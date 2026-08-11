# JFDS submission checklist

Prepared for **The Journal of Finance and Data Science** as a **Research Article**.
The journal uses double-anonymized review and asks for editable, single-column source files.
Requirements were checked on 2026-08-10 against the journal's
[Guide for Authors](https://www.sciencedirect.com/journal/the-journal-of-finance-and-data-science/publish/guide-for-authors)
and Elsevier's [LaTeX instructions](https://www.elsevier.com/researcher/author/policies-and-guidelines/latex-instructions).

## Prepared files

- `JFDS_Anonymous_Manuscript.pdf`: anonymous main manuscript.
- `JFDS_Anonymous_Manuscript_Source.zip`: flat, editable LaTeX source archive.
- `JFDS_Title_Page.pdf` and `JFDS_Title_Page.tex`: authors, affiliations,
  corresponding-author address, acknowledgments, CRediT statement, competing-interest
  statement, and identifying repository links.
- `JFDS_Supplementary_Material.pdf`: anonymous supplementary material.
- `JFDS_Supplement_Source.zip`: flat, editable supplementary LaTeX source archive.
- `figures/`: the publication-quality figure PDFs for individual upload.
- `Highlights.txt`: optional four-item highlights file; every bullet is at most 85 characters.

Both LaTeX source archives are deliberately flat because Elsevier Editorial Manager does
not compile submissions containing subdirectories. Select `Paper_v1.tex` as the main file
for the manuscript archive and `Supplement_v1.tex` for the supplement archive.

## Requirements addressed

- Official `elsarticle` class, preprint layout, and one column.
- Author-year citations and an alphabetized Elsevier Harvard bibliography.
- Numbered manuscript sections and a standalone abstract and keyword list.
- Separate anonymous manuscript, anonymous supplement, and identifying title page.
- Acknowledgments appear only on the title page.
- Identifying repository URLs appear only on the title page.
- Figures and tables are cited, captioned, and supplied as editable source or PDF artwork.
- The title page states that all figures are intended for color reproduction online and
  in print.
- A competing-interest statement is present on the title page.
- A code and data availability statement is present in the manuscript and title page.
- The required generative-AI writing declaration appears before the references.
- Supplementary material has a descriptive title and independent S-numbering.
- The study uses market-price data and does not involve human participants, personal
  data, case reports, or human tissue; ethics approval and consent statements are not
  applicable.

## Author actions required before upload

These items require an author decision or attestation and cannot be completed automatically.

1. **Funding:** confirm whether the work received any specific grant or institutional
   support. Add the journal's funding statement to `TitlePage_v1.tex` if applicable. If
   there was no specific funding, confirm whether to add the standard no-funding statement.
2. **Competing-interests form:** each author must complete Elsevier's online declarations
   tool. Upload the resulting `.doc` or `.docx` file; the title-page statement does not
   replace that form.
3. **Author record:** verify author order, full names, affiliation, postal code, and both
   email addresses. Add ORCID identifiers in the submission system if desired.
4. **Generative-AI declaration:** confirm that the Codex disclosure accurately describes
   the authors' use and approve its wording.
5. **Repository anonymity:** confirm that withholding the identifying links from the
   reviewer PDF is acceptable; the links remain on the editor-only title page.
6. **Preprint:** update the existing arXiv record before submitting to JFDS and disclose
   the preprint when the submission system asks.
7. **Originality and permissions:** confirm that all authors approve submission, the paper
   is not under consideration elsewhere, and all artwork is original or appropriately
   licensed.
8. **Reviewer suggestions:** prepare names, affiliations, and current email addresses for
   suggested reviewers if requested by the submission form.
9. **Submission metadata:** paste the title, abstract, keywords, author details, funding,
   data statement, and competing-interest responses into the online form and verify them
   against the uploaded files.
10. **Open-access charge:** the journal currently lists an article publishing charge of
    USD 700 excluding taxes, payable after acceptance. Confirm the current amount and
    identify the institutional, grant, or personal payment route before submission.

## Recommended upload mapping

| Editorial Manager item | File |
|---|---|
| Manuscript | `JFDS_Anonymous_Manuscript.pdf` |
| LaTeX source files | `JFDS_Anonymous_Manuscript_Source.zip` |
| Title page | `JFDS_Title_Page.pdf` |
| Supplementary material | `JFDS_Supplementary_Material.pdf` |
| Supplementary LaTeX source | `JFDS_Supplement_Source.zip` |
| Highlights | `Highlights.txt` |
| Figures | Upload the files in `figures/` individually |
| Declaration of competing interests | Word file generated by Elsevier's declarations tool |

The graphical abstract is not listed as a mandatory JFDS file. Prepare one only if the
submission interface requests it or the authors want to supply the optional item.
