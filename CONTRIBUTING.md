# Contributing to dk3

Bug reports, code and documentation improvements are welcome. Start with the
[build tutorial](docs/tutorials/build-engine.md) to set up the development tools.
Read [Engine architecture](docs/explanation/architecture.md) before changing the
runtime and [Add or change a class](docs/how-to/extend-class.md) for gameplay work.

## Build and check a change

Use Linux x86-64 and Zig 0.16.x. From the repository root, with the tutorial's
Python environment installed:

```sh
zig build -Dpython=.venv/bin/python
zig build test -Dpython=.venv/bin/python
```

`zig build test` runs the component checks, including formatting, class ownership,
codec/security and asset-tool fixtures. `make lint` and `make test` invoke the
same suite. Use `make fmt` to format Zig source.

Implement connected behavior before systematic gameplay verification. Use
`dkguard` for engine runs and `--headless` for software rendering without a
display. See [Headless runs](docs/how-to/headless.md) and the
[development workflow](docs/development-workflow.md).

For documentation-only changes, build and check the site with `make docs-site`.
See [Contributing to the documentation](docs/project/development.md#change-documentation)
for dependencies and preview commands.

## Report a problem

Open an [issue](https://github.com/Revivalry/dk3/issues) with the command you
ran, expected and actual behavior, OS, `zig version` and relevant log excerpts.
Remove personal paths and credentials. Do not attach retail files or extracted
assets. For vulnerabilities, follow [SECURITY.md](SECURITY.md).

## Submit a change

Fork the repository, make a focused branch and open a pull request. Describe the
behavior change and checks run. Update the relevant documentation when commands,
formats or requirements change.

Submit code you have the right to contribute under GPL-2.0-or-later. Preserve
copyright and license notices. Contributions do not transfer copyright; no
separate CLA or sign-off is required. Discuss third-party code and its license
before adding it.

Do not copy or mechanically translate unlicensed Gold implementation code. Use
original implementations and check behavior against synthetic fixtures or
observations. Proprietary strings and artwork belong in locally supplied game data.

Treat other contributors respectfully. Questions and small documentation fixes
are welcome.
