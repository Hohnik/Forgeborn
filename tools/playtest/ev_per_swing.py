"""Expected value of one more swing, as % of selling now, per quality (rules v0.3, no tools).

Reproduces the balance chart in docs/design.md. An item that started gray is
checked at every level of each quality; Frenzy is not counted.

    python3 ev_per_swing.py
"""
from forge import BAG, LEVELS_TO_NEXT, QUALITIES, VALUE_FACTOR


def quality_at(level):
    q, need = 0, 0
    while q < 5 and level >= need + LEVELS_TO_NEXT[q]:
        need += LEVELS_TO_NEXT[q]
        q += 1
    return q


def floor_at(level):
    return sum(LEVELS_TO_NEXT[:quality_at(level)])


def value(level):
    return VALUE_FACTOR[quality_at(level)] * (1 + 0.1 * level)


def main():
    starts = [sum(LEVELS_TO_NEXT[:q]) for q in range(6)]
    for q in range(6):
        lo = starts[q]
        hi = starts[q + 1] if q < 5 else lo + 7
        ratios = []
        for lvl in range(lo, hi):
            hit, great, miss, crack, _brk = BAG[q]
            ev = (hit * value(lvl + 1) + great * value(lvl + 2) + miss * value(lvl)
                  + crack * value(max(floor_at(lvl), lvl - 1))) / 20
            ratios.append(ev / value(lvl))
        avg = sum(ratios) / len(ratios)
        print(f"{QUALITIES[q]:>6}: average {avg * 100:5.1f}%  (from {min(ratios) * 100:.0f}% to {max(ratios) * 100:.0f}%)")


if __name__ == "__main__":
    main()
