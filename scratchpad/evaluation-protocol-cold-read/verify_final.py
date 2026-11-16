from pathlib import Path
import hashlib,json,re,sys
s=Path('scratchpad/evaluation-protocol-cold-read'); sys.path.insert(0,'/Users/jdv27/.codex/skills/cold-read/scripts'); from structure_guard import inventory
changed=[p for p,h in json.loads((s/'source-hashes-before.json').read_text()).items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
assert set(changed)=={'arxiv-paper/sections/method_sim.tex','arxiv-paper/sections/appendix.tex'},changed
old=(s/'before/method_sim.tex').read_text();new=Path('arxiv-paper/sections/method_sim.tex').read_text();a='\\paragraph{Evaluation protocol.}';b='\\paragraph{Jump-enabled multi-asset comparison.}'
assert old.split(a)[0]==new.split(a)[0] and old.split(b)[1]==new.split(b)[1]
assert new[new.index(a):new.index(b)]==(s/'paper/sections/evaluation_protocol.tex').read_text()
oldapp=(s/'before/appendix.tex').read_text();newapp=Path('arxiv-paper/sections/appendix.tex').read_text();added=(s/'supplement-addition.tex').read_text()
assert newapp.replace(added,'',1)==oldapp
assert added==(s/'paper/sections/supp_evaluation.tex').read_text()
keys=lambda t:set(k.strip() for block in re.findall(r'\\cite[pt]?\{([^}]+)\}',t) for k in block.split(','))
assert keys(old+oldapp)==keys(new+newapp)
assert not re.search(r'—|---|\\begin\{(?:itemize|enumerate)\}',(s/'final-main-excerpt.tex').read_text()+added)
counts={name:{k:inventory(s/f'count-{name}.tex')[k] for k in ['paragraph_count','prose_words']} for name in ['before','after','supp']}
assert counts['before']['paragraph_count']==5 and counts['after']['paragraph_count']==3 and counts['supp']['paragraph_count']==2
for name in ['method_sim','appendix']:
 before=json.loads((s/f'{name}-structure.json').read_text());after=inventory(Path('arxiv-paper/sections')/f'{name}.tex')
 protected=after['protected_formatting'].copy()
 if name=='appendix':protected.remove('\\subsection{Six-method composition evaluation}')
 assert before['protected_formatting']==protected,name
report={'counts':counts,'source_changes':changed,'scope_verification':'Only Evaluation protocol replaced in method_sim; appendix differs only by exact two-paragraph addition. All other manuscript source hashes unchanged.','citations':'All bibliography keys preserved across main and supplement.','formatting':'Existing headings and protected formatting unchanged. New supplemental subsection organizes the authorized relocation.','pdf_pages':{'main':[10,11],'supplement':[35,36]},'pdf_sha256':hashlib.sha256(Path('arxiv-paper/Paper_v1.pdf').read_bytes()).hexdigest()}
(s/'verification.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
