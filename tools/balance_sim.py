"""Симуляция баланса: бесплатная крутилка с удачей, деревья, прокачка, расширение острова.

Модель активного игрока: крутит, как только откат готов; сажает лучшие ростки;
жадно тратит монеты (расширение > дешёвая полезная покупка). Числа зеркалят
src/shared/Config. Запуск: python tools/balance_sim.py
"""

import math
import random

# --- деревья: (id, N в «1 из N») ---
TREES = [
    ("oak", 2), ("birch", 3), ("apple", 4), ("pine", 5), ("maple", 7), ("willow", 9),
    ("cherry", 12), ("pear", 16), ("lemon", 20), ("plum", 25), ("olive", 32), ("peach", 40),
    ("orange", 50), ("fig", 75), ("mango", 100), ("palm", 150), ("pomegranate", 200), ("cacao", 250),
    ("sakura", 400), ("ginkgo", 600), ("baobab", 1000), ("bluespruce", 1500), ("jacaranda", 2500),
    ("dragonblood", 5000), ("rainboweuc", 10000), ("goldenapple", 20000), ("crystalbirch", 50000),
    ("moonwillow", 100000), ("phoenix", 250000), ("worldsapling", 500000), ("yggdrasil", 1000000),
    ("starfruit", 2500000), ("celestial", 10000000), ("voidoak", 25000000), ("genesis", 100000000),
]

# доход и рост
INCOME_BASE = 30.0     # монет/мин у дерева N=1
INCOME_EXP = 0.5       # доход ~ N^0.5
GROW_BASE = 25         # сек
GROW_EXP = 0.25        # время роста ~ N^0.25
UPG_YIELD = 0.2        # +20% дохода за уровень дерева (линейно)
UPG_COST_MULT = 1.15   # цена уровня растёт в 1.15 раза
UPG_COST_BASE = 4.0    # первая прокачка = 4 минуты дохода дерева

# крутилка
ROLL_CD_BASE = 3.0
ROLL_CD_STEP = 0.1
ROLL_CD_MIN = 1.5
SPEED_COST = lambda lvl: 1500 * 1.9 ** lvl
LUCK_STEP = 0.1        # +10% удачи за уровень
LUCK_COST = lambda lvl: 2000 * 1.5 ** lvl
LUCKY_EVERY = 10       # каждая 10-я крутка x2 удача
INDEX_LUCK = 0.01      # +1% за открытый вид
# бонус за число круток: (крутки, +удача)
ROLL_MILESTONES = [(100, 0.05), (500, 0.1), (1000, 0.1), (2500, 0.15), (5000, 0.2),
                   (10000, 0.25), (25000, 0.3), (50000, 0.4), (100000, 0.5), (250000, 0.75),
                   (500000, 1.0), (1000000, 1.5)]

# остров: (участков, мин в игре, монеты, ростков)
ISLAND = [
    (3, 0, 0, 0),
    (4, 3, 500, 8),
    (5, 10, 3000, 20),
    (6, 30, 20000, 50),
    (7, 90, 120000, 120),
    (8, 240, 600000, 300),
    (9, 600, 3000000, 700),
    (10, 1200, 15000000, 1500),
    (11, 2400, 75000000, 3000),
    (12, 6000, 400000000, 6000),
]


def income(n):
    return INCOME_BASE * n ** INCOME_EXP / 60.0  # монет/сек


def luck_value(s):
    bonus = sum(b for r, b in ROLL_MILESTONES if s["rolls"] >= r)
    bonus += s["luck_lvl"] * LUCK_STEP
    bonus += len(s["found"]) * INDEX_LUCK
    return 1 + bonus


def roll(luck, rng):
    for name, n in reversed(TREES):
        if rng.random() < min(1.0, luck / n):
            return name, n
    return TREES[0]


