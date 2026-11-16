from pathlib import Path
import sys,json,re,hashlib
sys.path.insert(0,'/Users/jdv27/.codex/skills/cold-read/scripts')
from structure_guard import inventory
s=Path('scratchpad/introduction-cold-read'); target=Path('arxiv-paper/sections/introduction.tex'); before=json.loads((s/'structure.json').read_text()); after=inventory(target)
assert after['paragraph_count']==4 and after['block_order']==['para']*4
assert after['paragraphs'][3].startswith('In this study,')
assert after['prose_words']<=before['prose_words']
for key in ('protected_formatting','citation_styles'):assert before[key]==after[key]
raw=target.read_text(); old=(s/'before/introduction.tex').read_text()
keys=lambda t:set(k.strip() for c in re.findall(r'\\cite[pt]?\{([^}]+)\}',t) for k in c.split(','))
assert keys(raw)==keys(old)
refs=lambda t:set(re.findall(r'\\ref\{([^}]+)\}',t))
assert refs(old)-refs(raw)=={'tab:var','tab:model_comparison'} and not refs(raw)-refs(old)
changed=[p for p,h in json.loads((s/'source-hashes-before.json').read_text()).items() if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
assert changed==['arxiv-paper/sections/introduction.tex'],changed
assert raw==(s/'paper/sections/introduction.tex').read_text(),'Reader input differs from manuscript'
prose='\n'.join(l for l in raw.splitlines() if not l.startswith('%'))
assert not re.search(r'---|—| -- |\\begin\{(?:itemize|enumerate)\}|\\(?:sub)*section\{|\\paragraph\{|\\ref\{sec:',prose)
report={'paragraphs_before':before['paragraph_count'],'paragraphs_after':after['paragraph_count'],'words_before':before['prose_words'],'words_after':after['prose_words'],'paragraph_word_counts':[len(p.split()) for p in after['paragraphs']],'authorized_structure':'P1→P1, P2→P2, P3→P3, P4–P7→P4; final starts In this study,','unchanged_formatting':True,'unchanged_citation_style':True,'unchanged_bibliography_citation_keys':True,'removed_table_references':'tab:var and tab:model_comparison, with omitted optional VaR preview and standalone SPY test setup','only_changed_manuscript_source':changed,'final_source_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'pdf_sha256':hashlib.sha256(Path('arxiv-paper/Paper_v1.pdf').read_bytes()).hexdigest()}
(s/'verification.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2))
