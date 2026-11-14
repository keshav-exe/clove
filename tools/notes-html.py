"""Turns a release notes file (a paragraph, then "- **Title:** text" bullets)
into the small HTML page Sparkle shows in its update window."""
import html
import re
import sys

def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    return re.sub(r"`(.+?)`", r"<code>\1</code>", text)

lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
paragraphs, bullets = [], []
for line in lines:
    line = line.strip()
    if line.startswith("- "):
        bullets.append(f"<li>{inline(line[2:])}</li>")
    elif line:
        paragraphs.append(f"<p>{inline(line)}</p>")

print("""<!doctype html><meta charset="utf-8">
<style>
:root { color-scheme: light dark; }
body { font: 13px -apple-system, system-ui; line-height: 1.45; margin: 12px 16px; }
ul { padding-left: 18px; } li { margin: 6px 0; }
code { font: 12px ui-monospace, monospace; }
</style>""")
print("\n".join(paragraphs))
if bullets:
    print("<ul>\n" + "\n".join(bullets) + "\n</ul>")