def simulate(hours=300, seed=1, report=(5, 10, 15, 30, 60, 120, 300, 600, 1200, 2400, 3600, 6000, 9000, 18000)):
    rng = random.Random(seed)
    s = dict(t=0.0, coins=0.0, rolls=0, luck_lvl=0, speed_lvl=0, tier=0,
             found=set(), sprouts=0, plots=[], best=("oak", 2))
    next_roll = 0.0
    out = []
    reports = list(report)
    dt = 1.0
    while s["t"] < hours * 3600:
        s["t"] += dt
        cd = max(ROLL_CD_MIN, ROLL_CD_BASE - s["speed_lvl"] * ROLL_CD_STEP)
        while s["t"] >= next_roll:
            next_roll += cd
            s["rolls"] += 1
            L = luck_value(s) * (2 if s["rolls"] % LUCKY_EVERY == 0 else 1)
            name, n = roll(L, rng)
            s["found"].add(name)
            if n > s["best"][1]:
                s["best"] = (name, n)
            # посадка: на пустое место или вместо худшего дерева
            cap = ISLAND[s["tier"]][0]
            if len(s["plots"]) < cap:
                s["plots"].append([n, 1])
            else:
                worst = min(s["plots"], key=lambda p: income(p[0]) * (1 + UPG_YIELD * (p[1] - 1)))
                if income(n) > income(worst[0]) * (1 + UPG_YIELD * (worst[1] - 1)):
                    s["plots"].remove(worst)
                    s["plots"].append([n, 1])
                else:
                    s["sprouts"] += 1
        rate = sum(income(n) * (1 + UPG_YIELD * (lvl - 1)) for n, lvl in s["plots"])
        s["coins"] += rate * dt
        # траты
        minutes = s["t"] / 60
        for _ in range(20):
            if s["tier"] + 1 < len(ISLAND):
                _, m, c, sp = ISLAND[s["tier"] + 1]
                if minutes >= m and s["coins"] >= c and s["sprouts"] >= sp:
                    s["coins"] -= c
                    s["sprouts"] -= sp
                    s["tier"] += 1
                    continue
            options = []
            for p in s["plots"]:
                cost = UPG_COST_BASE * income(p[0]) * 60 * UPG_COST_MULT ** (p[1] - 1)
                options.append((cost, "tree", p))
            options.append((LUCK_COST(s["luck_lvl"]), "luck", None))
            if ROLL_CD_BASE - s["speed_lvl"] * ROLL_CD_STEP > ROLL_CD_MIN:
                options.append((SPEED_COST(s["speed_lvl"]), "speed", None))
            cost, kind, p = min(options, key=lambda o: o[0])
            # копим на расширение, если оно почти доступно по времени и росткам
            if s["tier"] + 1 < len(ISLAND):
                _, m, c, sp = ISLAND[s["tier"] + 1]
                if minutes >= m and s["sprouts"] >= sp and s["coins"] - cost < c and cost > c * 0.05:
                    break
            if s["coins"] < cost:
                break
            s["coins"] -= cost
            if kind == "tree":
                p[1] += 1
            elif kind == "luck":
                s["luck_lvl"] += 1
            else:
                s["speed_lvl"] += 1
        if reports and minutes >= reports[0]:
            reports.pop(0)
            out.append((round(minutes), ISLAND[s["tier"]][0], s["rolls"], round(luck_value(s), 2),
                        len(s["found"]), s["best"][0], s["best"][1], round(rate * 60),
                        s["luck_lvl"], s["speed_lvl"], s["sprouts"]))
    return out


if __name__ == "__main__":
    print("min plots rolls luck found best(1inN) coins/min luckLvl speedLvl sprouts")
    runs = [simulate(seed=k) for k in range(5)]
    for i in range(len(runs[0])):
        row = runs[0][i]
        bests = sorted(r[i][6] for r in runs)
        print(f"{row[0]:>5} {row[1]:>3} {row[2]:>7} {row[3]:>5} {row[4]:>3} "
              f"{row[5]:>13}(1/{row[6]}) med 1/{bests[2]} {row[7]:>9} {row[8]:>3} {row[9]:>3} {row[10]:>6}")
