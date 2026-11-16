from pathlib import Path
import re, json

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
original=(WORK/'before/appendix.tex').read_text()
records=json.loads((WORK/'paragraphs.json').read_text())
p={k:v['text'] for k,v in records.items()}
def r(k,old,new=''):
    pattern=r'\s+'.join(re.escape(x) for x in old.split())
    p[k],n=re.subn(pattern,lambda m:new,p[k],count=1)
    if n!=1: raise ValueError((k,old[:100]))
def span(k,start,end,new=''):
    a=p[k].index(start); b=p[k].index(end,a)+len(end)
    p[k]=p[k][:a]+new+p[k][b:]
def setp(k,text):
    displays=re.findall(r'\\begin\{(equation\*?|align\*?)\}.*?\\end\{\1\}',p[k],re.S)
    full=[m.group() for m in re.finditer(r'\\begin\{(equation\*?|align\*?)\}.*?\\end\{\1\}',p[k],re.S)]
    for i,block in enumerate(full): text=text.replace(f'@@{i}@@',block)
    assert all(block in text for block in full),(k,'lost display')
    p[k]=text.strip()

# Shorten prose around the complete mathematical arguments.
r('P2','Centering does not change covariance, so these values equal those obtained from the raw draws. We plotted the per-ticker values as histograms (Fig.~\\ref{fig:cov_diag}).','Centering leaves covariance unchanged.')
r('P2','The per-ticker values are therefore of the size expected from sampling noise, and the omitted cross-term is negligible on average. On a single path, it is not zero, which is why the composed variance matches its target only approximately.','The averages were consistent with sampling noise; individual paths still had nonzero cross-terms and therefore matched their variance targets only approximately.')
setp('P4',r'''To identify the portfolio consequence of independent residuals, we derive the diversification return of a daily-rebalanced portfolio. Matching generator variance also matches empirical variance only when the generator reproduces it; neither condition restores cross-asset residual covariance.''')
r('P5','Each asset\'s residual path, whether a rescaled full-return draw or a draw from a residual model, keeps its own temporal structure, but the residual paths are generated independently across assets at each date, so the construction omits cross-asset residual covariance.','Residual paths retain their own temporal structure but are generated independently across assets.')
r('P5','We suppress the time argument, writing $g_i$ for $g_i(t)$.','Write $g_i$ for $g_i(t)$.')
r('P5','Dividing through by $\\Delta t$ extracts the portfolio\'s annualized one-step log-growth rate $g_p(t) := \\Delta t^{-1}\\log(W_t/W_{t-1})$, the portfolio counterpart of the per-asset $g_i(t)$ (still suppressing the time argument):',r'Dividing by $\Delta t$ gives the annualized portfolio growth rate $g_p(t) := \Delta t^{-1}\log(W_t/W_{t-1})$:')
r('P6','The $O(\\Delta t)$ correction in Eq.~\\eqref{eq:gp-onestep} contains two squared quantities, $\\sum_i w_i\\, g_i(t)^2$ and $(\\sum_i w_i\\, g_i(t))^2$. Both expand by the second-moment identity, which holds for any random variable $X$ with finite second moment:',r'The squared terms $\sum_i w_i\, g_i(t)^2$ and $(\sum_i w_i\, g_i(t))^2$ in the $O(\Delta t)$ correction expand using the following identity for any $X$ with finite second moment:')
r('P6','The middle term, $D$, is the diversification return: $\\tfrac{1}{2}\\Delta t$ times the difference between the weighted-average per-asset variance $\\sum_i w_i \\sigma_i^2$ and the portfolio variance $\\sigma_p^2$.',r'The middle term, $D$, is the diversification return.')
r('P6','The long-run limit is then fixed by the unconditional joint distribution of $(g_i(t))_i$ at a single date and does not depend on the serial structure of the residual draw. This limit argument treats the residuals as a stationary process; the per-path centering and scaling of the composition act on a finite horizon and are outside it.',r'This limit depends on the single-date joint law of $(g_i(t))_i$, not residual serial dependence. Finite-horizon centering and scaling are outside this stationary-process argument.')
span('P7','The diversification return is therefore','called it the diversification return.',r'For positive-weight asset pairs, $D$ vanishes only when $\Var(g_i-g_j)=0$, or when all weight is on one asset. Rebalancing converts cross-sectional dispersion into compounded growth, the variance bonus described by Markowitz~\cite{markowitz1976longRun} and the diversification return of Booth and Fama~\cite{boothFama1992}.')
r('P8','Because $g_m$ and the residuals are uncorrelated, this relation splits the diversification return into market-beta-dispersion and idiosyncratic components:',r'The zero market-residual covariance splits diversification return into market and idiosyncratic components:')
r('P8','where the market-beta-dispersion component $D_\\mathrm{mkt}$ contains the weighted cross-sectional variance of $\\beta$. Applying the pair identity of Eq.~\\eqref{eq:pair-identity} with $\\beta_i$ in place of $g_i$ gives:',r'The market term $D_\mathrm{mkt}$ contains the weighted variance of $\beta$. Applying Eq.~\eqref{eq:pair-identity} with $\beta_i$ in place of $g_i$ gives:')
r('P9','Because the second-order value of $D$ depends only on same-date unconditional moments, serial dependence in the residual draw does not change it. Under the same zero-cross-covariance assumption,',r'At fixed same-date moments, serial dependence does not change the second-order $D$. Under zero market-residual covariance,')
r('P9','Thus, at fixed contemporaneous moments, serial dependence changes sampling noise but not the second-order diversification return.','')
setp('P10',r'''By contrast, omitted positive cross-asset residual covariance lowers real $\Var(\eps_i-\eps_j)$ below the independent-generator value $\sigma_{\eps,i}^2+\sigma_{\eps,j}^2$, so matching marginal variances can overstate $D_\eps$. We did not measure this excess. Isolating it requires a joint-residual comparison with fixed marginals and allocation; a gap from realized portfolio returns also includes finite-horizon sampling and second-order approximation error~\cite{boucheyNemtchinovWong2015}.''')
r('P12','This section defines those summaries; the factor-recovery errors and variance ratios of the composition scorecard are defined in the main text with that experiment.','')
r('P12','These percentages are descriptive: the tests assume independent observations, whereas returns are serially dependent, and in sample the generator was fitted to the comparison series. Independent simulations give independent pass indicators conditional on that fixed history and model, but do not supply new observed histories. A high pass rate therefore describes agreement with the supplied history and is not evidence that the model and the data share a distribution.','Pass rates are descriptive because returns are dependent and training comparisons reuse the fitting history. Independent simulations supply independent indicators conditional on that history and fit, not new historical evidence or proof of a shared distribution.')
r('P13','Every bin, including the last, contained its lower edge and excluded its upper edge, so observations equal to the pooled maximum fell outside all bins and that sample\'s bin weights sum to slightly less than one; we state this convention because the reported scores were computed with it. The score is a histogram approximation to the Hellinger distance between the two densities. Its bin edges depend on each pair, and its bins hold fewer observations in shorter samples, so it is best compared across generators within one window; holdout scores on $249$ observations run larger than training scores partly for that reason. Smaller Wasserstein and Hellinger scores indicate closer marginal agreement.',r'All bins included their lower edge and excluded their upper edge, omitting the pooled maximum; the resulting weights sum to slightly less than one. This histogram approximation is best compared within a window because pair-specific edges and sample length affect it. Smaller scores indicate closer marginal agreement.')
r('P14','These shape summaries do not measure how often returns exceed a Value-at-Risk threshold.','')
r('P15','To assess whether the simulated distributions bracketed the observed one, we measured agreement at $99$ quantile levels (Table~\\ref{tab:model_comparison}).',r'We also measured whether simulation envelopes bracketed $99$ observed quantiles (Table~\ref{tab:model_comparison}).')
r('P15','Larger values mean that more observed quantiles fall inside the pointwise simulation envelopes. This statistic assesses marginal quantile agreement; it does not estimate daily Value-at-Risk exceedance coverage or simultaneous confidence coverage.','Larger values indicate closer pointwise quantile agreement, not Value-at-Risk exceedance coverage or simultaneous confidence coverage.')
r('P17','The ensemble score asks whether the model\'s average autocorrelation curve matches the observed curve; the path score asks how far a single path\'s curve typically falls from it, sampling noise included. Their magnitudes cannot be compared directly across the single-asset and composition experiments, which also differ in lag limits, histories, and assets.','The path score includes sampling noise that ensemble averaging can cancel. The experiments also use different lag limits, histories and assets, so their error magnitudes are not directly comparable.')
r('P18','The multi-asset jump contrasts used the replication as the unit instead: within each of the $1{,}000$ replications we averaged a metric across assets, differenced two jump settings, and took the standard deviation of the $1{,}000$ differences divided by $\\sqrt{1{,}000}$ as the standard error, so that the dependence created by the shared market path stays inside each unit (Table~\\ref{tab:jump_ablation_uncertainty}; Online Appendix~\\ref{sec:supp-jump-composition}).',r'For multi-asset contrasts, we averaged within each of $1{,}000$ shared-market replications before differencing settings; the standard deviation of those differences divided by $\sqrt{1{,}000}$ preserved the market dependence within each unit (Online Appendix~\ref{sec:supp-jump-composition}).')
r('P20','stored fits were rechecked before evaluation.','')
r('P21','The six-method scores measured agreement with the observed asset and its calibrated factor model, rather than recovery of a common target for every branch (Tables~\\ref{tab:aggregate}, \\ref{tab:branch}, and \\ref{tab:beta_bucket}).','The scores reflect branch-specific targets.')
r('P21','Higher KS and AD pass rates and lower Wasserstein-1 distance indicated closer distributional agreement; kurtosis and Hill indices were compared with the observed asset\'s values.','')
span('P24','To confirm reproducibility,','output fingerprints.','Pinned dependencies, trained weights and generation records accompany the benchmark in the repository.')
r('P23','That early-stopping rule never triggered: the fit ran the full $200$ epochs, and the best training loss occurred at epoch $199$.','The fit completed $200$ epochs, selecting epoch $199$.')

