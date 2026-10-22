"""Forgeborn playtest engine (rules v0.3).

A tiny command-line version of the anvil, used to playtest the rules in chat
before any Lua exists. State is kept in state.json next to this file.

    python3 forge.py new --name "Tattered Boots" --quality gray --ilvl 20 --kind armor --seed 2026
    python3 forge.py swing          # one swing
    python3 forge.py swing 5        # up to five swings (stops on a break)
    python3 forge.py sell
    python3 forge.py show

Tools are passed with --tool (repeatable), e.g. --tool "Fiery Core".
"""
import argparse
import base64
import json
import os
import pickle
import random

HERE = os.path.dirname(os.path.abspath(__file__))
STATE = os.path.join(HERE, "state.json")

QUALITIES = ["gray", "white", "green", "blue", "purple", "orange"]
VALUE_FACTOR = [1, 1.5, 2.2, 3.2, 4.6, 6.5]
LEVELS_TO_NEXT = [4, 4, 5, 6, 7]  # gray->white, white->green, green->blue, blue->purple, purple->orange
# Tokens out of 20 per quality: Hit (+1), Great hit (+2), Miss (0), Crack (-1), Break
BAG = [
    (14, 3, 2, 1, 0),
    (13, 3, 2, 1, 1),
    (11, 2, 4, 1, 2),
    (8, 2, 5, 2, 3),
    (6, 1, 6, 3, 4),
    (4, 1, 7, 3, 5),
]
EMBERS_FOR_FRENZY = 7
FRENZY_SWINGS = 3


def quality(item, level=None):
    lvl = item["level"] if level is None else level
    q, need = item["start_quality"], 0
    while q < 5 and lvl >= need + LEVELS_TO_NEXT[q]:
        need += LEVELS_TO_NEXT[q]
        q += 1
    return q


def quality_floor(item):
    return sum(LEVELS_TO_NEXT[item["start_quality"]:quality(item)])


def value(state):
    item, tools = state["item"], state["tools"]
    q = quality(item)
    factor = VALUE_FACTOR[q]
    if q == 5 and "Righteous Orb" in tools:
        factor = 9
    v = item["ilvl"] * factor * (1 + 0.1 * item["level"])  # silver
    if item["kind"] == "armor" and "Thorium Bar" in tools:
        v *= 1.2
    if item["kind"] == "weapon" and "Heavy Sharpening Stone" in tools:
        v *= 1.25
    return v


def bag(state):
    hit, great, miss, crack, brk = BAG[quality(state["item"])]
    tools = state["tools"]
    if "Blacksmith Hammer" in tools:
        hit += 2
    if "Weak Flux" in tools:
        crack = max(0, crack - 1)
    if "Strong Flux" in tools:
        crack = max(0, crack - 2)
    if "Lava Core" in tools:
        great += 2
    if "Arcanite Bar" in tools:
        brk = max(0, brk - 1)
    return {"Hit": hit, "Great hit": great, "Miss": miss, "Crack": crack, "Break": brk}


def odds(state):
    b = bag(state)
    if state["frenzy"]:
        b = {k: (n if k in ("Hit", "Great hit") else 0) for k, n in b.items()}
    total = sum(b.values())
    return {k: round(100 * n / total) for k, n in b.items()}


def money(silver):
    copper = round(silver * 100)
    g, rest = divmod(copper, 10000)
    s, c = divmod(rest, 100)
    return f"{g}g {s:02d}s" if g else (f"{s}s" if s else f"{c}c")


def load():
    with open(STATE) as f:
        state = json.load(f)
    rng = random.Random()
    rng.setstate(pickle.loads(base64.b64decode(state.pop("rng"))))
    return state, rng


def save(state, rng):
    state = dict(state, rng=base64.b64encode(pickle.dumps(rng.getstate())).decode())
    with open(STATE, "w") as f:
        json.dump(state, f, indent=1)


def swing(state, rng):
    item = state["item"]
    b = bag(state)
    pool = [k for k, n in b.items() for _ in range(n)]
    token = rng.choice(pool)
    in_frenzy = state["frenzy"] > 0
    while in_frenzy and token in ("Miss", "Crack", "Break"):
        token = rng.choice(pool)
    if token == "Break":
        print(f"BREAK. {item['name']} (+{item['level']} {QUALITIES[quality(item)]}, {money(value(state))}) is gone.")
        state["item"] = None
        return False
    gain = {"Hit": 1, "Great hit": 3 if "Fiery Core" in state["tools"] else 2, "Miss": 0, "Crack": -1}[token]
    before = quality(item)
    item["level"] = max(quality_floor(item), item["level"] + gain)
    if in_frenzy:
        state["frenzy"] -= 1
    else:
        state["embers"] += 1
    line = f"{'[Frenzy] ' if in_frenzy else ''}{token}: +{item['level']} {QUALITIES[quality(item)]}, {money(value(state))}"
    if quality(item) > before:
        line += f"  -> now {QUALITIES[quality(item)]}!"
    print(line)
    if state["embers"] >= EMBERS_FOR_FRENZY and not state["frenzy"]:
        state["embers"], state["frenzy"] = 0, FRENZY_SWINGS
        print("Embers full: Frenzy, the next 3 swings are safe.")
    return True


def show(state):
    item = state["item"]
    print(f"Addon gold: {money(state['gold'])} | Shelf: {', '.join(state['tools']) or 'empty'}")
    if item:
        print(f"{item['name']} +{item['level']} {QUALITIES[quality(item)]}, {money(value(state))}")
        print(f"Embers {state['embers']}/{EMBERS_FOR_FRENZY}, Frenzy swings left {state['frenzy']}")
        print("Next swing: " + "  ".join(f"{k} {v}%" for k, v in odds(state).items()))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new")
    n.add_argument("--name", required=True)
    n.add_argument("--quality", choices=QUALITIES, required=True)
    n.add_argument("--ilvl", type=int, required=True)
    n.add_argument("--kind", choices=["armor", "weapon"], required=True)
    n.add_argument("--seed", type=int, default=None)
    n.add_argument("--tool", action="append", default=[])
    s = sub.add_parser("swing")
    s.add_argument("count", nargs="?", type=int, default=1)
    sub.add_parser("sell")
    sub.add_parser("show")
    args = ap.parse_args()

    if args.cmd == "new":
        rng = random.Random(args.seed)
        state = dict(gold=0.0, tools=args.tool[:4], embers=0, frenzy=0,
                     item=dict(name=args.name, start_quality=QUALITIES.index(args.quality),
                               level=0, ilvl=args.ilvl, kind=args.kind))
        show(state)
        save(state, rng)
        return

    state, rng = load()
    if args.cmd == "swing" and state["item"]:
        for _ in range(args.count):
            if not swing(state, rng):
                break
    elif args.cmd == "sell" and state["item"]:
        v = value(state)
        state["gold"] += v
        print(f"Sold {state['item']['name']} for {money(v)}.")
        state["item"] = None
    show(state)
    save(state, rng)


if __name__ == "__main__":
    main()
