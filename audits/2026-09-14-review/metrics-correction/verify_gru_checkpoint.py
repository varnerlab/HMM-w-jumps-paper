"""Verify the recorded environment, artifacts, and complete serial sample paths."""
from pathlib import Path
import hashlib
import importlib.metadata as packages
import json
import sys
import numpy as np
import torch

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[2]
NEURAL = REPO / "code/baseline-comparison/neural-baseline"
RUN = NEURAL / "saved-runs/r8-20260915"
sys.path.insert(0, str(NEURAL))
import train_gru as baseline

digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
metadata = json.loads((RUN / "metadata.json").read_text())
for name, expected in metadata["source_input_sha256"].items():
    assert digest(NEURAL / name) == expected, name
for name, expected in metadata["artifact_sha256"].items():
    assert digest(RUN / name) == expected, name
for name, version in metadata["packages"].items():
    assert packages.version(name) == version
assert sys.version == metadata["python"]
assert metadata["epochs_completed"] == 200 and metadata["best_epoch"] == 199

torch.set_num_threads(1)
baseline.DEVICE = torch.device("cpu")
checkpoint = torch.load(RUN / "checkpoint.pt", map_location="cpu", weights_only=True)
model = baseline.GRUGenerator()
model.load_state_dict(checkpoint["state_dict"])
assert sum(p.numel() for p in model.parameters()) == 37954
history = [json.loads(line) for line in (RUN / "epochs.jsonl").read_text().splitlines()]
assert history == checkpoint["history"]
assert min(history, key=lambda row: row["training_nll"])["epoch"] == 199
g_is, g_oos = baseline.load_data()
assert checkpoint["mean"] == g_is.mean() and checkpoint["std_ddof0"] == g_is.std()
serialized_state = checkpoint["numpy_rng_before_generation"]
state = (serialized_state[0], np.array(serialized_state[1], dtype=np.uint32),
    serialized_state[2], serialized_state[3], serialized_state[4])
checks = {}
for window, horizon in (("is", 2766), ("oos", 249)):
    old = NEURAL / f"gru_paths_{window}.csv"
    new = RUN / old.name
    assert old.read_bytes() == new.read_bytes()
    saved = np.loadtxt(new, delimiter=",")
    assert saved.shape == (horizon, 1000) and np.isfinite(saved).all()
    np.random.set_state(state)
    if window == "oos":
        # Advance exactly through all 1,000 training paths before the holdout.
        for _ in range(1000):
            np.random.randint(0, len(g_is)-baseline.WINDOW_SIZE)
            np.random.normal(size=2766)
    serial = baseline.generate_paths(model, g_is, checkpoint["mean"],
        checkpoint["std_ddof0"], horizon, 3)
    rounded = np.array([[float(f"{value:.10f}") for value in row] for row in serial])
    assert np.array_equal(rounded, saved[:, :3])
    checks[window] = {"all_1000_paths_byte_identical_to_archive": True,
        "three_full_length_serial_paths_match_checkpoint": True, "shape": list(saved.shape),
        "sha256": digest(new)}
report = {"environment_matches": True, "source_input_and_output_hashes_match": True,
    "checkpoint_reload_passed": True, "epochs": 200, "selected_epoch": 199,
    "all_3015000_generated_values_match_archive": True, "windows": checks}
(OUT / "gru-checkpoint-verification.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps(report,indent=2))
