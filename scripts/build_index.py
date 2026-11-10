"""Build site/queries.json from the header block at the top of every queries/**/*.sql file,
and copy the published .sql files into site/queries/. Queries marked "Status: Broken" stay
in the repo but are left off the site.

Run by the GitHub Action on every push; run it locally with `python scripts/build_index.py`.
"""
import json
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
QUERIES = ROOT / "queries"
OUT = ROOT / "site" / "queries.json"

FIELD = re.compile(r"^\s{3}([A-Z][A-Za-z ]*?):\s+(.*)$")   # "   Status:   Confirmed good"
CONT = re.compile(r"^\s{14,}(\S.*)$")                      # wrapped continuation line


def folder_label(folder: pathlib.Path) -> str:
    readme = folder / "README.md"
    if readme.exists():
        for line in readme.read_text(encoding="utf-8").splitlines():
            if line.startswith("# "):
                return line[2:].strip()
    return folder.name.split("-", 1)[-1].replace("-", " ").title()


def folder_blurb(folder: pathlib.Path) -> str:
    """First sentence of the first paragraph under the README heading."""
    readme = folder / "README.md"
    if not readme.exists():
        return ""
    for line in readme.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith(("#", "|", "[", "Open a query")):
            return re.split(r"(?<=\.)\s", line, maxsplit=1)[0]
    return ""


def parse(path: pathlib.Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if not text.lstrip().startswith("/*") or "*/" not in text:
        raise ValueError(f"{path}: missing the /* ... */ info header")
    header, body = text.split("*/", 1)
    title = re.search(r"#(\d+)\s+(.+)", header)
    if not title:
        raise ValueError(f"{path}: header needs a '#<number>  <name>' line")
    fields, cur = {}, None
    for line in header.splitlines():
        m = FIELD.match(line)
        if m and "HOW TO USE" not in line:
            cur = m.group(1).strip()
            fields[cur] = m.group(2).strip()
        elif cur and CONT.match(line):
            fields[cur] += " " + CONT.match(line).group(1).strip()
        else:
            cur = None
    rel = path.relative_to(ROOT).as_posix()
    top = path.relative_to(QUERIES).parts[0]
    sub = path.relative_to(QUERIES).parts[1] if len(path.relative_to(QUERIES).parts) > 2 else ""
    params = fields.pop("Params", "").split("  (")[0]
    return {
        "id": f"{top.split('-', 1)[0]}-{title.group(1)}" + (f"-{sub}" if sub else ""),
        "num": int(title.group(1)),
        "name": title.group(2).strip(),
        "cat": top,
        "catLabel": folder_label(QUERIES / top),
        "group": folder_label(QUERIES / top / sub) if sub else "",
        "status": fields.pop("Status", "Not run yet"),
        "type": fields.pop("Type", ""),
        "purpose": fields.pop("Purpose", ""),
        "output": fields.pop("Output", ""),
        "tables": fields.pop("Tables", ""),
        "params": params,
        "check": fields.pop("Check", ""),
        "extra": {k: v for k, v in fields.items() if k != "Category"},   # vendor fields etc.
        "file": rel,
        "sql": body.lstrip("\n"),
    }


def main() -> int:
    items = [parse(p) for p in sorted(QUERIES.rglob("*.sql"))]
    hidden = [i["file"] for i in items if i["status"] == "Broken"]
    items = [i for i in items if i["status"] != "Broken"]
    ids = [i["id"] for i in items]
    dupes = {i for i in ids if ids.count(i) > 1}
    if dupes:
        print("Duplicate query ids:", ", ".join(sorted(dupes)), file=sys.stderr)
        return 1
    cats = []
    for folder in sorted(p for p in QUERIES.iterdir() if p.is_dir()):
        cats.append({"key": folder.name, "label": folder_label(folder), "blurb": folder_blurb(folder)})
    OUT.parent.mkdir(exist_ok=True)
    site_q = OUT.parent / "queries"
    if site_q.exists():
        shutil.rmtree(site_q)
    for i in items:
        dest = OUT.parent / i["file"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / i["file"], dest)
    for c in cats:   # keep folder READMEs (and empty categories) in the downloads
        readme = QUERIES / c["key"] / "README.md"
        if readme.exists():
            (site_q / c["key"]).mkdir(parents=True, exist_ok=True)
            shutil.copy2(readme, site_q / c["key"] / "README.md")
    OUT.write_text(json.dumps({"categories": cats, "queries": items}, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {len(items)} queries in {len(cats)} categories to {OUT.relative_to(ROOT)}")
    for h in hidden:
        print(f"Left off the site (Broken): {h}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
