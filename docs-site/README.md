# Docs Site (MkDocs + GitHub Pages)

This directory contains the MkDocs project for end-user documentation (privacy policy, data privacy overview, and account deletion instructions). The site is intended to publish to GitHub Pages via the `gh-pages` branch.

## Structure
- `mkdocs.yml` — MkDocs configuration and navigation.
- `docs/` — Markdown content pages:
  - `index.md` (home)
  - `privacy-policy.md`
  - `data-privacy.md`
  - `account-deletion.md`

## Local preview
```bash
cd docs-site
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```
Visit http://127.0.0.1:8000 to preview.

## Publish to GitHub Pages
Option A: Quick deploy from your machine (uses `gh-pages` branch):
```bash
cd docs-site
source .venv/bin/activate  # if using the venv above
pip install -r requirements.txt
mkdocs gh-deploy --clean --force
```
This builds the site and pushes the output to the `gh-pages` branch. Ensure you have push access and GitHub Pages is configured to serve from that branch.

Option B: GitHub Actions (recommended for CI):
1) Add a workflow (e.g., `.github/workflows/docs.yml`) that installs `-r requirements.txt` and runs `mkdocs gh-deploy --clean --force --no-history`.
2) Give the workflow permissions to push to `gh-pages`.

## PDF export
- Enabled via `mkdocs-pdf-export-plugin` in `mkdocs.yml`.
- `mkdocs serve` will render per-page “Export to PDF” links; `mkdocs build` generates PDFs alongside the HTML output if requested.

## Theme
- Uses the Material for MkDocs theme with navigation and code-copy enhancements. If customizing palette or icons, update `theme` in `mkdocs.yml`.

## Customization checklist
- Replace placeholder emails (`privacy@example.com`) with your real support/privacy contact.
- Update `site_url` in `mkdocs.yml` to your GitHub Pages URL.
- Keep `privacy-policy.md`, `data-privacy.md`, and `account-deletion.md` aligned with the app’s actual data collection, SDKs, and in-app deletion path. Update before each release.

