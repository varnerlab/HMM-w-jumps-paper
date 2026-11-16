from pathlib import Path
import re
root=Path(__file__).resolve().parents[2]/'arxiv-paper/sections'
def sub(s,a,b):
    return re.sub(r'\s+'.join(re.escape(x) for x in a.split()),lambda m:b,s)
mapping={'fig:cov_diag':'sec:supp-cov','fig:statistical_validation':'sec:supp-gen-renewal',
'tab:descriptive_stats':'sec:supp-generator','tab:supp-acf-prediction':'sec:supp-gen-tuning',
'fig:model_internals':'sec:supp-gen-nojump','tab:sensitivity_n':'sec:supp-sensitivity',
'tab:cross_asset':'sec:supp-cross-asset','fig:r2_distribution':'sec:supp-sim-derivations',
'fig:branch_map':'sec:supp-sim-derivations','tab:branch':'sec:supp-sim-derivations',
'tab:tracker_grid':'sec:supp-sim-derivations','tab:stress':'sec:supp-sim-derivations',
'tab:supp-kurt-composition':'sec:supp-residual-choice','tab:jump_ablation_episodes':'sec:supp-jump-composition',
'tab:var_convergence':'sec:supp-var-ensemble','tab:var_common':'sec:supp-var-ensemble',
'tab:fallback_assets':'sec:supp-fallback'}
for name in ['appendix','method_hmm','method_sim','results','discussion','main_tables']:
    f=root/(name+'.tex'); s=f.read_text()
    replacements=[
    (r'Figs.~\ref{fig:r2_distribution} and~\ref{fig:branch_map}; Table~\ref{tab:branch}',r'Online Appendix~\ref{sec:supp-sim-derivations}'),
    (r'Tables~\ref{tab:branch} and~\ref{tab:tracker_grid}',r'Online Appendix~\ref{sec:supp-sim-derivations}'),
    (r'Tables~\ref{tab:supp-generator-quantities} and~\ref{tab:supp-acf-prediction}',r'Table~\ref{tab:supp-generator-quantities}; Online Appendix~\ref{sec:supp-gen-tuning}'),
    (r'Tables~\ref{tab:fallback_assets} and~\ref{tab:fallback_sensitivity}',r'Table~\ref{tab:fallback_sensitivity}; Online Appendix~\ref{sec:supp-fallback}'),
    (r'Tables~\ref{tab:sensitivity_n} and~\ref{tab:emission_hsmm}',r'Online Appendix~\ref{sec:supp-sensitivity}; Table~\ref{tab:emission_hsmm}'),
    (r'Fig.~\ref{fig:model_internals} in Online Appendix~\ref{sec:supp-transitions}',r'Online Appendix~\ref{sec:supp-gen-nojump}'),
    (r'Fig.~\ref{fig:model_internals}; Online Appendix~\ref{sec:supp-generator}',r'Online Appendix~\ref{sec:supp-gen-nojump}'),
    (r'Table~\ref{tab:cross_asset}; Online Appendix~\ref{sec:supp-cross-asset}',r'Online Appendix~\ref{sec:supp-cross-asset}'),
    ]
    for a,b in replacements:s=sub(s,a,b)
    for old,new in mapping.items():
        s=re.sub(r'(?:Fig\.|Table)~\\ref\{'+re.escape(old)+r'\}',lambda m:r'Online Appendix~\ref{'+new+'}',s)
    if name=='appendix':
        s=sub(s,'eligible assets; All four residual','eligible assets. All four residual')
        s=s.replace('scale (Online Appendix~\\ref{sec:supp-fallback}).\n\nEvaluated','scale (Online Appendix~\\ref{sec:supp-fallback}).\nEvaluated')
        s=sub(s,'Their annualized volatility is',r'Ljung--Box tests on raw returns at lag $20$ gave $p<0.001$ in training and $p=0.019$ in the $249$-day $2025$ holdout, despite small individual lag correlations. Their annualized volatility is')
        s=sub(s,'All cells used the intended branch and approximately recovered their targets over $100$ replications, with finite-path differences from independent residuals.',r'All cells used the intended branch; across $100$ replications per cell, median loading and $R^2$ errors were at most $0.0011$ and $0.0017$. Independent residuals still caused finite-path differences.')
        s=s.replace('Every SPY state was populated,','The tail sets were $\\mathcal{S}_{-}=\\{1,\\ldots,5\\}$ and $\\mathcal{S}_{+}=\\{96,\\ldots,100\\}$. Every SPY state was populated,')
    f.write_text(s)
print('Repaired active manuscript references; preserved main-text paragraph boundaries.')
