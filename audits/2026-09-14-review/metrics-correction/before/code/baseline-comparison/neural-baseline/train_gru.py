#!/usr/bin/env python3
"""
train_gru.py — Autoregressive GRU baseline for synthetic equity path generation.

Trains a 2-layer GRU that predicts the next excess growth rate given a window
of L past values. The output head produces both a mean and log-variance,
so at generation time we sample from N(mu, sigma) to produce diverse paths.

Usage:
    1. Run export_spy_data.jl to produce spy_is.csv and spy_oos.csv
    2. python train_gru.py
    3. Run Neural-Baseline-Evaluation.jl to compute quality metrics

Outputs:
    gru_paths_is.csv   — 1000 synthetic paths of length 2766 (T_is x 1000)
    gru_paths_oos.csv  — 1000 synthetic paths of length 249  (T_oos x 1000)
"""

import os
import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, TensorDataset

# ── reproducibility ─────────────────────────────────────────────────────────
SEED = 1234
np.random.seed(SEED)
torch.manual_seed(SEED)
torch.backends.cudnn.deterministic = True

# ── hyperparameters ─────────────────────────────────────────────────────────
WINDOW_SIZE = 50        # number of past values to condition on
HIDDEN_DIM = 64         # GRU hidden dimension
NUM_LAYERS = 2          # GRU layers
DROPOUT = 0.1           # dropout between GRU layers
BATCH_SIZE = 256
LEARNING_RATE = 1e-3
EPOCHS = 200
N_PATHS = 1000          # number of synthetic paths to generate

DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


# ── model ───────────────────────────────────────────────────────────────────
class GRUGenerator(nn.Module):
    """
    Autoregressive GRU with Gaussian output head.
    Input:  (batch, seq_len, 1)
    Output: mu (batch, 1), log_var (batch, 1)
    """

    def __init__(self, hidden_dim=HIDDEN_DIM, num_layers=NUM_LAYERS, dropout=DROPOUT):
        super().__init__()
        self.gru = nn.GRU(
            input_size=1,
            hidden_size=hidden_dim,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout if num_layers > 1 else 0.0,
        )
        self.fc_mu = nn.Linear(hidden_dim, 1)
        self.fc_logvar = nn.Linear(hidden_dim, 1)

    def forward(self, x):
        # x: (batch, seq_len, 1)
        out, _ = self.gru(x)          # (batch, seq_len, hidden)
        last = out[:, -1, :]          # (batch, hidden) — last time step
        mu = self.fc_mu(last)         # (batch, 1)
        logvar = self.fc_logvar(last) # (batch, 1)
        return mu, logvar


def gaussian_nll(mu, logvar, target):
    """Negative log-likelihood of target under N(mu, exp(logvar))."""
    var = torch.exp(logvar)
    return 0.5 * torch.mean(logvar + (target - mu) ** 2 / var)


# ── data loading ────────────────────────────────────────────────────────────
def load_data():
    is_path = os.path.join(SCRIPT_DIR, "spy_is.csv")
    oos_path = os.path.join(SCRIPT_DIR, "spy_oos.csv")
    if not os.path.exists(is_path):
        raise FileNotFoundError(
            f"{is_path} not found. Run export_spy_data.jl first."
        )
    g_is = np.loadtxt(is_path, delimiter=",").flatten()
    g_oos = np.loadtxt(oos_path, delimiter=",").flatten()
    return g_is, g_oos


def make_windows(data, window_size):
    """Create (X, y) pairs: X[i] = data[i:i+L], y[i] = data[i+L]."""
    X, y = [], []
    for i in range(len(data) - window_size):
        X.append(data[i : i + window_size])
        y.append(data[i + window_size])
    return np.array(X), np.array(y)


# ── training ────────────────────────────────────────────────────────────────
def train_model(g_is, mu_is, sigma_is):
    # normalize
    data_norm = (g_is - mu_is) / sigma_is

    X, y = make_windows(data_norm, WINDOW_SIZE)
    X_t = torch.FloatTensor(X).unsqueeze(-1)  # (N, L, 1)
    y_t = torch.FloatTensor(y).unsqueeze(-1)  # (N, 1)

    dataset = TensorDataset(X_t, y_t)
    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True, drop_last=True)

    model = GRUGenerator().to(DEVICE)
    optimizer = torch.optim.Adam(model.parameters(), lr=LEARNING_RATE)
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, patience=15, factor=0.5, min_lr=1e-5
    )

    best_loss = float("inf")
    patience_counter = 0

    for epoch in range(EPOCHS):
        model.train()
        epoch_loss = 0.0
        n_batches = 0
        for X_batch, y_batch in loader:
            X_batch = X_batch.to(DEVICE)
            y_batch = y_batch.to(DEVICE)

            mu, logvar = model(X_batch)
            loss = gaussian_nll(mu, logvar, y_batch)

            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()

            epoch_loss += loss.item()
            n_batches += 1

        avg_loss = epoch_loss / n_batches
        scheduler.step(avg_loss)

        if (epoch + 1) % 20 == 0:
            lr = optimizer.param_groups[0]["lr"]
            print(f"  Epoch {epoch+1:3d}/{EPOCHS}  loss={avg_loss:.4f}  lr={lr:.1e}")

        # early stopping
        if avg_loss < best_loss - 1e-4:
            best_loss = avg_loss
            patience_counter = 0
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
        else:
            patience_counter += 1
            if patience_counter >= 40:
                print(f"  Early stopping at epoch {epoch+1}")
                break

    model.load_state_dict(best_state)
    return model


