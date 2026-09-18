#!/usr/bin/env python3
"""Compile the Atlantis Wiki into a FLAT folder of linked HTML pages (real-website style).
All pages are siblings in one directory; cross-links point to plain `name.html#anchor`.
Builds to /tmp then copies into Drive (gdrive FUSE mount chokes on rapid mkdir)."""
import os, re, html, shutil

# Resolve relative to this script's own location — robust to the gdrive mount
# flapping between ~/gdrive/Atlantis and ~/gdrive/Decker53153/Atlantis.
_HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(_HERE, "Wiki")
OUT = "/tmp/Wiki-Site"
FINAL = os.path.join(_HERE, "Wiki-Site")

GROUP_ORDER = ["Core-Setting", "History", "Factions", "Myth-Engineering",
               "Embedded-Agents", "Artifacts", "Missions", "Campaigns",
               "Design-Notes", "GM-Secrets"]
GROUP_LABEL = {g: g.replace("-", " ") for g in GROUP_ORDER}
GROUP_LABEL["GM-Secrets"] = "GM Secrets (spoilers)"

def fslug(text):
    s = text.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"[\s/]+", "-", s)
    return s

# ---- discover all markdown files (relative to ROOT) ----
mdfiles = []
for dp, _, fns in os.walk(ROOT):
    for fn in fns:
        if fn.endswith(".md"):
            mdfiles.append(os.path.relpath(os.path.join(dp, fn), ROOT))

# ---- build flat filename map: src_rel_md -> flat html name (unique) ----
base_count = {}
for rel in mdfiles:
    b = fslug(os.path.splitext(os.path.basename(rel))[0])
    base_count[b] = base_count.get(b, 0) + 1

flatmap = {}   # normalized rel md path -> flat html filename
used = set()
for rel in mdfiles:
    parts = rel.split(os.sep)
    base = fslug(os.path.splitext(parts[-1])[0])
    if base_count[base] > 1 and len(parts) > 1:
        name = fslug(parts[0]) + "-" + base        # disambiguate with folder
    else:
        name = base
    n = name; k = 2
    while (n + ".html") in used:
        n = f"{name}-{k}"; k += 1
    used.add(n + ".html")
    flatmap[os.path.normpath(rel)] = n + ".html"

# ---- per-page heading-anchor slugs (GitHub style) ----
slug_counts = {}
def slug(text):
    s = text.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s)
    s = re.sub(r"\s", "-", s)
    n = slug_counts.get(s, 0); slug_counts[s] = n + 1
    return s if n == 0 else f"{s}-{n}"

def fix_href(url, srcdir):
    if re.match(r"^[a-z]+://", url) or url.startswith("#"):
        return url
    path, sep, anc = url.partition("#")
    if path.endswith("/"):   # directory link -> index section anchor
        folder = os.path.basename(os.path.normpath(os.path.join(srcdir, path)))
        return "index.html#" + fslug(folder)
    if path.endswith(".md"):
        tgt = os.path.normpath(os.path.join(srcdir, path))
        flat = flatmap.get(tgt)
        if flat:
            return flat + (("#" + anc) if anc else "")
        return fslug(os.path.splitext(os.path.basename(path))[0]) + ".html" + (("#" + anc) if anc else "")
    return url

def inline(t, srcdir):
    t = html.escape(t)
    t = re.sub(r"`([^`]+)`", lambda m: "<code>" + m.group(1) + "</code>", t)
    t = re.sub(r"\[([^\]]+)\]\(([^)]+)\)",
               lambda m: f'<a href="{fix_href(m.group(2), srcdir)}">{m.group(1)}</a>', t)
    t = re.sub(r"\*\*\*(.+?)\*\*\*", r"<strong><em>\1</em></strong>", t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"__(.+?)__", r"<strong>\1</strong>", t)
    t = re.sub(r"\*(?!\s)([^*\n]+?)\*", r"<em>\1</em>", t)
    return t

