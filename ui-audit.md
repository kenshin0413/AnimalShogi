# UI / UX Audit and Improvement Record

## Audit scope

Single-screen player-versus-CPU flow on iPhone 16 Pro and iPhone SE (3rd generation).

## User goal

Understand whose turn it is, choose a legal move without confusion, recover from a mistake, obtain help, and restart or adjust CPU strength without leaving the game.

## Captured evidence

1. `audit/02-stable.png` — polished start state on iPhone 16 Pro: healthy.
2. `audit/03-small-phone.png` — compact layout on iPhone SE: healthy; all core controls remain visible.
3. `audit/04-home.png` — dedicated home screen on iPhone 16 Pro: healthy.
4. `audit/05-centered-game.png` — board recentered using equal left/right coordinate gutters: healthy.
5. `audit/06-home-small.png` — home screen on iPhone SE: healthy; start and rules actions remain visible.
6. `audit/07-home-clean.png` — simplified home without inline settings or redundant first-player copy: healthy.
7. `audit/10-settings-themed.png` — themed CPU strength and starting-side settings: healthy.
8. `audit/11-centered-grid.png` — playable grid centered by measured cell coordinates; A/B/C positioned at exact column centers: healthy.
9. `audit/15-guide.png` — child-friendly three-step guide and rule cards: healthy.
10. `audit/16-stats.png` — persistent game record screen: healthy.

## Improvements completed

- Added a clear title bar with rules and settings entry points.
- Replaced the loose status text with a high-contrast turn pill, live state dot, and turn count.
- Styled both hand areas as consistent trays with explicit empty states.
- Added persistent Undo, Hint, and Rematch actions.
- Added legal hint calculation and a highlighted recommended destination.
- Added full-turn undo that safely cancels pending CPU work.
- Added Easy, Normal, and Hard CPU difficulty levels.
- Added an in-app rules sheet.
- Added last-move destination feedback.
- Added a focused game-over overlay with result, reason, and rematch action.
- Added a dedicated home screen with difficulty selection, character presentation, rules, and primary start action.
- Recalculated the board frame with equal coordinate gutters so the playable three-column grid is centered on screen.
- Changed captured-piece presentation from bare animal art to miniature versions of the complete piece cards, including card color, border, movement dots, orientation, and count badge.
- Moved CPU strength out of the home screen and into a dedicated themed settings sheet.
- Added first-player, second-player, and per-game random starting-side choices; CPU makes the opening move when the player chooses second.
- Replaced difficult kanji in child-facing copy with short hiragana phrases and removed the unexplained English subtitle.
- Rebuilt the rules screen as illustrated, themed rule cards.
- Added distinct animated win and loss celebrations plus both rematch and home actions.
- Added persistent sound, haptic, animation, difficulty, and starting-side preferences.
- Added spring piece insertion/removal animation plus capture, promotion, and result feedback.
- Added a confirmation dialog before abandoning a live game.
- Added persistent games played, wins, losses, current streak, and best streak.
- Replaced the home rules handout with a first-launch interactive tutorial on the real 3×5 board. It teaches moving, capturing, placing a captured piece, and fish promotion through direct play, and can be replayed from「あそびかた」.
- Preserved the reference artwork, dashed grid, landscape background, and child-friendly rounded typography.

## Accessibility notes

- Core board cells remain full-cell tap targets.
- Disabled actions use both disabled behavior and visual treatment.
- Status changes are expressed with text as well as color.
- Small-phone reflow was visually checked; no core control is clipped.

## Evidence limits

Screenshots verify layout, contrast risk, and visible states. VoiceOver reading order and Dynamic Type at accessibility sizes still require device-level testing.

## Open findings

- P0: none
- P1: none
- P2: none in the checked screens.
