# Last-rank chick-drop comparison — 10,000 games per rule

- Board/setup: current 3×5 recommended layout
- Search: depth 5 minimax with alpha-beta pruning
- Move variation: 30% among near-best moves
- Repetition: player creating the fourth occurrence loses
- Seeds: 1–10, 1,000 games per seed
- Maximum game length: 180 plies
- In the allowed version, a chick dropped on the last rank stays a chick and cannot move forward.

| Rule | Games | First wins | Second wins | Unfinished | First rate | Second rate | Average plies |
|---|---:|---:|---:|---:|---:|---:|---:|
| Last-rank chick drop forbidden | 10,000 | 5,024 | 4,966 | 10 | 50.24% | 49.66% | 42.8263 |
| Last-rank chick drop allowed | 10,000 | 4,973 | 5,022 | 5 | 49.73% | 50.22% | 43.1439 |

Allowing the drop shifted the observed first-player win rate by -0.51 percentage points and the second-player win rate by +0.56 points. The lead changed from first +0.58 points to second +0.49 points. Both gaps are smaller than roughly one percentage point, so this run does not show a meaningful first/second-player imbalance caused by the rule. It slightly reduced unfinished games and increased average length by 0.3176 plies.

This is an empirical self-play comparison, not a complete game-theoretic proof.
