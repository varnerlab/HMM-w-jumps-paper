PAPER := Paper_v1
BIB := References_v1
PDF := $(PAPER).pdf
ARCHIVE := HMM-w-jumps-arxiv-source.tar.gz

SECTIONS := sections/abstract.tex \
	sections/introduction.tex \
	sections/related.tex \
	sections/method_hmm.tex \
	sections/method_sim.tex \
	sections/results.tex \
	sections/discussion.tex \
	sections/conclusion.tex \
	sections/appendix.tex
TABLES := sections/tables/table1_aggregate.tex \
	sections/tables/table2_by_branch.tex \
	sections/tables/table2_model_comparison.tex \
	sections/tables/table3_by_beta_bucket.tex \
	sections/tables/table5_var_backtest_oos.tex \
	sections/tables/table6_oos_scorecard.tex
FIGS := figs/main/Fig01-Empirical-Motivation.pdf \
	figs/main/Fig03-Model-Comparison.pdf \
	figs/main/Fig04-Jump-Mix-Frontier.pdf \
	figs/main/Fig05-OoS-Composition.pdf \
	figs/main/Fig06-Variance-Preservation.pdf \
	figs/supplement/FigS01-Cross-Covariance.pdf \
	figs/supplement/FigS02-Tail-Preservation.pdf \
	figs/supplement/FigS03-R2-Distribution.pdf \
	figs/supplement/FigS04-Statistical-Validation.pdf \
	figs/supplement/FigS05-Model-Internals.pdf \
	figs/supplement/FigS06-Branch-Map.pdf
SOURCES := $(PAPER).tex $(BIB).bib neurips_2026.sty $(SECTIONS) $(TABLES) $(FIGS)

LATEXMK := latexmk
LATEXMK_FLAGS := -pdf -bibtex -interaction=nonstopmode -halt-on-error

.PHONY: all pdf source watch clean distclean

all: pdf

pdf: $(PDF)

$(PDF): $(SOURCES)
	$(LATEXMK) $(LATEXMK_FLAGS) $(PAPER)

source: $(ARCHIVE)

$(ARCHIVE): $(SOURCES) Makefile
	tar -czf $(ARCHIVE) $(SOURCES) Makefile

watch:
	$(LATEXMK) $(LATEXMK_FLAGS) -pvc $(PAPER)

clean:
	$(LATEXMK) -c $(PAPER)
	rm -f $(PAPER).bbl $(PAPER).run.xml $(PAPER).synctex.gz $(PAPER).fff $(PAPER).ttt

distclean: clean
	rm -f $(PDF) $(ARCHIVE)
