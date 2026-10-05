# Ronda

A Godot implementation of [Ronda](https://fr.wikipedia.org/wiki/Ronda_(jeu_de_cartes)),
a Spanish-deck fishing/capture card game, built so a human can play against a
computer opponent of three different strengths.

This README is the entry point for anyone joining the project. For more detail see:

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — how the code is organised,
  class by class, and how to extend it.
- **[docs/RULES.md](docs/RULES.md)** — the rules as implemented, including every
  place the source material was ambiguous and the house-rule decision that was
  made instead.

## Status

A full 2-player game is playable end to end: dealing, capturing, announcements
(ronda/tringla), missa, the full tapping chain (Bount/Khamsa/Aachra), card-count
scoring, and a complete match to 41 points against a choice of three AI
difficulties. Nothing here has been run inside the Godot editor by the person
who wrote it (an AI assistant, working from the source only) — **treat the whole
project as unverified until someone opens it in Godot and plays a few rounds.**

Not done yet:
- **3 and 4-player games.** The rules engine (`core/`) already fully supports
  them (team sides, 13-card threshold, the four-player opening deal and its
  false-deal check). The screen (`ui/game_table.gd`) does not: it hardcodes two
  seats, "you" at the bottom and one opponent at the top.
- **The optional "dealer must win the last trick" ±5-point rules.** Not
  implemented, and not currently planned for unless requested.
- **Real card artwork is wired up but switched off.** See `ui/card_textures.gd`.

## Requirements

Godot **4.2 or newer** (uses typed arrays, `class_name`, and other GDScript
features from the 4.x line).

## Running it

1. Open the project folder in Godot.
2. Project Settings → Application → Run → Main Scene should already point at
   `main.tscn`; if not, set it.
3. Press Play.

There is no build step and no external dependencies — everything is plain
GDScript, and the card faces are drawn in code by default.

## Project layout

```
res://
├── main.tscn              The only scene. A full-rect Control with GameTable attached.
├── core/                   Rules engine. No Godot Node classes, no UI, no randomness
│                           beyond an injectable RandomNumberGenerator. This is what
│                           both the AI and the UI are built on top of.
│   ├── card.gd                 A single playing card. Immutable.
│   ├── deck.gd                 A pile of cards: shuffle, draw.
│   ├── announcement.gd         A declared ronda or tringla.
│   ├── tap_chain.gd            A tap stack that hasn't been settled yet.
│   ├── point_award.gd          One scored amount, with a reason, for the UI to show.
│   ├── move.gd                 A player's chosen action (PLAY/ANNOUNCE/TAP/COUNTER/DECLINE).
│   ├── move_result.gd          Everything that happened when a Move was applied.
│   ├── ronda_rules.gd          Stateless rule constants and helpers (capture logic,
│   │                           opening-deal validity, scoring tables).
│   ├── round_state.gd          THE central class: one round's full state, legal_moves(),
│   │                           apply_move(), clone() for AI lookahead.
│   └── match_state.gd          A whole game: running scores across rounds to 41.
│
├── ai/                     Computer opponents. Read a RoundState through AIKnowledge
│   │                       so they never see hidden information.
│   ├── ai_player.gd             Base class every AI implements.
│   ├── ai_factory.gd            Picks an AI for a difficulty level.
│   ├── ai_knowledge.gd          What a player can legitimately infer (unseen cards,
│   │                           opponent hand sizes, rank probabilities).
│   ├── random_ai.gd             Easy: captures when possible, otherwise random.
│   ├── heuristic_ai.gd          Medium: scores every move by gain minus risk.
│   └── monte_carlo_ai.gd        Hard: determinized Monte Carlo over sampled hands.
│
├── game/
│   └── game_controller.gd  A Godot Node: owns the MatchState/RoundState, decides
│                           whose turn it is, and drives the AI. No drawing code.
│
└── ui/                     Everything Godot-specific: Controls, Tweens, input.
    ├── card_view.gd             One card on screen: drawing, hover, click.
    ├── card_textures.gd         Optional switch to real card artwork (off by default).
    └── game_table.gd            The whole screen: layout, animation, turns the
                               engine's MoveResult objects into what you see happen.
```

## How the pieces fit together (short version)

`RoundState` is a plain data class with no knowledge of Godot. It exposes
`legal_moves()` and `apply_move(move) -> MoveResult`. Nothing else is allowed to
mutate game state directly — not the AI, not the UI.

`GameController` (a `Node`, so it can use `await`/timers) owns the current
`RoundState` and `MatchState`, and is the only thing that calls `apply_move()`.
After each move it waits for the view to say it has finished animating before
asking for the next one, via a small `round_started` / `move_applied` /
`awaiting_human` / `awaiting_ai` / `round_finished` signal protocol.

`GameTable` (the UI) only ever reads `controller.state`, reacts to its signals
by animating `CardView`s around, and calls `controller.human_play()` /
`human_announce()` / `human_tap()` / `human_counter()` / `human_decline()` when
the person clicks something.

See `docs/ARCHITECTURE.md` for the full detail, including the tap-chain state
machine, the AI's fairness model, and extension points for 3/4-player support.

## Contributing

- Every class is documented with a `##` doc-comment block at the top explaining
  its responsibility and any invariants it relies on (e.g. "the table never
  holds two cards of the same rank"). Read that before changing a file.
- `core/` must stay free of any `Node`/`Control`/scene-tree dependency. It should
  be possible to unit-test or script against it from a plain command-line Godot
  run. If you need something Godot-specific, it belongs in `game/` or `ui/`.
- House-rule decisions (places where the source Wikipedia page was ambiguous)
  are collected in `docs/RULES.md` rather than scattered across commit
  messages — add to that file, not just a code comment, if you change one.
- No automated tests exist yet (none were written for this project by request).
  If you add a test suite, GUT (Godot Unit Test) is the natural choice and was
  the original plan.
