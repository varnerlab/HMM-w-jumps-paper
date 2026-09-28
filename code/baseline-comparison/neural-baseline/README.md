# GRU benchmark and recorded reproduction

The gated recurrent unit (GRU) is the neural benchmark in manuscript Table 2.
Its model definition and original training/sampling code are in
[train_gru.py](train_gru.py). It predicts a Gaussian distribution for the next
standardized SPY growth rate from a 50-value window, using two 64-unit GRU
layers and 37,954 trainable parameters.

The 15 September 2026 reproduction is saved in
[saved-runs/r8-20260915](saved-runs/r8-20260915/). It completed 200 epochs,
selected epoch 199 using training loss, and reproduced both distributed path
CSVs byte for byte. All 1,000 training-length and 1,000 holdout-length paths
match the original files. The manuscript's numerical GRU results are unchanged.

## Environment

The checked environment is CPython 3.14.2 on macOS arm64, with PyTorch 2.10.0,
NumPy 2.4.3, and SciPy 1.17.1. The complete runtime dependencies are pinned in
[requirements-macos-arm64.lock](requirements-macos-arm64.lock). The direct
dependencies are also pinned in [requirements.txt](requirements.txt). SciPy is
used by the original script's kurtosis sanity check; pandas is not required.

From this directory, create the environment with:

```sh
python3.14 -m venv .venv
.venv/bin/python -m pip install -r requirements-macos-arm64.lock
.venv/bin/python -m pip check
```

Other platforms require a separately checked environment. The byte-for-byte
reproduction applies to the recorded CPU environment, source, inputs, and
random-number schedule.

## Reproduce the fit and paths

Use a fresh output directory. From this directory:

```sh
.venv/bin/python -u reproduce_gru.py --workers 12 --training-threads 24 --output-dir saved-runs/new-run
```

The wrapper records the original training rule and invokes the original scalar
rollout. Worker processes receive the NumPy RNG state at each path's original
serial position. A serial/parallel parity check runs before full generation.
The training-length paths are generated first, then the holdout-length paths,
with the same fitted network and seed 1234.

Each completed run contains:

- `checkpoint.pt`: selected model weights, normalization, epoch history,
  pre-generation NumPy state, and source/input hashes.
- `best-weights.pt`: selected state dictionary, written whenever training loss
  improves by more than `1e-4`.
- `epochs.jsonl`: training loss, learning rate, selected epoch, and stopping
  counter for every epoch.
- `gru_paths_is.csv` and `gru_paths_oos.csv`: generated excess growth rates,
  with paths in columns and time in rows.
- `metadata.json`: environment, configuration, validation, and artifact hashes.

If training completed but generation was interrupted, repeat the same command
with `--resume`, the same output directory, environment, and thread settings.
The source and input hashes must match the saved checkpoint. Generation restarts
from the saved random-number state.

A short check exercises one epoch, checkpoint loading, and three short paths in
each window. It also compares the instrumented training loop with the unchanged
original loop and requires identical weights:

```sh
.venv/bin/python -u reproduce_gru.py --smoke --workers 2 --training-threads 24 --output-dir saved-runs/smoke
```

## Reproduce the metrics

The observed CSVs are the same VWAP-derived growth rates used in the single-asset
experiment: `252*log(P[t]/P[t-1]) - rf`, with `rf=0.043` in training and
`rf=0.0421` in the holdout. Both exports were checked against the cached
observed series. Training and normalization use only the 2014–2024 series;
the holdout supplies its length and the evaluation reference.

From the repository root, run the audit scorer against the recorded paths:

```sh
julia --compiled-modules=existing --threads=4 --project=code/baseline-comparison audits/2026-09-14-review/metrics-correction/verify_metrics.jl code/baseline-comparison/neural-baseline/saved-runs/r8-20260915 audits/2026-09-14-review/metrics-correction/gru-rerun-metrics
```

The scorer loads the metric definitions directly from the two original Julia
evaluators, checks their agreement, and writes every point estimate and standard
error. It also checks the ACF formula, both orders of averaging, quantile-envelope
coverage, and the original histogram endpoint convention. It does not train or
simulate a new model. The [R8 report](../../../audits/2026-09-14-review/metrics-correction/README.md)
documents manuscript changes and verification.