# Later sections are revised in the companion script.
exec((WORK/'revise_later.py').read_text())

# Authorized grouping: 15 paragraphs in each of three original chunks.
groups=[['P4','P5'],['P9','P10'],['P14','P15'],['P16','P17'],['P20','P21'],
        ['P42','P43'],['P46','P47'],['P58','P59'],['P64','P65'],
        ['P71','P72'],['P74','P75','P76'],['P79','P80']]
for group in groups:
    p[group[0]]='\n'.join(p[k].strip() for k in group if p[k].strip())
    for k in group[1:]:p[k]=''
p['P49']=''
p['P67']=''
# Two derivations gain explicit paragraph boundaries.
p['P45']=p['P45'].replace('The ACF follows by conditioning','\n\nThe ACF follows by conditioning')
p['P66']=p['P66'].replace('Writing $\\kappa_m$','\n\nWriting $\\kappa_m$')

out=original
for k,v in records.items():
    assert v['text'] in out,k
    out=out.replace(v['text'],p[k],1)
keep={'tab:supp-generator-quantities','tab:emission_hsmm','tab:beta_bucket','fig:tails',
      'tab:jump_ablation_uncertainty','tab:centering_control','tab:fallback_sensitivity'}
def float_edit(m):
    label=re.search(r'\\label\{([^}]+)\}',m.group()).group(1)
    return m.group() if label in keep else ''
out=re.sub(r'\\begin\{(figure|table)\}.*?\\end\{\1\}',float_edit,out,flags=re.S)
out=out.replace('\\section{Transition matrix internals and partition diagnostics}\n\\label{sec:supp-transitions}','')
out=out.replace('\\label{sec:supp-gen-nojump}','\\label{sec:supp-gen-nojump}\n\\label{sec:supp-transitions}')
# Stale source comments describe deleted layouts; retain only substantive source.
out='\n'.join(line for line in out.splitlines() if not line.lstrip().startswith('%'))+'\n'
out=re.sub(r'\n(?:[ \t]*\n){2,}','\n\n',out)
(ROOT/'arxiv-paper/sections/appendix.tex').write_text(out)
(WORK/'grouping.json').write_text(json.dumps({'merges':groups,'removed':['P49','P67'],'split':['P45','P66'],'expected_actual_paragraphs':45},indent=2))
print('Wrote appendix revision.')
