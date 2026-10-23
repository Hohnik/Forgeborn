"""Copies UI/Layout.lua into the layout editor, so the editor starts from the addon's layout, and rebuilds the
Figma plugin (tools/figma-plugin/build.js, needs Node).

    python3 tools/layout-editor/sync.py              # after editing UI/Layout.lua by hand
    python3 tools/layout-editor/sync.py --page OUT   # also write just the page part (for hosting it as a page)

tests/test_layout.lua fails when they differ.
"""
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
EDITOR = os.path.join(HERE, "index.html")
LAYOUT = os.path.join(ROOT, "UI", "Layout.lua")


def main():
    with open(LAYOUT, encoding="utf-8") as f:
        lua = f.read()
    with open(EDITOR, encoding="utf-8") as f:
        html = f.read()
    new = re.sub(r"(-- layout:start\n)[\s\S]*?(-- layout:end)", lambda m: m.group(1) + lua + m.group(2), html, count=1)
    if new != html:
        with open(EDITOR, "w", encoding="utf-8") as f:
            f.write(new)
        print("updated", os.path.relpath(EDITOR, ROOT))
    else:
        print("already up to date")
    build = os.path.join(ROOT, "tools", "figma-plugin", "build.js")
    if shutil.which("node"):
        subprocess.run(["node", build], check=True)
    else:
        print("Node not found: run node tools/figma-plugin/build.js to update the Figma plugin")
    if "--page" in sys.argv:
        out = sys.argv[sys.argv.index("--page") + 1]
        page = re.search(r"<!-- page:start[^\n]*\n([\s\S]*?)<!-- page:end -->", new).group(1)
        with open(out, "w", encoding="utf-8") as f:
            f.write(page)
        print("wrote", out)


if __name__ == "__main__":
    main()