def render(md, srcdir):
    lines = md.split("\n"); out = []; i = 0; in_code = False; code_buf = []
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("```"):
            if not in_code: in_code = True; code_buf = []
            else:
                out.append("<pre><code>" + html.escape("\n".join(code_buf)) + "</code></pre>"); in_code = False
            i += 1; continue
        if in_code: code_buf.append(line); i += 1; continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            lvl = len(m.group(1)); text = m.group(2).strip(); a = slug(text)
            out.append(f'<h{lvl} id="{a}">{inline(text, srcdir)}</h{lvl}>'); i += 1; continue
        if re.match(r"^\s*([-*_])\1\1+\s*$", line):
            out.append("<hr>"); i += 1; continue
        if "|" in line and i+1 < len(lines) and re.match(r"^\s*\|?[\s:|-]+\|?\s*$", lines[i+1]) and "-" in lines[i+1]:
            def cells(r):
                r = r.strip()
                if r.startswith("|"): r = r[1:]
                if r.endswith("|"): r = r[:-1]
                return [c.strip() for c in r.split("|")]
            header = cells(line); i += 2; rows = []
            while i < len(lines) and "|" in lines[i] and lines[i].strip():
                rows.append(cells(lines[i])); i += 1
            t = ["<table><thead><tr>"] + [f"<th>{inline(c, srcdir)}</th>" for c in header] + ["</tr></thead><tbody>"]
            for r in rows:
                t.append("<tr>" + "".join(f"<td>{inline(c, srcdir)}</td>" for c in r) + "</tr>")
            t.append("</tbody></table>"); out.append("".join(t)); continue
        if line.startswith(">"):
            buf = []
            while i < len(lines) and lines[i].startswith(">"):
                buf.append(lines[i].lstrip(">").strip()); i += 1
            out.append("<blockquote>" + inline(" ".join(buf), srcdir) + "</blockquote>"); continue
        if re.match(r"^\s*[-*+]\s+", line):
            buf = []
            while i < len(lines) and re.match(r"^\s*[-*+]\s+", lines[i]):
                buf.append(re.sub(r"^\s*[-*+]\s+", "", lines[i])); i += 1
            out.append("<ul>" + "".join(f"<li>{inline(x, srcdir)}</li>" for x in buf) + "</ul>"); continue
        if re.match(r"^\s*\d+\.\s+", line):
            buf = []
            while i < len(lines) and re.match(r"^\s*\d+\.\s+", lines[i]):
                buf.append(re.sub(r"^\s*\d+\.\s+", "", lines[i])); i += 1
            out.append("<ol>" + "".join(f"<li>{inline(x, srcdir)}</li>" for x in buf) + "</ol>"); continue
        if not line.strip(): i += 1; continue
        buf = [line]; i += 1
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#{1,6}\s|>|\s*[-*+]\s|\s*\d+\.\s|```)", lines[i]) and not re.match(r"^\s*([-*_])\1\1+\s*$", lines[i]):
            buf.append(lines[i]); i += 1
        out.append("<p>" + inline(" ".join(buf), srcdir) + "</p>")
    return "\n".join(out)

