from pathlib import Path
import re
f=Path(__file__).resolve().parents[2]/'arxiv-paper/sections/appendix.tex'
s=f.read_text()
def fix(a,b):
 global s
 s,n=re.subn(r'\s+'.join(re.escape(x) for x in a.split()),lambda m:b,s,count=1)
 assert n==1,a
fix(r'so it does not change $\E(g_p)$ in Eqs.~\eqref{eq:booth-fama} and~\eqref{eq:dr-sim}.',r'so it leaves the second-order approximation to $\E(g_p)$ in Eqs.~\eqref{eq:booth-fama} and~\eqref{eq:dr-sim} unchanged.')
fix('the resulting weights sum to slightly less than one.','the sample containing that maximum has weights summing to slightly less than one.')
fix('Larger values indicate closer pointwise quantile agreement, not Value-at-Risk exceedance coverage or simultaneous confidence coverage.','Larger values mean that more observed quantiles lie inside the pointwise envelopes, which also depends on envelope width; this is neither Value-at-Risk exceedance coverage nor simultaneous confidence coverage.')
fix('Their annualized volatility is','The training series has annualized volatility')
fix('Each closed-form entry evaluates an expression derived in this section at the fitted SPY model of Table~\\ref{tab:hyperparams}.',r'Entries evaluate the expressions below at the fitted SPY model of Table~\ref{tab:hyperparams}; jump-path entries use the stated single-episode and finite-horizon approximations.')
fix('the fitted law need not reproduce their moments.','the fitted law need not reproduce the observed return moments.')
fix('The transition matrix is the maximum likelihood estimator (MLE) of a first-order Markov chain. Conditional on the assigned state sequence',r'Row counting gives the maximum likelihood estimator (MLE) for the transition likelihood conditional on the initial assigned state. For the assigned state sequence')
fix(r'As $\tau$ grows, $\mathbf{T}^\tau$ converges to its rank-one limit, every row equal to $\bar\pi$, at the geometric rate $|\theta_2|^\tau$, where $\theta_2$ is the second-largest eigenvalue of $\mathbf{T}$ in modulus; the ACF is therefore bounded by a constant multiple of $|\theta_2|^\tau$.',r'For an ergodic, diagonalizable transition matrix, $\mathbf{T}^\tau$ approaches the rank-one limit with rows $\bar\pi$ at geometric rate $|\theta_2|^\tau$, where $\theta_2$ is the second-largest eigenvalue in modulus; the ACF is then bounded by a constant multiple of $|\theta_2|^\tau$. Direct evaluation of Eq.~\eqref{eq:supp-acf-nj-def} gives the fitted-chain decay reported here.')
fix(r'The long-run state distribution is therefore approximately $(1 - \pi_J)\,\bar\pi + \pi_J\, u$, and using $\bar\pi$ as the initial law misallocates $O(\pi_J) \approx 1\%$ of probability mass. Thus $\bar\pi$ is only an approximate stationary start for the augmented process.',r'The long-run state marginal is therefore approximately $(1 - \pi_J)\,\bar\pi + \pi_J\,u$. Its forced-state contribution has weight $O(\pi_J) \approx 1\%$; this is not an error bound for the full augmented initial law, which also sets the episode counter to zero. Thus $\bar\pi$ supplies only an approximate stationary start.')
fix('Forced observations are conditionally independent draws from $u$.',r'Forced states are independent draws from $u$, followed by independent emissions from those states.')
fix('A sweep of the jump-active share confirmed the tradeoff between autocorrelation and marginal fit.',r'A mixture of jump-active and no-jump groups from $4{,}000$ training-length paths, with the jump-active weight varied from zero to one, lowered ACF-MAE together with KS and AD pass rates as the weight increased.')
fix('fitting used the unshifted visit lengths.','fitting used the unshifted visit lengths, so simulation added one step to the fitted count mean. This convention also qualifies the duration comparison.')
fix(r'clipping affected $0.0\%$, $76.4\%$ and $95.2\%$ of the $423$ assets, respectively;',r'clipping affected $0.0\%$, $76.4\%$ and $95.2\%$ of evaluated composed paths across the $423$ assets, respectively;')
fix(r'Writing $\kappa_m$ and $\kappa_{\gen}$ for the excess kurtosis of the supplied market series and of the generator draw,',r'Writing $\kappa_m$ and $\kappa_{\gen}$ for the population excess kurtoses of the market and generator laws in this fixed-coefficient approximation,')
fix('For a low-loading asset, most of the generator\'s excess kurtosis survives:','For a small market variance share, most generator excess kurtosis survives:')
fix(r'The hybrid KS pass rate declines from $87.6\%$ in Q1 to $65.9\%$ in Q4; the naive KS pass rate falls from $24.6\%$ to $1.3\%$ over the same range.',r'Pass rates pool equal numbers of paths per asset; other entries are medians across paths in the bucket. The GARCH rows use eligible fits among $393$ assets, while the other methods cover all $423$.')
fix(r'For the inventory, $n_{\rm c}$ counted observations in a constant state and $n_0,n_1$ counted empty and singleton states.',r'The per-asset inventory retained in the replication files uses $n_{\rm c}$ for observations in a constant state and $n_0,n_1$ for empty and singleton state counts.')
fix(r'The variance-change diagnostic $\Delta V$ is the percentage change',r'Its diagnostic $\Delta V$ is the percentage change')
s='\n'.join(line.rstrip() for line in s.splitlines())+'\n'
f.write_text(s)
print('Applied reader repairs without changing paragraph boundaries or displayed math.')
