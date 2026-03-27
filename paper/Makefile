TEX      = Paper_v1
BIB      = References_v1
LATEX    = pdflatex
BIBTEX   = bibtex

.PHONY: all clean

all: $(TEX).pdf

$(TEX).pdf: $(TEX).tex $(BIB).bib sections/*.tex
	$(LATEX) $(TEX).tex
	$(BIBTEX) $(TEX)
	$(LATEX) $(TEX).tex
	$(LATEX) $(TEX).tex

clean:
	rm -f $(TEX).aux $(TEX).bbl $(TEX).blg $(TEX).log $(TEX).out \
	      $(TEX).spl $(TEX).toc $(TEX).lof $(TEX).lot $(TEX).fls \
	      $(TEX).fdb_latexmk $(TEX).synctex.gz $(TEX).nav $(TEX).snm \
	      sections/*.aux
