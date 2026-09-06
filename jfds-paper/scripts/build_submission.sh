#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:?Pass the absolute jfds-paper path as the first argument}"
if [[ "${ROOT}" != /* || ! -f "${ROOT}/Paper_v1.tex" ]]; then
  echo "Invalid jfds-paper root: ${ROOT}" >&2
  exit 1
fi

OUT="${ROOT}/submission"
STAGE="$(mktemp -d /private/tmp/jfds-submission.XXXXXX)"
trap 'rm -rf "${STAGE}"' EXIT

MAIN_STAGE="${STAGE}/anonymous-main"
SUPP_STAGE="${STAGE}/anonymous-supplement"
mkdir -p "${MAIN_STAGE}" "${SUPP_STAGE}"

if [[ "${OUT}" != "${ROOT}/submission" ]]; then
  echo "Refusing to replace unexpected output path: ${OUT}" >&2
  exit 1
fi
rm -rf "${OUT}"
mkdir -p "${OUT}/figures"

ELSARTICLE_CLS="$(kpsewhich elsarticle.cls)"
ELSARTICLE_HARV="$(kpsewhich elsarticle-harv.bst)"
if [[ -z "${ELSARTICLE_CLS}" || -z "${ELSARTICLE_HARV}" ]]; then
  echo "The elsarticle class or author-year BibTeX style is unavailable." >&2
  exit 1
fi

MAIN_SECTIONS=(
  abstract.tex introduction.tex related.tex method_hmm.tex method_sim.tex
  results.tex discussion.tex conclusion.tex
)
MAIN_TABLES=(
  table1_aggregate.tex table2_model_comparison.tex
  table5_var_backtest_oos.tex table6_oos_scorecard.tex
  table7_jump_ablation.tex
)
MAIN_FIGURES=(
  Fig01-Empirical-Motivation.pdf Fig03-Model-Comparison.pdf
  Fig04-Jump-Mix-Frontier.pdf Fig05-OoS-Composition.pdf
  Fig06-Variance-Preservation.pdf
)
SUPP_TABLES=(table2_by_branch.tex table3_by_beta_bucket.tex tableS_jump_ablation_uncertainty.tex tableS_jump_ablation_episodes.tex tableS_generator_quantities.tex tableS_acf_prediction.tex tableS_kurt_composition.tex)
SUPP_FIGURES=(
  FigS01-Cross-Covariance.pdf FigS02-Tail-Preservation.pdf
  FigS03-R2-Distribution.pdf FigS04-Statistical-Validation.pdf
  FigS05-Model-Internals.pdf FigS06-Branch-Map.pdf
)

cp "${ROOT}/Paper_v1.tex" "${ROOT}/elsarticle-preamble.tex" \
  "${ROOT}/References_v1.bib" "${ROOT}/Paper_v1.bbl" \
  "${ROOT}/Supplement_v1.aux" "${MAIN_STAGE}/"
for file in "${MAIN_SECTIONS[@]}"; do
  cp "${ROOT}/sections/${file}" "${MAIN_STAGE}/"
done
for file in "${MAIN_TABLES[@]}"; do
  cp "${ROOT}/sections/tables/${file}" "${MAIN_STAGE}/"
done
for file in "${MAIN_FIGURES[@]}"; do
  cp "${ROOT}/figs/main/${file}" "${MAIN_STAGE}/"
  cp "${ROOT}/figs/main/${file}" "${OUT}/figures/"
done
cp "${ELSARTICLE_CLS}" "${ELSARTICLE_HARV}" "${MAIN_STAGE}/"
perl -pi -e 's#sections/tables/##g; s#sections/##g; s#figs/main/##g' "${MAIN_STAGE}"/*.tex

cp "${ROOT}/Supplement_v1.tex" "${ROOT}/elsarticle-preamble.tex" \
  "${ROOT}/References_v1.bib" "${ROOT}/Supplement_v1.bbl" \
  "${ROOT}/Paper_v1.aux" "${ROOT}/sections/appendix.tex" "${SUPP_STAGE}/"
for file in "${SUPP_TABLES[@]}"; do
  cp "${ROOT}/sections/tables/${file}" "${SUPP_STAGE}/"
done
for file in "${SUPP_FIGURES[@]}"; do
  cp "${ROOT}/figs/supplement/${file}" "${SUPP_STAGE}/"
  cp "${ROOT}/figs/supplement/${file}" "${OUT}/figures/"
done
cp "${ELSARTICLE_CLS}" "${ELSARTICLE_HARV}" "${SUPP_STAGE}/"
perl -pi -e 's#sections/tables/##g; s#sections/##g; s#figs/supplement/##g' "${SUPP_STAGE}"/*.tex

(
  cd "${MAIN_STAGE}"
  zip -q "${OUT}/JFDS_Anonymous_Manuscript_Source.zip" ./*
)
(
  cd "${SUPP_STAGE}"
  zip -q "${OUT}/JFDS_Supplement_Source.zip" ./*
)

cp "${ROOT}/output/pdf/JFDS_Anonymous_Manuscript.pdf" "${OUT}/"
cp "${ROOT}/output/pdf/JFDS_Supplementary_Material.pdf" "${OUT}/"
cp "${ROOT}/output/pdf/JFDS_Title_Page.pdf" "${OUT}/"
cp "${ROOT}/TitlePage_v1.tex" "${OUT}/JFDS_Title_Page.tex"
cp "${ROOT}/Highlights.txt" "${OUT}/Highlights.txt"
cp "${ROOT}/Submission_Checklist.md" "${OUT}/Submission_Checklist.md"

echo "JFDS submission files written to ${OUT}"
