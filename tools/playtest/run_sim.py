"""Forge-fee runs (proposal in docs/run-design.md): how far does a player get?

A run is 8 shifts. Each shift 3 items arrive, the player forges and sells 3 items ("crafts"),
then the forge fee is due. Missing a fee costs a grudge; 3 grudges end the run. Leftover
gold buys upgrades in the shop between shifts.

Values are in "base" units: a gray item at +0 is worth 1. The anvil uses the rules v0.4
break curve with a fixed Break share (faces change only the other outcomes, see the design).

    python3 run_sim.py                  # fee curve, income per shift, how far players get
    python3 run_sim.py --runs 20000
"""
import random
import sys

from ev_per_swing import QUALITY_START, break_chance, quality_at

VALUE_FACTOR = [1, 1.5, 2.2, 3.2, 4.6, 6.5]
SHIFTS = 8
CRAFTS_PER_SHIFT = 3
GRUDGES_TO_LOSE = 3
# Quality of delivered items per shift (gray, white, green, blue, purple): better as the run goes on.
DELIVERY = {
    1: [50, 35, 15, 0, 0], 2: [40, 38, 20, 2, 0], 3: [30, 40, 25, 5, 0], 4: [20, 40, 30, 10, 0],
    5: [10, 40, 35, 13, 2], 6: [5, 35, 38, 18, 4], 7: [0, 30, 42, 22, 6], 8: [0, 25, 42, 25, 8],
}
# The forge fee per shift, in base units (proposal; tuned with this script).
FEES = {1: 4, 2: 6, 3: 9, 4: 14, 5: 24, 6: 42, 7: 75, 8: 135}
VALUE_PER_LEVEL = 1.2


class Build:
    """What the player has bought: the anvil's faces and a few tool effects."""

    def __init__(self):
        self.faces = {"crack": 2, "miss": 4, "hit": 12, "great": 2}
        self.great_gain = 2
        self.value_bonus = 0.0  # +x% value
        self.value_mult = 1.0  # xN value (rare tools)
        self.break_cut = 0.0  # share of the Break chance removed (0.25 = a quarter)
        self.frenzy_every = 7

    def odds(self, grade, safe=False):
        f = self.faces
        rest = [f["crack"], f["miss"], f["hit"], f["great"]]
        if safe:
            rest = [0, 0, f["hit"], f["great"]]
            total = sum(rest)
            return [0.0] + [x / total for x in rest]
        p = break_chance(grade) * (1 - self.break_cut)
        total = sum(rest)
        return [p] + [(1 - p) * x / total for x in rest]


# Upgrades in the shop: name, price, effect. Prices rise 15% a shift.
UPGRADES = [
    ("3 Hit faces", 2, lambda b: b.faces.__setitem__("hit", b.faces["hit"] + 3)),
    ("Great face", 2.5, lambda b: b.faces.__setitem__("great", b.faces["great"] + 1)),
    ("Remove a Crack", 2, lambda b: b.faces.__setitem__("crack", max(0, b.faces["crack"] - 1))),
    ("Remove a Miss", 2, lambda b: b.faces.__setitem__("miss", max(0, b.faces["miss"] - 1))),
    ("+30% value tool", 3, lambda b: setattr(b, "value_bonus", b.value_bonus + 0.3)),
    ("x1.5 value tool", 7, lambda b: setattr(b, "value_mult", b.value_mult * 1.5)),
    ("Fiery Core", 4, lambda b: setattr(b, "great_gain", min(5, b.great_gain + 1))),
    ("Arcanite Bar", 5, lambda b: setattr(b, "break_cut", min(0.6, b.break_cut + 0.2))),
    ("Elemental Flux", 4, lambda b: setattr(b, "frenzy_every", max(4, b.frenzy_every - 1))),
]


def forge_item(quality, build, target, rng):
    """Forge one item: push until it reaches the target value, then while one more swing pays. Returns its sale value."""
    start = QUALITY_START[quality]
    grade, embers, frenzy = start, 0, 0
    base = VALUE_FACTOR[quality] * (1 + build.value_bonus) * build.value_mult

    def value(g):
        return base * VALUE_PER_LEVEL ** (g - start)

    for _ in range(80):
        o = build.odds(grade, frenzy > 0)
        floor = QUALITY_START[quality_at(grade)]
        gains = [None, -1, 0, 1, build.great_gain]
        # Expected value of one more swing, as a ratio to selling now.
        ev = sum(o[k] * value(max(floor, grade + gains[k])) for k in range(1, 5)) / value(grade)
        if value(grade) >= target and ev < 1.0:
            break
        if value(grade) < target and o[0] > 0.6:
            break
        roll, outcome = rng.random(), 4
        for k, pk in enumerate(o):
            roll -= pk
            if roll < 0:
                outcome = k
                break
        if outcome == 0:
            return 0.0
        grade = max(floor, grade + gains[outcome])
        if frenzy > 0:
            frenzy -= 1
        else:
            embers += 1
            if embers >= build.frenzy_every:
                embers, frenzy = 0, 3
    return value(grade)


