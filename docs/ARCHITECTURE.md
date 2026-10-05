# Architecture

This document explains how the code is organised and why, in enough detail
that someone can extend it (new AI, 3/4-player UI, new scoring rule) without
re-deriving the design from scratch. For *what the rules are*, see
[RULES.md](RULES.md). This document is about *how the code implements them*.

## Layering

```
core/   <-  ai/   <-  game/   <-  ui/
```

Each layer only depends on the ones to its left.

- **`core/`** is the rules engine. Every class is `RefCounted`, not `Node`: no
  scene tree, no signals, no `_process()`. It can be exercised from a
  stand-alone script with no scene open at all. `RoundState.new_round(...)`,
  `legal_moves()`, `apply_move()` and `clone()` are the entire public surface
  anything else needs.
- **`ai/`** reads a `RoundState` and returns a `Move`. It never mutates state
  itself and never reads another player's hand directly — see
  [AI fairness](#ai-fairness-aiknowledge) below.
- **`game/`** is `GameController`, a `Node`. It's the only thing in the project
  allowed to call `RoundState.apply_move()` during real play. It owns turn
  order and timing (AI "thinking" delays) but draws nothing.
- **`ui/`** is `GameTable` plus its helpers (`CardView`, `CardTextures`). It
  only *reads* the controller's state and *reacts* to its signals. It never
  calls `apply_move()` directly — only through `controller.human_*()` methods.

If you're adding something and you're not sure which layer it belongs in: can
it be exercised with no `Node` in the tree at all? If yes, it's `core/`. Does it
decide what move to make? `ai/`. Does it draw something or read mouse input?
`ui/`. Everything else (turn sequencing, timing) is `game/`.

## The `core/` engine

### Data model

| Class | Role |
|---|---|
| `Card` | One of the 40 cards. Immutable after construction, so `Card` instances are shared freely between `RoundState.clone()` copies. Ranks are `1 2 3 4 5 6 7 10 11 12` — there is no 8 or 9. `order_index()` gives a card's position in that sequence (0–9); two cards are "consecutive" when their indices differ by 1. |
| `Deck` | A pile of cards (talon). `draw()`/`draw_many()` pop from the end; `shuffle()` takes an optional seeded RNG. |
| `Announcement` | A declared ronda (pair) or tringla (three of a kind): seat, kind, rank. `strength()` orders them for comparison (any tringla beats any ronda, then higher rank wins). |
| `TapChain` | A tap stack that hasn't been settled: the rank, the stacked cards in order, and who laid each one. See [Tapping](#tapping-the-state-machine). |
| `PointAward` | One scored amount with a human-readable reason ("Bount", "Missa", "Ronda of 7", "Hidden ronda penalty", …), attached to the `MoveResult` it happened on. |
| `Move` | A player's chosen action. Five types: `PLAY`, `ANNOUNCE`, `TAP`, `COUNTER`, `DECLINE`. Built through static constructors (`Move.play(seat, card)`, etc.), never `Move.new()` directly. |
| `MoveResult` | Everything that happened when a `Move` was applied — see [below](#the-moveresult-contract). |
| `RondaRules` | Stateless constants and pure functions: capture logic, opening-deal validity, scoring tables. No state, so call it from anywhere. |
| `RoundState` | One round's complete, mutable state, and the only thing that can change it (`apply_move`). |
| `MatchState` | A sequence of rounds to 41 points: owns the running score and the dealer rotation, and creates each `RoundState` via `RoundState.new_round()`. |

### Seats vs. sides

A **seat** is a physical player, numbered `0..player_count-1` in play order
(after seat `p` comes `(p+1) % player_count`). A **side** is whoever collects
cards and points together: with 2 or 3 players every seat is its own side; with
4 players, seats 0+2 are side 0 and seats 1+3 are side 1 (partners sit
opposite). `RoundState.side_of(seat)` converts between the two. `captured`,
`round_points`, and `MatchState.scores` are all indexed **by side**, not seat —
this is the single most common mistake to make when touching this code.

### The table invariant

The table (`RoundState.table`) **never holds two cards of the same rank**. This
is guaranteed by the opening-deal validation (`RondaRules.deal_table`) and by
every capture/throw rule, and a lot of code relies on it implicitly — most
importantly `RondaRules.find_capture()`, which can build a `rank -> card`
dictionary from the table without worrying about collisions. If you ever change
a rule in a way that could put two same-rank cards on the table, audit every
caller of `find_capture`/`find_run_above` before shipping it.

### The `Move`/`MoveResult` contract

`RoundState.apply_move(move)` is the only way to change the state, and it
always returns a `MoveResult`:

- If the move was illegal, the state is **untouched** and the result has
  `ok == false` with a human-readable `error`. Callers (the UI, the AI) should
  never construct an illegal move on purpose, but the engine doesn't trust them
  not to.
- If it was legal, the result carries **everything a renderer needs to animate
  the move** — which card was played, what was captured, whether a missa or
  tap chain was settled, whether a new deal happened, whether the round ended
  — so that `ui/game_table.gd` never has to re-derive "what just happened" by
  diffing two states. This is a deliberate design choice: state diffing is
  fragile and duplicates logic that the engine already knows for free while
  it's making the change.

`legal_moves()` returns every `Move` currently available to `current_player`.
The UI and every AI are expected to only ever submit moves from this list (or
equivalent ones built the same way) — `is_legal()` exists for defence in depth,
not as the primary way callers are expected to find out what they can do.

### Tapping: the state machine

This is the most involved part of the engine, so it gets its own section.
Tapping lets the player right after a plain throw (a play that didn't capture)
react with a matching card instead of taking their own ordinary turn. If
another player can add a further matching card, the pile keeps growing —
Bount (2 cards) → Khamsa (3) → Aachra (4) — until someone can't or won't
continue it.

**State:** `RoundState._last_throw` / `_last_throw_seat` remember the card a
plain `PLAY` just put on the table and who threw it — this is private
bookkeeping, not exposed to the UI or AI directly (use `can_tap()` instead).
`RoundState.tap_chain` (a `TapChain`, or `null`) holds a stack that has been
started but not yet settled: cards aren't on the table and aren't in anyone's
pile while this is non-null.

**The five move types involved:**

- `PLAY` — only legal while `tap_chain == null`. A normal turn: capture if the
  card pairs with something on the table (this also clears `_last_throw`), or
  throw it (this sets `_last_throw`/`_last_throw_seat`, opening the possibility
  of a tap on the *next* player's turn).
- `TAP` — only legal for the seat right after `_last_throw_seat`, with a card
  of the matching rank (`RoundState.can_tap()`). Removes the thrown card from
  the table, creates a new `TapChain` of 2 cards, and hands the turn onward.
- `COUNTER` — only legal while `tap_chain != null`, with a card of
  `tap_chain.rank`. Adds a third or fourth card to the stack.
- `DECLINE` — only legal while `tap_chain != null`. Settles the chain for
  whoever laid its last card, then — importantly — **does not advance the
  turn**: the decliner immediately gets a normal move. (`GameController`'s
  `_advance()` loop handles this transparently: it just checks
  `state.current_player` again after every applied move, so a stalled turn
  "just works" without the controller needing to know the reason.)

**Resolution (`_after_layer`):** after a `TAP` or `COUNTER` is applied, the
engine checks whether the *next* player could plausibly continue the chain
(`tap_chain.level() < MAX_TAP_LEVEL` and they hold a card of the rank). If so,
the move's result just has `tap_pending = true` and the turn passes to them to
decide (`COUNTER` or `DECLINE`). If not — no higher card could possibly exist in
their hand, or the stack is already at 4 — the chain is **settled
automatically**, with no explicit decline needed.

**Settling (`_resolve_chain`):** the stack, **plus the ascending run of table
cards still sitting above its rank** (`RondaRules.find_run_above`), all go to
whoever laid the stack's last card. This is a deliberate reading of the
original rules (see [RULES.md](RULES.md#tapping) for the reasoning): an
unanswered tap is **never worse** than an ordinary capture would have been —
it gets the same cards, plus a bonus. The risk is entirely on the other side:
if someone counters, the entire pile (not just the 2-card stack) goes to them
instead.

**Missa interacts with tapping the same way it does with an ordinary capture**
(`_check_missa`, called from both `_apply_play`'s capture branch and
`_resolve_chain`): if the cards leaving the table empty it out (and it isn't
the last hand), a separate `"Missa"` award is added on top of the
Bount/Khamsa/Aachra award. The source material describes this as the *same*
score shifted up by one (Bount worth 2 instead of 1, etc.); splitting it into
two `PointAward` lines instead gives the identical total while letting the UI
show *why* the extra point happened, which seemed more useful than matching
the exact wording.

### `clone()` and AI lookahead

`RoundState.clone()` makes a fully independent copy — `Card`/`Announcement`
instances are shared (they're immutable so this is safe), every container
(`hands`, `table`, `captured`, per-deal tracking dictionaries, `tap_chain`) is
duplicated. This is what `MonteCarloAI` uses to simulate games: clone, apply a
candidate move, keep playing with a cheap policy, read off a score, throw the
clone away. If you add new per-deal state to `RoundState`, **you must also add
it to `clone()`** or AI lookahead will silently see stale/shared data.

## AI fairness: `AIKnowledge`

Every `AIPlayer.choose_move(state, rng)` is handed the *real* `RoundState`,
which technically contains every hand, including the other players'. The
engine does not stop an AI from reading `state.hand_of(other_seat)` — nothing
in GDScript enforces that boundary. Instead, **the convention this project
follows is that every AI builds an `AIKnowledge` object first and only reasons
about what that exposes**: its own hand, the table, every captured pile
(captures happen face up), a stacked tap chain (also face up), and only the
*size* of each opponent's hand, never its contents. Everything else — the
other hands and the talon — is pooled into `unseen`, and
`probability_opponents_hold(rank)` gives the hypergeometric chance that at
least one unseen copy of a rank is actually in an opponent's hand rather than
the talon.

**If you write a new AI, treat this as a hard rule, not a suggestion**: reach
for `AIKnowledge` instead of `state.hands[other_seat]`, even though nothing
will stop you from cheating. The existing three AIs (`random_ai.gd`,
`heuristic_ai.gd`, `monte_carlo_ai.gd`) are the reference for how to do this.

### The three difficulties

| | Class | Approach |
|---|---|---|
| Easy | `RandomAI` | Always announces and always answers a tap it can. Otherwise: plays a capturing card at random if one exists, else a random card. Never initiates a tap. |
| Medium | `HeuristicAI` | Scores every candidate card as *(what I capture now) − (what the opponent is expected to capture next turn, weighted by the probability they hold each needed rank) + a discounted bonus for a capture I could make myself next turn*. A tap gets an extra term (`_tap_bonus`) weighing the Bount point against the risk of a Khamsa. Answering a tap (`_answer_tap`) is a small closed-form decision based on the probability a fourth card exists. |
| Hard | `MonteCarloAI` | Determinized Monte Carlo: repeatedly deals the unseen cards into a plausible "world" (respecting known hand sizes), tries every candidate move in that same world, plays the rest of the current deal out with a cheap fixed policy (`_fast_policy`), and scores the outcome. Candidates are compared using the *same* sampled worlds and RNG draws, so the comparison is fair even with relatively few samples. Thinks for `think_time_ms` (default 350ms) on the main thread — this will cause a brief visible pause; lower it if that's a problem for your use case. |

`AIFactory.create(difficulty)` is the only place that should construct an AI;
`GameController.set_difficulty()` is the only place that should call it during
play. To add a fourth difficulty: implement `AIPlayer`, add an enum value to
`AIFactory.Difficulty`, and handle it in `AIFactory.create()` and
`AIFactory.NAMES`.

## `game/game_controller.gd`: turn sequencing

`GameController` is a `Node` (so it can `await` timers) that owns the
`MatchState` and the `RoundState` currently being played, and nothing else. Its
job is exactly: decide whose turn it is, run the AI with a visible "thinking"
delay, and apply whatever move it's handed — and wait for the *view* to
confirm it has finished presenting the previous move before doing any of that.

The signal protocol is small on purpose:

```
round_started            -- a new round was just dealt
move_applied(result)     -- a move was just applied; animate it
awaiting_human           -- it's the human's turn; call one of human_*()
awaiting_ai               -- the AI is about to think, then move
round_finished            -- the round just ended (points already added to the match)
```

The view calls `presentation_finished()` exactly once after it's done
reacting to any of `round_started`/`move_applied`, and that's what triggers
the controller to figure out what happens next (`_advance()`). This
request/acknowledge pattern is what keeps animations from overlapping and
stops the AI from moving while cards are still flying across the screen — it's
worth preserving if you touch this file, rather than having the controller
fire-and-forget.

Human input comes in through five narrow methods —
`human_play/announce/tap/counter/decline` — each of which just builds the
matching `Move` and calls the private `_apply()` helper (which itself just
calls `state.apply_move()` and emits `move_applied`). They all guard against
being called out of turn or while the view is still busy, but they trust the
caller (the UI) to only call the one that matches what `legal_moves()` is
currently offering — same convention as the AI layer.

## `ui/`: the view

`GameTable` builds its entire interface in code in `_build_ui()` (no other
scene files needed beyond `main.tscn`, which just attaches this script to a
full-rect `Control`). It never applies rules; it only:

1. Reads `controller.state` to know what to draw.
2. Reacts to the controller's signals by animating `CardView`s and calling
   `controller.presentation_finished()` once done.
3. Forwards clicks to `controller.human_*()`.

### Card positioning

All `CardView`s live in one `Control` (`_card_layer`), and "moving a card
between zones" (hand → table → pile, or into/out of a tap stack) is just
calling `CardView.move_to(new_position)` — there's no separate reparenting per
zone. `_layout()` recomputes every position (hand row, table row, talon,
piles, the tap stack) from scratch and is called both after a resize
(`animate = false`, cards jump) and after state changes (`animate = true`,
cards glide via `Tween`).

### Presenting a `MoveResult`

`_on_move_applied(result)` dispatches on `result.kind` to one of several
`_present_*` helper coroutines (`_present_tap_or_counter`, `_present_decline`,
the inline `PLAY`/`ANNOUNCE` handling, `_present_round_sweep`). Every one of
these follows the same pattern: animate, `await` a fixed pause, **re-check
`id != _presentation_id` after every await** before touching any view, then
continue or return. `_presentation_id` is bumped every time a new round
starts; this guard is what stops an in-flight animation from a just-abandoned
round from touching views that no longer exist (e.g. if `New match` is clicked
mid-animation). If you add a new kind of animated event, copy this pattern —
skipping the guard is the most likely source of a crash-on-resize/new-game bug
in this codebase.

### Tap-specific UI

- A card in hand that could tap the just-thrown card gets a small floating
  "Bount!" `Button` positioned above it (`_update_tap_badges`), separate from
  the card's own click handler — clicking the *card* still plays it normally
  (full capture, no bonus); clicking the *badge* taps it. This is how the UI
  resolves the fact that the same card is simultaneously a legal `PLAY` and a
  legal `TAP`.
- While `state.tap_chain != null`, only hand cards matching the chain's rank
  are made `interactive`; clicking one now means `COUNTER` instead of `PLAY`
  (`_on_hand_card_pressed` checks `controller.state.tap_chain != null` to
  decide which controller method to call). A `"Let it go"` button
  (`_decline_button`) calls `human_decline()`.
- Cards currently stacked in an unsettled chain live in `_tap_stack_views`,
  positioned near the centre of the table with a small cascading offset
  (`_position_tap_stack`) so every card in the stack stays visible. They move
  into the scorer's pile only once `MoveResult.chain_resolved` is true.

### `CardView` and `CardTextures`

`CardView` draws its own face and back in `_draw()` — rank, a simple
pictogram per suit, hover lift, a highlight outline (used to preview what a
hovered card would capture). `CardTextures.face(card)`/`back()` can return
real images instead, loaded from `res://assets/cards/` (`1.PNG`…`40.PNG` and
`back.PNG`); this is currently **switched off** via
`CardTextures.USE_ARTWORK = false`. Flip that constant to `true` to use
artwork instead — see the comment there for the expected file-number mapping
(suit order, rank order within a suit) and what to do if yours differs.

## Known gaps / where to extend next

- **3 and 4 players**: `RoundState`/`MatchState`/`RondaRules` already handle
  every rule difference (team sides, the 13-card threshold, the four-card
  opening deal and false-deal redeal, the hidden-ronda penalty target with 3
  players). Only `ui/game_table.gd` needs work: it hardcodes `HUMAN_SEAT`/
  `OPPONENT_SEAT` and a two-row layout. A 3/4-player layout would need to pick
  seat positions around the table and generalise `_pile_position`,
  `_place_row`, and the opponent-hand rendering to loop over
  `controller.state.player_count` seats instead of one fixed opponent.
- **`MonteCarloAI` never initiates a tap in its own rollouts** (`_fast_policy`
  only ever answers one) — a reasonable simplification, but it means the Hard
  AI's own evaluation of tapping is driven entirely by the top-level candidate
  comparison in `choose_move`, not by what it imagines happening several moves
  later. If tapping ever needs to be smarter, this is the place to improve.
- **No automated tests.** None were written for this project (by explicit
  request while it was being built). If that changes, GUT is the natural
  choice and `core/` was deliberately kept Node-free so it's easy to drive
  from a test script.
