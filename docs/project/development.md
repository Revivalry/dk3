# Contribute to dk3

Start with the [engine build tutorial](../tutorials/build-engine.md), then read the
[architecture](../explanation/architecture.md) and the source area you want to change.

## Build and check code

```sh
zig build -Dpython=.venv/bin/python
zig build test -Dpython=.venv/bin/python
```

The component suite includes runtime, codec/security and process tests, formatting,
class ownership and synthetic asset-tool fixtures. `make lint` and `make test`
both invoke that suite. `make fmt` formats Zig code.

For gameplay changes, build connected behavior before running the relevant scenarios.
Keep the inputs and failure details needed to reproduce a problem. Use `dkguard`
for engine runs; see [Headless runs](../how-to/headless.md).

## Change documentation

Choose the document's purpose before writing:

- A **tutorial** walks a learner through a concrete result.
- A **how-to guide** solves one task for a reader who already knows the basics.
- A **reference** describes options, commands, formats and defaults.
- An **explanation** describes how a system works and why its design matters.

Write instructions in terms of the reader's task. Keep implementation journals,
review records and test reports in the repository's development records rather
than the user guide. Link related documents instead of repeating their contents.

To build the site:

```sh
python3 -m venv .venv-docs
.venv-docs/bin/python -m pip install -r dkq3/tools/requirements-docs.txt
make docs-site MKDOCS=.venv-docs/bin/mkdocs
```

To preview it locally, run `.venv-docs/bin/mkdocs serve`.
The site source is Markdown under `docs/`, selected by the navigation in `mkdocs.yml`.

## Report or submit a change

Open a [bug report](https://github.com/dmytrogajewski/dk3/issues) with commands,
expected behavior, actual behavior and relevant logs. Report vulnerabilities through
the [private security form](https://github.com/dmytrogajewski/dk3/security/advisories/new).

For code, file a pull request with the behavior change and checks run. The
[contribution guide](https://github.com/dmytrogajewski/dk3/blob/main/CONTRIBUTING.md)
describes licensing and submission requirements.
