# Makefile for Paper_v1 (variance-corrected SIM composition)
# Requires: latexmk, pdflatex, bibtex

PAPER   := Paper_v1
SUPP    := Supplement_v1
BIB     := References_v1
TEX     := $(PAPER).tex
PDF     := $(PAPER).pdf
SUPP_TEX := $(SUPP).tex
SUPP_PDF := $(SUPP).pdf
SECTIONS := $(wildcard sections/*.tex) $(wildcard sections/tables/*.tex)
FIGS     := $(shell find figs -type f)

LATEXMK := latexmk
LATEXMK_FLAGS := -pdf -bibtex -interaction=nonstopmode -halt-on-error

.PHONY: all pdf paper supplement watch clean distclean view

all: pdf

pdf: paper supplement
	$(LATEXMK) $(LATEXMK_FLAGS) $(PAPER)

paper: $(TEX) $(BIB).bib $(SECTIONS) $(FIGS) neurips_2026.sty
	$(LATEXMK) $(LATEXMK_FLAGS) $(PAPER)

supplement: $(SUPP_TEX) $(BIB).bib sections/appendix.tex $(FIGS) neurips_2026.sty
	$(LATEXMK) $(LATEXMK_FLAGS) $(SUPP)

# Continuous rebuild on file changes (Ctrl-C to stop).
watch:
	$(LATEXMK) $(LATEXMK_FLAGS) -pvc $(PAPER)

# Open the built PDF (macOS).
view: $(PDF)
	open $(PDF)

# Remove intermediate build artifacts, keep the PDF.
clean:
	$(LATEXMK) -c $(PAPER)
	$(LATEXMK) -c $(SUPP)
	rm -f $(PAPER).bbl $(PAPER).run.xml $(PAPER).synctex.gz $(PAPER).fff $(PAPER).ttt
	rm -f $(SUPP).bbl $(SUPP).run.xml $(SUPP).synctex.gz

# Remove everything, including the PDF.
distclean:
	$(LATEXMK) -C $(PAPER)
	$(LATEXMK) -C $(SUPP)
	rm -f $(PAPER).bbl $(PAPER).run.xml $(PAPER).synctex.gz $(PAPER).fff $(PAPER).ttt
	rm -f $(SUPP).bbl $(SUPP).run.xml $(SUPP).synctex.gz
