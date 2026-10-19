ZIG ?= zig
MKDOCS ?= mkdocs

.PHONY: build test lint fmt docs-site
build:
	$(ZIG) build -Doptimize=ReleaseSafe

test:
	$(ZIG) build test

lint:
	$(ZIG) build test

fmt:
	$(ZIG) fmt build.zig build.zig.zon build src

docs-site:
	$(MKDOCS) build --strict
	python3 docs_site/check.py zig-out/docs-site /dk3/
