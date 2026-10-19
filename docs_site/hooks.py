"""Keep all checked-in guides discoverable and link repository files on GitHub."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
REPOSITORY = "https://github.com/dmytrogajewski/dk3/blob/main/"


def title(path):
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^# (.+)$", text, re.M)
    return match[1] if match else path.stem.replace("-", " ").title()


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


def on_config(config):
    listed = set(paths_in(config.nav))
    classes, references = [], []
    for path in sorted(DOCS.rglob("*.md")):
        relative = path.relative_to(DOCS).as_posix()
        if relative in listed:
            continue
        entry = {title(path): relative}
        (classes if relative.startswith("class-porting/") else references).append(entry)
    config.nav.append({"Class reviews": classes})
    config.nav.append({"Engineering records": references})
    config.extra["guide_count"] = len(list(DOCS.rglob("*.md")))
    return config


def on_page_markdown(markdown, page, config, files):
    if page.file.src_uri == "documentation.md":
        sections = []
        for group in config.nav:
            for name, entries in group.items():
                if not isinstance(entries, list):
                    continue
                sections.append("## " + name)
                for entry in entries:
                    for label, destination in entry.items():
                        sections.append(f"- [{label}]({destination})")
        markdown = markdown.replace("<!-- DOCUMENTATION_DIRECTORY -->", "\n\n".join(sections))

    # Source links outside docs belong to the repository, rather than Pages paths.
    def source_link(match):
        label, destination = match[1], match[2]
        if re.match(r"(?:[a-z]+:|#|/)", destination, re.I):
            return match[0]
        relative, separator, anchor = destination.partition("#")
        target = (DOCS / Path(page.file.src_uri).parent / relative).resolve()
        if target == DOCS or DOCS in target.parents:
            return match[0]
        if ROOT in target.parents and target.exists() and not target.is_relative_to(ROOT / "zig-out"):
            repository = REPOSITORY if target.is_file() else REPOSITORY.replace("/blob/", "/tree/")
            return "[" + label + "](" + repository + target.relative_to(ROOT).as_posix() + (separator + anchor if separator else "") + ")"
        # Old investigations reference sibling private checkouts, retired files or
        # local captures. Preserve their labels without publishing broken URLs.
        return label + " (local historical reference)"

    return re.sub(r"(?<!!)\[([^\]]+)\]\(([^\s)]+)\)", source_link, markdown)
