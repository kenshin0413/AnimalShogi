# Online Match UI Design QA

- Source visual truth: `/Users/kenshin/Desktop/AnimalShogi/audit/online-ready-target.png`
- Implementation screenshot: `/Users/kenshin/Desktop/AnimalShogi/audit/online-ready-se-implementation.png`
- Combined comparison: `/Users/kenshin/Desktop/AnimalShogi/audit/online-ready-comparison.png`
- Additional states: `/Users/kenshin/Desktop/AnimalShogi/audit/online-match-intro-versus.png`, `/Users/kenshin/Desktop/AnimalShogi/audit/online-match-intro-countdown.png`, `/Users/kenshin/Desktop/AnimalShogi/audit/online-match-intro-started.png`
- State: online ready screen, match introduction, countdown, and playable board
- Viewport: iPhone SE (3rd generation), 375 × 667 points, light appearance
- Pixels and density: source 853 × 1844 pixels; implementation 750 × 1334 pixels at @2x. Source was proportionally normalized to 1334 px high for the side-by-side comparison.

## Findings

- No actionable P0/P1/P2 findings remain.
- The attached design uses a taller viewport. On iPhone SE the same hierarchy is preserved with a scrollable ready screen; the matchmaking button remains visible without scrolling.
- The source title says `どうぶつしょうぎ`; the implementation intentionally says `いきものしょうぎ` following the user's explicit naming correction.
- Initial VS capture wrapped the rank/rating line on the shorter viewport (P2). Its type was reduced by one point and constrained to one scaled line. The final capture shows both player cards clearly.

## Required Fidelity Surfaces

- Fonts and typography: rounded heavy system typography matches the playful target hierarchy. Name, rank, rating, record, rule labels, VS cards, and countdown remain legible on SE.
- Spacing and layout rhythm: hero piece, name pill, rank/rating, record capsule, rule row, primary CTA, and profile action follow the source order and proportions. The screen scrolls only where the short viewport requires it.
- Colors and visual tokens: sky blue, pale yellow, grass green, brick red, white surfaces, and pink piece tile closely match the selected visual target.
- Image quality and asset fidelity: the existing project animal artwork is used directly with aspect-fit sizing. No placeholder replaces a player avatar.
- Copy and content: app naming is `いきものしょうぎ`; rank, rating, wins/losses, rule summary, search action, player identities, first/second order, countdown, and start state are shown.

## Full-view Comparison Evidence

The combined image confirms the selected hierarchy and visual language. Differences are limited to the corrected app name, real profile data, native SF Symbols, and responsive compression for the SE viewport.

## Focused Region Comparison Evidence

The full-resolution comparison clearly exposes typography, animal-art scaling, score capsule, three rule items, and both CTAs. Separate full-resolution VS and countdown captures verify the new transition states.

## Interaction Verification

- Match intro overlays the already-rendered board.
- Opponent card, VS marker, and player card display for roughly three seconds.
- The overlay then advances through 3, 2, 1, and `開始！`.
- Board input is blocked before the shared start timestamp.
- Match and turn clocks use the shared future timestamp, so intro time is not deducted.
- After the timestamp, the overlay disappears and normal board interaction begins.
- Resume skips the intro when the saved start timestamp is already in the past.

## Comparison History

1. Previous ready UI used a compact generic profile panel rather than the chosen visual hierarchy.
2. Ready UI was rebuilt around the attached hero piece, name pill, rank/rating, W/L capsule, rule icons, and two actions.
3. Initial VS card wrapped the rating line on SE; the line was scaled and constrained.
4. Final visual evidence shows complete ready, VS, countdown, and started states with no clipped persistent controls.

## Implementation Checklist

- [x] Selected ready-screen design reproduced responsively
- [x] `いきものしょうぎ` naming retained
- [x] Match-found player introduction overlay
- [x] First/second labels
- [x] 3–2–1–start countdown
- [x] Shared future start timestamp
- [x] Input and clocks paused during intro
- [x] iPhone SE simulator build and state captures

## Follow-up Polish

- P3: Physical-device testing can confirm haptic and animation timing preferences under real network latency.

final result: passed
