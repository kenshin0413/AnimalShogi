# 3x5 recommended variant — 10,000 game run

- Date: 2026-09-20
- Search depth: 5 plies
- Near-best-move randomization: 25%
- Repetition: third occurrence is a draw
- Independent seeds: 1 through 10 (1,000 games each)
- Setup, CPU side: `giraffe / elephant / lion`, with the chick directly in front of the lion
- Human side: the 180-degree rotation of the CPU setup

| Result | Games | Rate |
|---|---:|---:|
| First-player wins | 2,732 | 27.32% |
| Second-player wins | 2,756 | 27.56% |
| Draws | 4,512 | 45.12% |
| First-player score (draw = 0.5) | 4,988 | 49.88% |
| Second-player score (draw = 0.5) | 5,012 | 50.12% |

Average game length: 34.7722 plies.

The root evaluation was 0 in every shard. This is an empirical self-play result, not a complete game-theoretic proof.

## Draw-reduction follow-up

| Repetition / move variation | Games | First score | Draw rate | Average plies |
|---|---:|---:|---:|---:|
| 3 repetitions / 25% | 10,000 | 49.88% | 45.12% | 34.77 |
| 3 repetitions / 30% | 2,000 | 50.03% | 39.75% | 36.88 |
| 4 repetitions / 25% | 2,000 | 51.80% | 38.70% | 40.55 |
| 5 repetitions / 25% | 2,000 | 52.53% | 33.45% | 45.18 |
| 4 repetitions / 30% | 1,000 | 51.85% | 30.90% | 44.15 |

## Final low-draw rule

Rule: on the fourth occurrence of the same position, the player whose move created that occurrence loses instead of drawing.

- Games: 10,000
- Search depth: 5 plies
- Near-best-move randomization: 30%
- First-player wins: 4,926 (49.26%)
- Second-player wins: 5,066 (50.66%)
- Unfinished at 180 plies: 8 (0.08%)
- First-player score: 49.30%
- Second-player score: 50.70%
- Average game length: 42.7591 plies
