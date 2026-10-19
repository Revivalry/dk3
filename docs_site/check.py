#!/usr/bin/env python3
"""Validate rendered Pages links, anchors and search without game dependencies."""
from html.parser import HTMLParser
import json
from pathlib import Path
import sys
from urllib.parse import unquote, urlsplit


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.links, self.ids = [], set()
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attributes = dict(attrs)
        if "id" in attributes:
            self.ids.add(attributes["id"])
        if tag == "a" and attributes.get("href"):
            self.links.append(attributes["href"])


def check(directory, base_path):
    root = Path(directory).resolve()
    pages = {path: Page(path.read_text(encoding="utf-8")) for path in root.rglob("*.html")}
    failures = []
    for path, page in pages.items():
        for link in page.links:
            url = urlsplit(link)
            if url.scheme or url.netloc:
                continue
            destination = unquote(url.path)
            if destination.startswith(base_path):
                destination = destination[len(base_path):]
            if not url.path:
                target = path
            else:
                parent = root if url.path.startswith("/") else path.parent
                target = (parent / destination.lstrip("/")).resolve()
            if target.is_dir():
                target /= "index.html"
            if not target.exists():
                failures.append(f"{path.relative_to(root)}: missing {link}")
            elif url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                failures.append(f"{path.relative_to(root)}: missing anchor {link}")
    search = json.loads((root / "search/search_index.json").read_text(encoding="utf-8"))
    if not pages or not search.get("docs"):
        failures.append("HTML output or search index is empty")
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"Documentation: {len(pages)} HTML pages, internal links/anchors and search index passed.")


if __name__ == "__main__":
    check(sys.argv[1], sys.argv[2])
