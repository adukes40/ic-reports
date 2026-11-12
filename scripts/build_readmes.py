"""Rebuild the query table in every queries/<category>/README.md, and the Categories table in the
root README, from the header block of each .sql file. Run it after adding a query or changing a
Status: `python scripts/build_readmes.py`. A new category folder needs a README.md with a
`# Heading` and a one-sentence blurb first; this script only fills in the tables.
"""
import re
import sys

from build_index import QUERIES, ROOT, folder_blurb, folder_label, parse

ROW = re.compile(r"^\|.*\|\s*$")


def swap_table(text: str, header: str, rows: list[str]) -> str:
    """Replace the first markdown table whose header line is `header` with header + rows."""
    lines = text.splitlines()
    start = lines.index(header)
    end = start
    while end < len(lines) and ROW.match(lines[end]):
        end += 1
    return "\n".join(lines[:start] + [header, lines[start + 1]] + rows + lines[end:]) + "\n"


def main() -> int:
    cats = []
    for folder in sorted(p for p in QUERIES.iterdir() if p.is_dir()):
        items = sorted((parse(p) for p in folder.rglob("*.sql")), key=lambda i: i["num"])
        cats.append((folder, len(items)))
        readme = folder / "README.md"
        header = "| # | Query | Status | What it finds |"
        if not items or header not in readme.read_text(encoding="utf-8"):
            continue   # vendors keeps its own layout
        rows = [f"| {i['num']} | [{i['name']}]({i['file'].split('/', 2)[2]}) | {i['status']} | {i['purpose']} |" for i in items]
        readme.write_text(swap_table(readme.read_text(encoding="utf-8"), header, rows), encoding="utf-8")
    root = ROOT / "README.md"
    cats.sort(key=lambda c: c[0].name == "14-vendors")   # vendors stays last
    rows = [f"| **[{folder_label(f)}](queries/{f.name}/)** | {folder_blurb(f).rstrip('.')} | {n} |" for f, n in cats]
    root.write_text(swap_table(root.read_text(encoding="utf-8"), "| Category | What's in it | Queries |", rows), encoding="utf-8")
    print(f"Rebuilt {len(cats)} category tables and the root README")
    return 0


if __name__ == "__main__":
    sys.exit(main())
