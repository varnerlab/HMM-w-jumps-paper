#!/usr/bin/env python3
"""Run the GRU with a saved checkpoint, complete epoch log, and input hashes.

The model, loss, hyperparameters, and scalar rollout come from train_gru.py.
Parallel workers receive the NumPy RNG state for their original path position.
This preserves the original serial sampling order without changing the rollout.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import importlib.metadata
import json
import multiprocessing as mp
import platform
import sys
import time

import numpy as np
import torch
from torch.utils.data import DataLoader, TensorDataset
import train_gru as baseline

ROOT = Path(__file__).resolve().parent


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def reset_seed():
    np.random.seed(baseline.SEED)
    torch.manual_seed(baseline.SEED)


def state_to_json(state):
    return [state[0], state[1].tolist(), int(state[2]), int(state[3]), float(state[4])]


def state_from_json(state):
    return (state[0], np.array(state[1], dtype=np.uint32), state[2], state[3], state[4])


def train_with_log(g_is, mu_is, sigma_is, epochs, output):
    """The original training loop, with epoch records and saved best weights."""
    X, y = baseline.make_windows((g_is - mu_is) / sigma_is, baseline.WINDOW_SIZE)
    dataset = TensorDataset(torch.FloatTensor(X).unsqueeze(-1), torch.FloatTensor(y).unsqueeze(-1))
    loader = DataLoader(dataset, batch_size=baseline.BATCH_SIZE, shuffle=True, drop_last=True)
    model = baseline.GRUGenerator().to(baseline.DEVICE)
    optimizer = torch.optim.Adam(model.parameters(), lr=baseline.LEARNING_RATE)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, patience=15, factor=0.5, min_lr=1e-5)
    best_loss, patience_counter, best_epoch = float("inf"), 0, 0
    history = []
    for epoch in range(epochs):
        model.train()
        epoch_loss, n_batches = 0.0, 0
        for X_batch, y_batch in loader:
            X_batch, y_batch = X_batch.to(baseline.DEVICE), y_batch.to(baseline.DEVICE)
            mu, logvar = model(X_batch)
            loss = baseline.gaussian_nll(mu, logvar, y_batch)
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            epoch_loss += loss.item()
            n_batches += 1
        avg_loss = epoch_loss / n_batches
        if not np.isfinite(avg_loss):
            raise RuntimeError("Non-finite training loss")
        scheduler.step(avg_loss)
        if avg_loss < best_loss - 1e-4:
            best_loss, patience_counter, best_epoch = avg_loss, 0, epoch + 1
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            torch.save(best_state, output / "best-weights.pt")
        else:
            patience_counter += 1
        row = {"epoch": epoch + 1, "training_nll": avg_loss,
            "learning_rate": optimizer.param_groups[0]["lr"], "best_epoch": best_epoch,
            "best_training_nll": best_loss, "patience_counter": patience_counter}
        history.append(row)
        with (output / "epochs.jsonl").open("a") as stream:
            stream.write(json.dumps(row) + "\n")
        print(f'Epoch {epoch+1:3d}: loss={avg_loss:.8f}, best={best_loss:.8f}, '
              f'lr={row["learning_rate"]:.1e}', flush=True)
        if patience_counter >= 40:
            break
    model.load_state_dict(best_state)
    return model, history


def worker_init(checkpoint_path, observations, mu, sigma):
    global WORKER_MODEL, WORKER_OBS, WORKER_MU, WORKER_SIGMA
    torch.set_num_threads(1)
    baseline.DEVICE = torch.device("cpu")
    WORKER_MODEL = baseline.GRUGenerator()
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    WORKER_MODEL.load_state_dict(checkpoint["state_dict"])
    WORKER_OBS, WORKER_MU, WORKER_SIGMA = observations, mu, sigma


def worker_path(job):
    index, horizon, rng_state = job
    np.random.set_state(rng_state)
    path = baseline.generate_paths(WORKER_MODEL, WORKER_OBS, WORKER_MU,
        WORKER_SIGMA, horizon, 1)[:, 0]
    if not np.isfinite(path).all():
        raise RuntimeError(f"Non-finite return in path {index}")
    return index, path


def path_jobs(horizon, n_paths, n_seeds):
    jobs = []
    for index in range(n_paths):
        jobs.append((index, horizon, np.random.get_state()))
        # The parameters of a normal draw do not change its RNG consumption.
        np.random.randint(0, n_seeds)
        np.random.normal(size=horizon)
    return jobs


def generate_parallel(pool, horizon, n_paths, n_seeds, label):
    paths = np.empty((horizon, n_paths))
    jobs = path_jobs(horizon, n_paths, n_seeds)
    start = time.monotonic()
    for completed, (index, path) in enumerate(pool.imap_unordered(worker_path, jobs, chunksize=1), 1):
        paths[:, index] = path
        if completed % 25 == 0 or completed == n_paths:
            print(f"{label}: {completed}/{n_paths} paths, {time.monotonic()-start:.1f} s", flush=True)
    return paths


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=12)
    parser.add_argument("--training-threads", type=int, default=24)
    parser.add_argument("--smoke", action="store_true", help="One epoch and three short paths per window")
    parser.add_argument("--resume", action="store_true", help="Load the completed training checkpoint and regenerate paths")
    args = parser.parse_args()
    if args.workers < 1 or args.training_threads < 1:
        parser.error("Worker and thread counts must be positive")
    output = args.output_dir.resolve()
    if output.exists() and not args.resume:
        parser.error("Output directory exists; choose a new directory or use --resume")
    output.mkdir(parents=True, exist_ok=True)
    baseline.DEVICE = torch.device("cpu")
    torch.set_num_threads(args.training_threads)
    reset_seed()
    g_is, g_oos = baseline.load_data()
    assert len(g_is) == 2766 and len(g_oos) == 249
    mu_is, sigma_is = float(g_is.mean()), float(g_is.std())
    source_inputs = {name: sha256(ROOT/name) for name in
        ("train_gru.py", "reproduce_gru.py", "spy_is.csv", "spy_oos.csv")}
    checkpoint_path = output / "checkpoint.pt"
    if args.resume:
        checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
        assert checkpoint["source_input_sha256"] == source_inputs, "Checkpoint source/input mismatch"
        assert checkpoint["smoke"] == args.smoke
        model = baseline.GRUGenerator()
        model.load_state_dict(checkpoint["state_dict"])
        history = checkpoint["history"]
        np.random.set_state(state_from_json(checkpoint["numpy_rng_before_generation"]))
    else:
        epochs = 1 if args.smoke else baseline.EPOCHS
        model, history = train_with_log(g_is, mu_is, sigma_is, epochs, output)
        checkpoint = {"state_dict": model.state_dict(), "history": history,
            "mean": mu_is, "std_ddof0": sigma_is, "smoke": args.smoke,
            "numpy_rng_before_generation": state_to_json(np.random.get_state()),
            "source_input_sha256": source_inputs}
        torch.save(checkpoint, checkpoint_path)
    parameter_count = sum(p.numel() for p in model.parameters())
    assert parameter_count == 37954

    if args.smoke:
        # Verify the recorded loop against the untouched training implementation.
        reset_seed()
        old_epochs = baseline.EPOCHS
        baseline.EPOCHS = 1
        reference_model = baseline.train_model(g_is, mu_is, sigma_is)
        baseline.EPOCHS = old_epochs
        assert all(torch.equal(v, reference_model.state_dict()[k]) for k,v in model.state_dict().items())
        print("Recorded training loop matches original weights exactly after one epoch.", flush=True)

    # Check the saved checkpoint, worker arithmetic, and serial RNG scheduling.
    loaded = torch.load(checkpoint_path, map_location="cpu", weights_only=True)
    assert all(torch.equal(v, loaded["state_dict"][k]) for k,v in model.state_dict().items())
    sample_state = state_from_json(checkpoint["numpy_rng_before_generation"])
    np.random.set_state(sample_state)
    reference = baseline.generate_paths(model, g_is, mu_is, sigma_is, 64, 3)
    serial_end = np.random.get_state()
    ctx = mp.get_context("spawn")
    with ctx.Pool(args.workers, initializer=worker_init,
                  initargs=(str(checkpoint_path), g_is, mu_is, sigma_is)) as pool:
        np.random.set_state(sample_state)
        parallel = generate_parallel(pool, 64, 3, len(g_is)-baseline.WINDOW_SIZE, "Parity check")
        assert np.array_equal(reference, parallel), "Parallel generation changed original scalar rollout"
        assert state_to_json(np.random.get_state()) == state_to_json(serial_end)
        print("Checkpoint reload and parallel/serial paths agree exactly.", flush=True)
        np.random.set_state(sample_state)
        n_paths = 3 if args.smoke else baseline.N_PATHS
        for window, horizon in (("is", 64 if args.smoke else len(g_is)),
                                ("oos", 16 if args.smoke else len(g_oos))):
            paths = generate_parallel(pool, horizon, n_paths, len(g_is)-baseline.WINDOW_SIZE, window)
            np.savetxt(output / f"gru_paths_{window}.csv", paths, delimiter=",", fmt="%.10f")
    metadata = {"completed_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "mode": "smoke" if args.smoke else "full", "device": "cpu",
        "python": sys.version, "platform": platform.platform(),
        "packages": {name: importlib.metadata.version(name) for name in ("torch","numpy","scipy")},
        "training_threads": args.training_threads, "generation_workers": args.workers,
        "generation_threads_per_worker": 1, "seed": baseline.SEED,
        "parameters": parameter_count, "epochs_completed": len(history),
        "best_epoch": history[-1]["best_epoch"], "best_training_nll": history[-1]["best_training_nll"],
        "training_windows": len(g_is)-baseline.WINDOW_SIZE, "normalization_mean": mu_is,
        "normalization_std_ddof0": sigma_is, "source_input_sha256": source_inputs,
        "checkpoint_and_serial_parallel_parity": True,
        "original_loop_smoke_parity": bool(args.smoke),
        "artifact_sha256": {name:sha256(output/name) for name in
            ("checkpoint.pt","best-weights.pt","epochs.jsonl","gru_paths_is.csv","gru_paths_oos.csv")}}
    (output / "metadata.json").write_text(json.dumps(metadata,indent=2)+"\n")
    print(json.dumps({k:metadata[k] for k in ("mode","epochs_completed","best_epoch","parameters")}),flush=True)


if __name__ == "__main__":
    main()
