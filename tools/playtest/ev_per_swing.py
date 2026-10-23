"""Odds per grade and expected value of one more swing (rules v0.4, no tools).

Rules v0.4 follow ForgeTax's anvil: the odds depend on the grade (the level counted
from the start of gray), so they change with every level, and every level multiplies
the value by 1.2. This script is a separate Python version of the rules in Rules.lua;
tests/test_rules.lua checks the Lua numbers against what it prints.

    python3 ev_per_swing.py           # EV of one more swing per quality
    python3 ev_per_swing.py --table   # the odds of every grade (docs/design.md)
"""
import sys

QUALITIES = ["gray", "white", "green", "blue", "purple", "orange"]
LEVELS_TO_NEXT = [4, 4, 5, 6, 7]
QUALITY_START = [sum(LEVELS_TO_NEXT[:q]) for q in range(6)]  # 0, 4, 8, 13, 19, 26
# Break, Crack (-1), Miss (0), Hit (+1), Great hit (+2). Break comes from the curve.
DECK = [0, 2, 4, 12, 2]
BREAK_CURVE = [(0, 0), (2, 2), (4, 6), (8, 12), (13, 20), (19, 30), (26, 40), (36, 55), (50, 70)]
TICKETS = 1000
VALUE_PER_LEVEL = 1.2


def break_chance(grade):
    if grade <= BREAK_CURVE[0][0]:
        return BREAK_CURVE[0][1] / 100
    for (g0, p0), (g1, p1) in zip(BREAK_CURVE, BREAK_CURVE[1:]):
        if grade <= g1:
            return (p0 + (p1 - p0) * (grade - g0) / (g1 - g0)) / 100
    return BREAK_CURVE[-1][1] / 100


def bag(grade):
    plain = sum(DECK[1:])
    p = min(break_chance(grade), 0.99)
    return [plain * p / (1 - p)] + DECK[1:]


def apportion(weights, size):
    total = sum(weights)
    exact = [w * size / total for w in weights]
    result = [int(x) for x in exact]
    rema = [x - r for x, r in zip(exact, result)]
    left = size - sum(result)
    while left > 0:
        best = None
        for i, r in enumerate(rema):
            if r > 0 and (best is None or r > rema[best]):
                best = i
        if best is None:
            break
        result[best] += 1
        rema[best] = 0
        left -= 1
    return result


def odds(grade):
    tickets = apportion(bag(grade), TICKETS)
    return [t / TICKETS for t in tickets]


def quality_at(level):
    q = 0
    for i, start in enumerate(QUALITY_START):
        if level >= start:
            q = i
    return q


def value(level):
    return VALUE_PER_LEVEL ** level


def ev_ratio(level):
    """One more swing for an item that started gray, as a ratio to selling now."""
    brk, crack, miss, hit, great = odds(level)
    floor = QUALITY_START[quality_at(level)]
    ev = hit * value(level + 1) + great * value(level + 2) + miss * value(level) + crack * value(max(floor, level - 1))
    return ev / value(level)


def main():
    if "--table" in sys.argv:
        print("| Grade | Quality | Break | Crack -1 | Miss 0 | Hit +1 | Great hit +2 | Value |")
        print("| --- | --- | --- | --- | --- | --- | --- | --- |")
        for grade in range(0, 51):
            o = odds(grade)
            q = quality_at(grade)
            label = f"{QUALITIES[q]} +{grade}" if grade in QUALITY_START else f"+{grade}"
            cells = " | ".join(f"{x * 100:.1f}%" for x in o)
            print(f"| {grade} | {label} | {cells} | x{value(grade):,.1f} |")
        return
    for q in range(6):
        lo = QUALITY_START[q]
        hi = QUALITY_START[q + 1] if q < 5 else lo + 7
        ratios = [ev_ratio(level) for level in range(lo, hi)]
        avg = sum(ratios) / len(ratios)
        print(f"{QUALITIES[q]:>6}: average {avg * 100:5.1f}%  (from {min(ratios) * 100:.0f}% to {max(ratios) * 100:.0f}%)")


if __name__ == "__main__":
    main()