def run(rng, fees, shop=True):
    build, gold, grudges = Build(), 0.0, 0
    for shift in range(1, SHIFTS + 1):
        fee = fees[shift]
        items = [rng.choices(range(5), DELIVERY[shift])[0] for _ in range(CRAFTS_PER_SHIFT)]
        items.sort()
        earned = 0.0
        for i, q in enumerate(items):
            need = max(0.0, fee - gold - earned)
            target = need / (len(items) - i)
            earned += forge_item(q, build, target, rng)
        gold += earned
        if gold >= fee:
            gold -= fee
        else:
            gold, grudges = 0.0, grudges + 1
            if grudges >= GRUDGES_TO_LOSE:
                return shift - 1, grudges
        if shop and shift < SHIFTS:
            # 4 random offers; buy the dearest ones that fit (a bot: no plan, no synergy).
            reserve = 0
            offers = rng.sample(UPGRADES, 4)
            for name, price, apply in sorted(offers, key=lambda o: -o[1]):
                cost = price * (1 + 0.15 * (shift - 1))
                if gold - cost >= reserve:
                    gold -= cost
                    apply(build)
    return SHIFTS, grudges


def income(shift, rng, n=20000):
    """Income of one shift for a player without upgrades who doesn't aim at a fee."""
    out = []
    for _ in range(n):
        items = [rng.choices(range(5), DELIVERY[shift])[0] for _ in range(CRAFTS_PER_SHIFT)]
        out.append(sum(forge_item(q, Build(), 0, rng) for q in items))
    out.sort()
    return out[n // 4], out[n // 2], out[3 * n // 4]


def build_income():
    """Income of shift 5 with single upgrades and with combined builds: builds multiply, they don't add."""
    rng = random.Random(5)
    cases = [
        ("plain anvil", {}),
        ("+6 Hit faces", {"hit": 18}),
        ("+3 Great faces", {"great": 5}),
        ("no Crack, no Miss faces", {"crack": 0, "miss": 0}),
        ("+60% value", {"value_bonus": 0.6}),
        ("x1.5 value", {"value_mult": 1.5}),
        ("Great hits +4", {"great_gain": 4}),
        ("Break chance -40%", {"break_cut": 0.4}),
        ("Frenzy every 4", {"frenzy_every": 4}),
        ("all of: +6 Hit, +3 Great, Great +4, Break -40%, Frenzy 4", {"hit": 18, "great": 5, "great_gain": 4, "break_cut": 0.4, "frenzy_every": 4}),
    ]
    for name, changes in cases:
        build = Build()
        for key, v in changes.items():
            if key in build.faces:
                build.faces[key] = v
            else:
                setattr(build, key, v)
        out = sorted(sum(forge_item(rng.choices(range(5), DELIVERY[5])[0], build, 0, rng) for _ in range(3)) for _ in range(4000))
        print(f"  {name:58s} median {out[len(out) // 2]:6.1f}")


def main():
    runs = int(sys.argv[sys.argv.index("--runs") + 1]) if "--runs" in sys.argv else 5000
    rng = random.Random(2026)
    print("shift  fee   income without upgrades (25% / median / 75%)")
    for s in range(1, SHIFTS + 1):
        lo, mid, hi = income(s, rng, 4000)
        print(f"{s:>5}  {FEES[s]:>4}   {lo:6.1f} / {mid:6.1f} / {hi:6.1f}")
    print("income of shift 5 by build (median):")
    build_income()
    for label, shop in (("no shop", False), ("buys upgrades", True)):
        reached = [run(rng, FEES, shop)[0] for _ in range(runs)]
        cleared = sum(r == SHIFTS for r in reached) / runs
        dist = "  ".join(f"{s}:{sum(r == s for r in reached) / runs:.0%}" for s in range(0, SHIFTS + 1))
        print(f"{label:>14}: wins {cleared:.0%}   shifts survived  {dist}")


if __name__ == "__main__":
    main()
