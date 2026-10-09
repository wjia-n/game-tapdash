# Tap Dash — Rules

_The authoritative source of truth for Tap Dash. If the implementation
conflicts with this document, fix the implementation._

## 1. Objective

Test and train your reaction time. The screen waits RED ("Wait for it…")
and turns GREEN ("TAP NOW!") after a random delay. Tap the instant it
turns green. The faster your tap, the better your score. Tapping before
green is a false start and costs you.

## 2. Setup

- Choose a game mode: Quick Match, Score Attack, or Vs Robo-Dash.
- Choose a speed tier: Chill, Swift, or Lightning (Pro).
- Quick Match: 1–4 players (pass-and-play on one device).
- Vs Robo-Dash: 1 human vs the bot; pick bot skill (Chill Bot / Swift Bot /
  Beast Bot).
- Score Attack: 1 player, endless rounds.

## 3. Turn order

- Quick Match: each player completes all 5 of their rounds, then passes the
  device to the next player ("Pass to X — tap to start!").
- Score Attack: rounds continue until the match ends (3 false starts).
- Vs Robo-Dash: 5 rounds; human and bot race every round.

## 4. Legal moves

- Tap anywhere on the screen.
- A tap is only "valid" while the screen is GREEN (armed phase). The time
  between green appearing and the tap is recorded in milliseconds.

## 5. Illegal moves

- Tapping during RED (waiting), during the 3-2-1 countdown, or during an
  amber TRICK flash (Lightning tier) is a FALSE START.
- A false start never scores; see §8 for penalties.

## 6. Captures

Not applicable — Tap Dash has no captures.

## 7. Special rules

- **Countdown:** every round starts with a 3-2-1 countdown. Tapping during
  the countdown is a false start.
- **Random green delay:** the wait before green is random within the tier's
  range (Chill 1.5–3.5s, Swift 1.0–2.6s, Lightning 0.8–2.0s), so it can
  never be memorized.
- **Lightning trick flashes (Pro):** 0–2 amber flashes may appear during the
  wait. Amber is NOT green — tapping on amber is a false start.
- **Vs Robo-Dash:** when green appears, the bot taps after its own
  reaction delay (Chill Bot ~520ms ±90, Swift Bot ~360ms ±70,
  Beast Bot ~250ms ±45). Whoever taps first wins the round.
- **Armed timeout:** if nobody taps within 10 seconds of green, the round
  scores as a miss (9999ms) instead of hanging.

## 8. Scoring

- Each valid tap scores `max(0, 1500 − ms)` points. A 200ms tap = 1300 pts;
  anything ≥1500ms = 0 pts.
- A false start scores 0 points for the round AND:
  - Quick Match: recorded as a 1200ms penalty round in the player's average.
  - Score Attack: counts as one strike (no points).
  - Vs Robo-Dash: the round is awarded to the bot.
- Grades: <200ms "Inhuman!!", <280ms "Superb!", <400ms "Nice!",
  <600ms "Solid!", otherwise "Keep practicing!".

## 9. Winning conditions

- Quick Match (1 player): finish 5 rounds — beat your own best average.
- Quick Match (2–4 players): lowest average reaction time wins.
- Score Attack: highest total score wins (played solo; beat your best).
- Vs Robo-Dash: most round wins out of 5 wins the match (5 is odd, so no
  ties are possible).

## 10. Draw conditions

- Vs Robo-Dash cannot draw (best of 5).
- Quick Match multiplayer: tied averages are a shared victory.

## 11. AI strategy

Robo-Dash has no strategy beyond its reaction distribution per skill tier
(see §7). It never false-starts and never adapts — beating Beast Bot
(~250ms) requires genuinely elite reactions.

## 12. Edge cases

- App backgrounded mid-round: the engine pauses; the waiting phase
  re-arms on resume and the armed phase preserves elapsed reaction time.
- Tapping during the result display: ignored (results auto-advance).
- Tapping after the match ends: ignored.
- A round's timers can never be lost: a watchdog re-arms any phase found
  without a live timer.
- Decoys never appear in Chill/Swift tiers.

## 13. Test cases

1. Tap during red → false start buzz, penalty applied, round auto-advances.
2. Tap during countdown → false start.
3. Tap on amber trick (Lightning) → false start.
4. Tap on green → ms recorded, grade shown, points awarded.
5. Quick Match 2 players → each plays 5 rounds; winner = lowest average.
6. Score Attack → 3rd false start ends the match; score accumulates.
7. Vs Robo-Dash → 5 rounds; round winner = faster tap; match winner =
   most rounds.
8. Background the app mid-wait → resume → round continues, no stuck state.
9. Never tap after green → after 10s the round scores as a miss.
10. Restart mid-match → clean state, no leftover timers.
