# JFDS figure assets

The directories follow the figure numbers produced by `Paper_v1.tex`:

- `main/`: cited main-text figures, named `Fig01-...` through `Fig06-...`.
- `supplement/`: cited online-appendix figures, named `FigS01-...` through
  `FigS07-...`.
- `diagnostics/`: optional generated plots that are not cited in the paper.

There is no `main/Fig02-...pdf`: Figure 2 is the HMM-WJ architecture drawn
directly in `sections/method_hmm.tex` with TikZ.

Do not place numbered figure PDFs directly in this directory. Generation
scripts should write to the appropriate subdirectory using the compiled paper
number, not an experiment-local or historical number.
