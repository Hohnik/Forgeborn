"""How often a value quota is met (rules v0.4), for the contract idea in docs/goal-plans.md.

A "collection" is 4 drops of typical low-level quality (40% gray, 35% white, 20% green, 5% blue).
Each drop is forged until it reaches a target number of levels past its start, or breaks. The
result is the collection's total value as a multiple of the drops' starting value.

    python3 contract_quota.py
"""
import random

from ev_per_swing import QUALITY_START, odds, quality_at

VALUE_FACTOR = [1, 1.5, 2.2, 3.2, 4.6, 6.5]
DROPS = 4
QUALITY_WEIGHTS = [40, 35, 20, 5]  # gray, white, green, blue
PLAYERS = {  # levels each player pushes past the start, by start quality
    "cautious": {0: 8, 1: 5, 2: 3, 3: 0},
    "steady": {0: 10, 1: 7, 2: 4, 3: 1},
    "greedy": {0: 13, 1: 9, 2: 6, 3: 3},
}
QUOTAS = [1.5, 2, 3, 4, 6]


def forge(start_quality, levels, rng):
    """Value multiple of one drop after forging it `levels` past its start (0 if it breaks)."""
    start = QUALITY_START[start_quality]
    grade, embers, frenzy = start, 0, 0
    while grade < start + levels:
        o = odds(grade)
        if frenzy > 0:
            outcome = 3 if rng.random() * (o[3] + o[4]) < o[3] else 4
        else:
            roll, outcome = rng.random(), 4
            for k, p in enumerate(o):
                roll -= p
                if roll < 0:
                    outcome = k
                    break
        if outcome == 0:
            return 0.0
        floor = QUALITY_START[quality_at(grade)]
        grade = max(floor, grade + {1: -1, 2: 0, 3: 1, 4: 2}[outcome])
        if frenzy > 0:
            frenzy -= 1
        else:
            embers += 1
            if embers >= 7:
                embers, frenzy = 0, 3
    return 1.2 ** (grade - start)


def collection(plan, rng):
    start_sum = end_sum = 0.0
    for _ in range(DROPS):
        q = rng.choices(range(4), QUALITY_WEIGHTS)[0]
        start_sum += VALUE_FACTOR[q]
        end_sum += VALUE_FACTOR[q] * forge(q, plan[q], rng)
    return end_sum / start_sum


def main():
    rng = random.Random(7)
    for name, plan in PLAYERS.items():
        results = sorted(collection(plan, rng) for _ in range(20000))
        median = results[len(results) // 2]
        rates = "  ".join(f"x{q}: {sum(r >= q for r in results) / len(results):.0%}" for q in QUOTAS)
        print(f"{name:>8}: median x{median:.2f}   meets {rates}")


if __name__ == "__main__":
    main()