CSS = """
:root{--ink:#1b1b1f;--muted:#6b6b76;--accent:#8a6d3b;--rule:#e2ddd2;--bg:#fbf9f4;--code:#f4efe6;}
*{box-sizing:border-box;}
body{margin:0;font-family:-apple-system,Georgia,'Times New Roman',serif;color:var(--ink);background:var(--bg);line-height:1.62;}
.wrap{max-width:820px;margin:0 auto;padding:28px 56px 70px;}
.topnav{font-family:-apple-system,Arial,sans-serif;font-size:.82rem;padding:10px 0 4px;border-bottom:1px solid var(--rule);margin-bottom:22px;color:var(--muted);}
.topnav a{color:var(--accent);text-decoration:none;}
.topnav .tag{float:right;text-transform:uppercase;letter-spacing:.1em;font-size:.7rem;font-weight:700;opacity:.8;}
h1,h2,h3,h4,h5,h6{font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;line-height:1.25;color:#23201a;}
h1{font-size:2.0rem;border-bottom:3px solid var(--accent);padding-bottom:.3em;margin-top:.2em;}
h2{font-size:1.5rem;margin-top:1.6em;border-bottom:1px solid var(--rule);padding-bottom:.2em;}
h3{font-size:1.2rem;margin-top:1.4em;color:var(--accent);}
h4{font-size:1.05rem;margin-top:1.2em;}
p{margin:.7em 0;}
a{color:#5a4a8a;text-decoration:none;border-bottom:1px solid rgba(90,74,138,.3);}
code{background:var(--code);padding:.12em .4em;border-radius:4px;font-family:'SF Mono',Menlo,Consolas,monospace;font-size:.88em;}
pre{background:var(--code);padding:16px 18px;border-radius:8px;overflow-x:auto;border:1px solid var(--rule);}
pre code{background:none;padding:0;font-size:.82rem;line-height:1.4;white-space:pre;}
blockquote{margin:1em 0;padding:.4em 1.1em;border-left:4px solid var(--accent);background:rgba(138,109,59,.06);color:#42403a;}
table{border-collapse:collapse;width:100%;margin:1.1em 0;font-size:.92rem;}
th,td{border:1px solid var(--rule);padding:7px 11px;text-align:left;vertical-align:top;}
th{background:rgba(138,109,59,.1);font-family:-apple-system,Arial,sans-serif;}
tr:nth-child(even) td{background:rgba(0,0,0,.018);}
hr{border:none;border-top:1px solid var(--rule);margin:1.6em 0;}
ul,ol{padding-left:1.5em;} li{margin:.25em 0;}
.idx h1{font-size:2.3rem;}
.idx .sub{color:var(--muted);font-style:italic;margin-top:-.4em;}
.idx h2{color:var(--accent);text-transform:uppercase;letter-spacing:.06em;font-size:1.05rem;border:none;margin:1.4em 0 .3em;}
.idx ul{list-style:none;padding-left:.2em;columns:2;column-gap:40px;}
.idx li{margin:.28em 0;break-inside:avoid;}
"""

def page(title, tag, content, is_index=False):
    nav = ""
    if not is_index:
        nav = f'<div class="topnav"><a href="index.html">← Wiki Index</a>'
        if tag: nav += f'<span class="tag">{html.escape(tag)}</span>'
        nav += '</div>'
    cls = "wrap idx" if is_index else "wrap"
    return (f'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width,initial-scale=1">'
            f'<title>{html.escape(title)}</title>'
            f'<link rel="stylesheet" href="style.css"></head>'
            f'<body><div class="{cls}">{nav}\n{content}\n</div></body></html>')

# ---- build (flat) ----
if os.path.exists(OUT): shutil.rmtree(OUT)
os.makedirs(OUT)
with open(os.path.join(OUT, "style.css"), "w") as f: f.write(CSS)

by_group = {}
readme_flat = None
for rel in mdfiles:
    norm = os.path.normpath(rel)
    parts = rel.split(os.sep)
    src = os.path.join(ROOT, rel)
    with open(src, encoding="utf-8") as fh: md = fh.read()
    slug_counts.clear()
    body = render(md, os.path.dirname(rel))
    tag = GROUP_LABEL.get(parts[0], "") if len(parts) > 1 else ""
    title = os.path.splitext(parts[-1])[0].replace("-", " ")
    flat = flatmap[norm]
    with open(os.path.join(OUT, flat), "w", encoding="utf-8") as fh:
        fh.write(page(title, tag, body))
    if len(parts) == 1:
        readme_flat = flat
    else:
        by_group.setdefault(parts[0], []).append((title, flat))

# ---- index (flat links) ----
idx = ['<h1>Atlantis Campaign Wiki</h1>',
       f'<p class="sub">{len(mdfiles)} linked documents — reference compilation</p>']
if readme_flat:
    idx.append(f'<p><a href="{readme_flat}"><strong>\U0001f4d6 Start here: README / overview</strong></a></p>')
for g in GROUP_ORDER:
    if g not in by_group: continue
    idx.append(f'<h2 id="{fslug(g)}">{html.escape(GROUP_LABEL[g])}</h2><ul>')
    for title, flat in sorted(by_group[g]):
        idx.append(f'<li><a href="{flat}">{html.escape(title)}</a></li>')
    idx.append("</ul>")
with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as fh:
    fh.write(page("Atlantis Campaign Wiki", "", "".join(idx), is_index=True))

print(f"OK -> {OUT}  (flat: {len(mdfiles)} pages + index + style.css)")

# ---- copy into Drive ----
if os.path.exists(FINAL): shutil.rmtree(FINAL)
shutil.copytree(OUT, FINAL)
print(f"copied -> {FINAL}")
