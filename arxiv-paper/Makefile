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
	sections/main_tables.tex \
	sections/main_figures.tex \
	sections/appendix.tex
TABLES := sections/tables/tableS_fallback_sensitivity.tex \
	sections/tables/tableS_centering_control.tex \
	sections/tables/table1_aggregate.tex \
	sections/tables/table2_model_comparison.tex \
	sections/tables/table3_by_beta_bucket.tex \
	sections/tables/table5_var_backtest_oos.tex \
	sections/tables/table6_oos_scorecard.tex \
	sections/tables/table7_jump_ablation.tex \
	sections/tables/tableS_jump_ablation_uncertainty.tex \
	sections/tables/tableS_generator_quantities.tex
FIGS := figs/main/Fig01-Empirical-Motivation.pdf \
	figs/main/Fig03-Model-Comparison.pdf \
	figs/main/Fig05-OoS-Composition.pdf \
	figs/main/Fig06-Variance-Preservation.pdf \
	figs/supplement/FigS02-Tail-Preservation.pdf
SOURCES := $(PAPER).tex $(BIB).bib neurips_2026.sty $(SECTIONS) $(TABLES) $(FIGS)

LATEXMK := latexmk
LATEXMK_FLAGS := -pdf -bibtex -interaction=nonstopmode -halt-on-error

.PHONY: all pdf source watch clean distclean

all: pdf

pdf: $(PDF)

$(PDF): $(SOURCES)
	$(LATEXMK) $(LATEXMK_FLAGS) $(PAPER)

source: $(ARCHIVE)

# Build first so the release archive includes the current generated bibliography.
$(ARCHIVE): $(PDF) $(SOURCES) Makefile
	COPYFILE_DISABLE=1 tar -czf $(ARCHIVE) $(SOURCES) $(PAPER).bbl

watch:
	$(LATEXMK) $(LATEXMK_FLAGS) -pvc $(PAPER)

clean:
	$(LATEXMK) -c $(PAPER)
	rm -f $(PAPER).bbl $(PAPER).run.xml $(PAPER).synctex.gz $(PAPER).fff $(PAPER).ttt

distclean: clean
	rm -f $(PDF) $(ARCHIVE)
