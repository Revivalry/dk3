# Maintaining the documentation site

The public engine manual is built from this repository's Markdown with MkDocs
Material. `mkdocs.yml` selects the primary navigation; `docs_site/hooks.py` adds
the remaining guides and class reviews to the directory and navigation.
The custom home template and stylesheet live in `docs_site/overrides` and
`docs/stylesheets`. The site has no analytics, login or remote font dependency.

## Build and preview

```sh
python3 -m venv .venv-docs
.venv-docs/bin/python -m pip install -r dkq3/tools/requirements-docs.txt
make docs-site MKDOCS=.venv-docs/bin/mkdocs
.venv-docs/bin/mkdocs serve
```

`make docs-site` builds strictly into `zig-out/docs-site` and validates rendered links,
anchors and the search index. Broken internal page links fail the build.
Repository-source links are converted to GitHub links; local evidence
and historical notes keep their scope. Every Markdown guide is indexed for search.
The documentation build requires neither game data nor an engine build.

## Publishing

`.github/workflows/pages.yml` validates documentation on pull requests and pushes
to `main`. A push to `main` also uploads and deploys the generated artifact through
GitHub Pages. PR jobs have read-only repository permissions and never deploy.
The deployment job alone has Pages write and OIDC permissions.

The repository must have Pages configured with **GitHub Actions** as its build
source. The public URL is <https://dmytrogajewski.github.io/dk3/>.
Generated HTML stays out of Git; Markdown remains the source of truth.

## Evidence and historical documents

Update [status](status.md) when the accepted implementation or verification state
changes. Keep [native acceptance](native-acceptance.md) as a scenario ledger;
retain rejected, failed and superseded outcomes with dates and scope. Tests and
map admissions do not establish complete campaign acceptance.

Historical operator notes and private-workspace instructions are retained for
traceability and clearly labeled. They are not public onboarding or claims about
a currently available hosted service. Asset packages and private report artifacts
are never copied into the Pages output.
