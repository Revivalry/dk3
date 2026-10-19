"""Publish the selected guides and redirect older documentation URLs."""
from html import escape
from pathlib import Path
import posixpath
import re
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
REPOSITORY = "https://github.com/dmytrogajewski/dk3/blob/main/"
REPLACEMENTS = {
    "getting-started.md": "tutorials/build-engine.md",
    "building.md": "reference/build.md",
    "assets.md": "reference/assets.md",
    "engine.md": "explanation/architecture.md",
    "protocol.md": "reference/network.md",
    "save-format.md": "reference/saves.md",
    "status.md": "project/status.md",
    "documentation.md": "index.md",
    "site-maintenance.md": "project/development.md",
    "vulkan-remaster.md": "reference/rendering.md",
    "seamless-worlds.md": "explanation/worlds.md",
    "multiplayer.md": "how-to/host-multiplayer.md",
}


def paths_in(nav):
    for item in nav:
        if isinstance(item, str):
            yield item
        elif isinstance(item, dict):
            for value in item.values():
                if isinstance(value, list):
                    yield from paths_in(value)
                elif isinstance(value, str):
                    yield value


def on_files(files, config):
    selected = set(paths_in(config.nav))
    for file in list(files):
        if file.is_documentation_page() and file.src_uri not in selected:
            files.remove(file)
    return files


def on_page_markdown(markdown, page, config, files):
    selected = set(paths_in(config.nav))

    def source_link(match):
        label, destination = match[1], match[2]
        if re.match(r"(?:[a-z]+:|#|/)", destination, re.I):
            return match[0]
        relative, separator, anchor = destination.partition("#")
        target = (DOCS / Path(page.file.src_uri).parent / relative).resolve()
        if target.is_relative_to(DOCS):
            if target.relative_to(DOCS).as_posix() in selected:
                return match[0]
            if target.suffix != ".md":
                return match[0]
        if target.is_relative_to(ROOT) and target.exists():
            repository = REPOSITORY if target.is_file() else REPOSITORY.replace("/blob/", "/tree/")
            return "[" + label + "](" + repository + quote(target.relative_to(ROOT).as_posix()) + (separator + anchor if separator else "") + ")"
        return match[0]

    return re.sub(r"(?<!!)\[([^\]]+)\]\(([^\s)]+)\)", source_link, markdown)


def page_url(source):
    path = Path(source)
    if path.name == "index.md":
        parent = path.parent.as_posix()
        return "" if parent == "." else parent + "/"
    return path.with_suffix("").as_posix() + "/"


def on_post_build(config):
    selected = set(paths_in(config.nav))
    for path in DOCS.rglob("*.md"):
        source = path.relative_to(DOCS).as_posix()
        if source in selected:
            continue
        old_url = page_url(source)
        replacement = REPLACEMENTS.get(source)
        if replacement:
            target = posixpath.relpath(page_url(replacement) or ".", old_url)
            if not target.endswith("/"):
                target += "/"
        else:
            target = REPOSITORY + "docs/" + quote(source)
        output = Path(config.site_dir) / old_url / "index.html"
        output.parent.mkdir(parents=True, exist_ok=True)
        safe_target = escape(target, quote=True)
        output.write_text(
            '<!doctype html><html lang="en"><head><meta charset="utf-8">'
            '<meta name="robots" content="noindex">'
            '<meta http-equiv="refresh" content="0; url=' + safe_target + '">'
            '<link rel="canonical" href="' + safe_target + '">'
            '<title>Documentation moved</title></head><body>'
            '<p><a href="' + safe_target + '">Continue to the documentation</a>.</p>'
            '</body></html>', encoding="utf-8",
        )
