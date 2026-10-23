"""Checks that every Blizzard API, template, font, atlas, sound and event Forgeborn uses exists in WoW Forever.

Reads tools/apicheck/forever_api.txt.gz (built by gen_fixture.py from Blizzard's UI source) and the addon's
Lua files. Prints each name it can't find and exits with 1 if there are any.

    python3 tools/apicheck/check_api.py
"""
import gzip
import os
import re
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
# Another client's list can be checked with: check_api.py path/to/api.txt.gz
FIXTURE = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "apicheck", "forever_api.txt.gz")


def addon_files():
    toc = open(os.path.join(ROOT, "Forgeborn.toc"), encoding="utf-8").read()
    files = [line.strip().replace("\\", "/") for line in toc.splitlines() if line.strip() and not line.startswith("#")]
    return [os.path.join(ROOT, f) for f in files]


def load_sets():
    sets, version = {}, "?"
    with gzip.open(FIXTURE, "rt", encoding="utf-8") as f:
        for line in f:
            section, _, value = line.rstrip("\n").partition(" ")
            if section == "version":
                version = value
            else:
                sets.setdefault(section, set()).add(value)
    return sets, version


# Functions of WoW's Lua environment (the C side), not in the generated docs or Blizzard's Lua.
# issecretvalue: the secret-value test, called 25 times by Forever's own UI code.
LUA_ENVIRONMENT = {"strtrim", "strsplit", "tinsert", "tremove", "wipe", "format", "date", "time",
                   "issecure", "securecall", "hooksecurefunc", "Enum", "issecretvalue"}

# Used only when the addon runs in WoW Forever (see Compat.lua), so another client may lack them.
FOREVER_ONLY = {"ColoredProgressBarTemplate", "WOW_PROJECT_CAMELOT"}


def main():
    sets, version = load_sets()
    forever = version.startswith("1.60")
    namespaces = {name: sets.get("ns:" + name, set()) for name in sets["namespace"]}
    # Defined in Blizzard's Lua or XML, documented, or called/read by Blizzard's own code.
    known_globals = (sets["globalFunctions"] | sets["luaGlobals"] | sets["calledGlobals"]
                     | sets["referencedGlobals"] | LUA_ENVIRONMENT | set(namespaces))

    files = addon_files()
    sources = {f: open(f, encoding="utf-8").read() for f in files}
    problems = []

    # 1. Globals read by the addon (luacheck lists them as undefined when no WoW std is given).
    out = subprocess.run(["luacheck", "--std", "lua51", "--no-config", "--formatter", "plain", "--codes"] + files,
                         capture_output=True, text=True).stdout
    own = {"ForgebornCharDB", "SLASH_FORGEBORN1", "SLASH_FORGEBORN2", "Forgeborn_OnCompartmentClick",
           "Forgeborn_OnCompartmentEnter", "Forgeborn_OnCompartmentLeave", "ForgebornFrame"}
    used = set(re.findall(r"\(W11[123]\) (?:accessing undefined|setting non-standard global|mutating non-standard global) variable '?(\w+)'?", out))
    used |= set(re.findall(r"variable '(\w+)'", out))
    for name in sorted(used - own):
        if name not in known_globals and not (name in FOREVER_ONLY and not forever):
            problems.append("global " + name)

    # 2. C_ namespace functions.
    for f, src in sources.items():
        for ns, fn in re.findall(r'\b(C_\w+)\.(\w+)', src):
            if ns not in namespaces or fn not in namespaces[ns]:
                problems.append("%s.%s (%s)" % (ns, fn, os.path.basename(f)))

    # 3. Templates, fonts, atlases, sounds.
    for f, src in sources.items():
        base = os.path.basename(f)
        for t in re.findall(r'"(\w+Template)"', src):
            if t not in sets["templates"] and not (t in FOREVER_ONLY and not forever):
                problems.append("template %s (%s)" % (t, base))
        for font in re.findall(r'"((?:GameFont|NumberFont|SystemFont)\w*)"', src):
            if font not in sets["fonts"]:
                problems.append("font %s (%s)" % (font, base))
        for atlas in re.findall(r'[Aa]tlas\s*=\s*"([\w\-]+)"', src):
            if atlas not in sets["atlases"]:
                problems.append("atlas %s (%s)" % (atlas, base))
        for tex in re.findall(r'"(Interface\\\\[A-Za-z0-9_\\\-]+)"', src):
            if "\\Icons\\" in tex:
                continue  # icons are checked against Wowhead's icon server (see README)
            if re.sub(r'\\+', lambda _: '\\', tex).lower() not in sets["textures"]:
                problems.append("texture %s (%s)" % (tex, base))
        for sound in re.findall(r'PlaySound\("(\w+)"\)', src):
            if sound not in sets["soundkit"]:
                problems.append("sound %s (%s)" % (sound, base))

    # 4. Events the addon registers.
    core = sources[os.path.join(ROOT, "Core.lua")]
    events = set(re.findall(r'function handlers\.([A-Z_]+)\(', core)) | set(re.findall(r'\b([A-Z][A-Z_]+) = \{ "\w+", (?:true|false) \}', core))
    for ev in sorted(events):
        if ev not in sets["events"]:
            problems.append("event " + ev)

    # 5. Globals named in the TOC.
    toc = open(os.path.join(ROOT, "Forgeborn.toc"), encoding="utf-8").read()
    for fn in re.findall(r'^## AddonCompartmentFunc\w*: (\w+)', toc, re.M):
        if not re.search(r'^function %s\(' % fn, core, re.M):
            problems.append("TOC names %s but Core.lua doesn't define it" % fn)

    print("checked %d globals, %d events, client %s" % (len(used - own), len(events), version))
    for p in problems:
        print("MISSING", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