# ── generation ──────────────────────────────────────────────────────────────
@torch.no_grad()
def generate_paths(model, g_is, mu_is, sigma_is, T, n_paths):
    """
    Generate n_paths synthetic paths of length T via autoregressive rollout.
    Each path is seeded with a random window from the training data.
    """
    model.eval()
    data_norm = (g_is - mu_is) / sigma_is
    n_seeds = len(data_norm) - WINDOW_SIZE

    paths = np.zeros((T, n_paths))

    for i in range(n_paths):
        # random seed window from training data
        start_idx = np.random.randint(0, n_seeds)
        window = data_norm[start_idx : start_idx + WINDOW_SIZE].copy()

        path = np.zeros(T)
        for t in range(T):
            x = torch.FloatTensor(window).unsqueeze(0).unsqueeze(-1).to(DEVICE)
            mu, logvar = model(x)
            sigma = torch.exp(0.5 * logvar).item()
            mu_val = mu.item()

            # sample from predicted Gaussian
            val = np.random.normal(mu_val, max(sigma, 1e-6))
            path[t] = val

            # slide window
            window = np.roll(window, -1)
            window[-1] = val

        # denormalize
        paths[:, i] = path * sigma_is + mu_is

    return paths


# ── main ────────────────────────────────────────────────────────────────────
def main():
    print("=" * 70)
    print("GRU Autoregressive Baseline — Synthetic Equity Path Generation")
    print("=" * 70)

    # load data
    print("\n[1/4] Loading data...")
    g_is, g_oos = load_data()
    T_is = len(g_is)
    T_oos = len(g_oos)
    print(f"  IS: {T_is} values, OoS: {T_oos} values")

    # normalization stats (from training data only)
    mu_is = g_is.mean()
    sigma_is = g_is.std()
    print(f"  IS mean: {mu_is:.6f}, std: {sigma_is:.6f}")

    # train
    print(f"\n[2/4] Training GRU (window={WINDOW_SIZE}, hidden={HIDDEN_DIM}, "
          f"layers={NUM_LAYERS}, epochs={EPOCHS})...")
    print(f"  Device: {DEVICE}")
    model = train_model(g_is, mu_is, sigma_is)

    # count parameters
    n_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"  Trainable parameters: {n_params:,}")

    # generate IS paths
    print(f"\n[3/4] Generating {N_PATHS} IS paths (T={T_is})...")
    paths_is = generate_paths(model, g_is, mu_is, sigma_is, T_is, N_PATHS)
    out_is = os.path.join(SCRIPT_DIR, "gru_paths_is.csv")
    np.savetxt(out_is, paths_is, delimiter=",", fmt="%.10f")
    print(f"  Saved to {out_is}")

    # generate OoS paths (same model, shorter rollout)
    print(f"\n[4/4] Generating {N_PATHS} OoS paths (T={T_oos})...")
    paths_oos = generate_paths(model, g_is, mu_is, sigma_is, T_oos, N_PATHS)
    out_oos = os.path.join(SCRIPT_DIR, "gru_paths_oos.csv")
    np.savetxt(out_oos, paths_oos, delimiter=",", fmt="%.10f")
    print(f"  Saved to {out_oos}")

    # quick sanity check
    print("\n── Sanity check (IS paths) ──")
    print(f"  Mean:     {paths_is.mean():.6f}  (observed: {mu_is:.6f})")
    print(f"  Std:      {paths_is.std():.6f}  (observed: {sigma_is:.6f})")
    from scipy.stats import kurtosis as sp_kurtosis
    kurt_sim = np.mean([sp_kurtosis(paths_is[:, i]) for i in range(N_PATHS)])
    from scipy.stats import kurtosis as sp_kurt
    kurt_obs = sp_kurt(g_is)
    print(f"  Kurtosis: {kurt_sim:.2f}  (observed: {kurt_obs:.2f})")

    print("\nDone.")


if __name__ == "__main__":
    main()
