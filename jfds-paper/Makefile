# Build and package the JFDS elsarticle submission.
# Requires: latexmk, pdflatex, bibtex, zip, and kpsewhich.

PAPER       := Paper_v1
SUPP        := Supplement_v1
TITLE       := TitlePage_v1
BIB         := References_v1
COMMON      := elsarticle-preamble.tex
SECTIONS    := $(wildcard sections/*.tex) $(wildcard sections/tables/*.tex)
FIGS        := $(shell find figs -type f)
OUTPUT_DIR  := output/pdf

LATEXMK       := latexmk
LATEXMK_FLAGS := -pdf -bibtex -interaction=nonstopmode -halt-on-error

.PHONY: all pdf paper supplement title outputs submission watch clean distclean view

all: outputs

# Build the supplement between two main-paper passes so xr-hyper resolves
# cross-document references in both directions from a clean checkout.
pdf: paper supplement
	$(LATEXMK) $(LATEXMK_FLAGS) $(PAPER)

paper: $(PAPER).tex $(COMMON) $(BIB).bib $(SECTIONS) $(FIGS)
	$(LATEXMK) $(LATEXMK_FLAGS) $(PAPER)

supplement: $(SUPP).tex $(COMMON) $(BIB).bib sections/appendix.tex $(FIGS)
	$(LATEXMK) $(LATEXMK_FLAGS) $(SUPP)

title: $(TITLE).tex
	$(LATEXMK) $(LATEXMK_FLAGS) $(TITLE)

outputs: pdf title
	mkdir -p $(OUTPUT_DIR)
	cp $(PAPER).pdf $(OUTPUT_DIR)/JFDS_Anonymous_Manuscript.pdf
	cp $(SUPP).pdf $(OUTPUT_DIR)/JFDS_Supplementary_Material.pdf
	cp $(TITLE).pdf $(OUTPUT_DIR)/JFDS_Title_Page.pdf

submission: outputs
	./scripts/build_submission.sh "$(CURDIR)"

watch:
	$(LATEXMK) $(LATEXMK_FLAGS) -pvc $(PAPER)

view: outputs
	open $(OUTPUT_DIR)/JFDS_Anonymous_Manuscript.pdf

clean:
	$(LATEXMK) -c $(PAPER)
	$(LATEXMK) -c $(SUPP)
	$(LATEXMK) -c $(TITLE)
	rm -f $(PAPER).bbl $(PAPER).run.xml $(PAPER).synctex.gz $(PAPER).fff $(PAPER).ttt
	rm -f $(SUPP).bbl $(SUPP).run.xml $(SUPP).synctex.gz
	rm -f $(TITLE).bbl $(TITLE).run.xml $(TITLE).synctex.gz

distclean: clean
	rm -f $(PAPER).pdf $(SUPP).pdf $(TITLE).pdf
