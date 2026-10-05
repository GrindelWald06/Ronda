# Rules, as implemented

Source: [Ronda (jeu de cartes) — French Wikipedia](https://fr.wikipedia.org/wiki/Ronda_(jeu_de_cartes)).

This game is traditional and the Wikipedia article, like most descriptions of
it, leaves several points genuinely ambiguous. Rather than bury those
decisions in commit history or scattered code comments, every place this
project had to make a call is listed here explicitly, with the reasoning,
**so a future contributor can find and reconsider it** rather than assume it
was settled by careful research. Where a decision is a simple constant, the
constant name is given so it's easy to find and change.

## The deck

40 cards, 4 suits (coins/cups/swords/clubs), ranks `1 2 3 4 5 6 7 10 11 12` —
no 8 or 9. In sequence terms, 7 is immediately followed by 10 (`Card.RANK_ORDER`).

## Dealing

- **2 or 3 players:** each player gets 3 cards, and 4 cards go face up on the
  table.
- **4 players (2 teams of 2, partners opposite each other):** each player gets
  4 cards on the **first** deal of the round only, and the table starts empty.
  A deal where any hand holds four of a kind is a false deal and everything is
  reshuffled and redealt (`RondaRules.has_four_of_a_kind`).
- Once every hand is empty, 3 more cards (2/3 players) are dealt to each seat
  from the talon, repeating until the talon runs out. The deal that empties
  the talon is the last hand of the round ("Khlassou!").

**Opening table validity — decision made:** the table must not start with a
pair, nor with a "suite" (run of consecutive ranks). The source doesn't say
how long a run has to be to count as a suite. This project uses **3
consecutive ranks** as the threshold (so 6-7-10 on the table is invalid, but
6-7 alone is fine) — `RondaRules.INVALID_TABLE_RUN_LENGTH`. Set it to `2` for a
stricter deal where even a single adjacent pair is disallowed. When the table
is invalid, the last offending card is pushed back into the middle of the
talon and replaced, repeated until valid (`RondaRules.deal_table`).

## Capturing

Playing a card that shares a rank with a table card captures it, **and then
continues upward through the sequence** for as long as the next rank is also
on the table (no wraparound from 12 back to 1) —
`RondaRules.find_capture`. Example: hand has a 5, table has 5, 6, 7, 10, 12 →
playing the 5 captures 5, 6, 7, 10 (the 12 is not consecutive with 10, so it
stays). A card that doesn't pair with anything is thrown face up onto the
table instead.

## Announcements (ronda / tringla)

Before playing their first card of a deal, a player holding a pair may
announce **"Ronda!"**, or holding three of a kind may announce **"Tringla!"**
(`RondaRules.find_announcement` — a hand's best pair, or its three of a kind if
it has one). This doesn't use up a turn; the player still plays a card
normally afterward. Once every player in the deal has played their first card,
every announcement made is compared and scored:

- If any tringla was announced, the strongest one takes 5 points **plus one
  point for every ronda announced that deal** — the ronda announcers get
  nothing.
- Otherwise, every ronda announced puts one token in a shared pot, and the
  strongest ronda (by rank; **decision:** higher rank wins, so the king/12
  beats everything) takes the pot. If several players tie for strongest, they
  split the pot evenly; a token that doesn't divide evenly is simply lost (not
  awarded to anyone) — three rondas announced, two tied for best, gives those
  two 1 point each and leaves 1 unclaimed.
- **Late announcements aren't possible at all**: the engine only offers
  `ANNOUNCE` as a legal move before that seat's first card of the deal
  (`RoundState.available_announcement`), matching the rule that an
  announcement after your first card scores nothing.
- **Hidden ronda penalty:** if a player holds a pair, never announces it, and
  then plays both cards of it during the same deal, the moment the second one
  is played the *other side* is awarded 5 points
  (`RondaRules.HIDDEN_RONDA_PENALTY`). **Decision, 3-player games:** the
  penalty goes to whichever opponent made the strongest announcement that
  deal, or to the next seat in play order if nobody announced
  (`RoundState._penalty_side`) — the source doesn't specify who benefits when
  there's more than one opponent.
- A hidden **tringla** (three of a kind never announced) is treated the same
  way the moment its second card is played — it contains a hidden pair.

## Missa

Capturing every remaining card on the table (leaving it empty) scores 1 point
(`RondaRules.MISSA_POINTS`), **except on the last hand of the round**
("Khlassou!") — clearing the table there is normal and un-bonused.

## Tapping ("Bount" / "Khamsa" / "Aachra")

This is the most elaborate rule and the one with the most judgment calls, so
it gets its own subsection. See
[ARCHITECTURE.md](ARCHITECTURE.md#tapping-the-state-machine) for how it's
implemented in code; this section is about *what* was decided and *why*.

The source describes: when the player right after someone who just **threw**
a card (a play that didn't capture) holds a matching card, they may "tap" it
by playing their matching card and declaring **"Bount!"**. If the player after
*them* also holds a matching card, they may add it, declaring **"Khamsa!"**
(5 points). If a further player holds the last copy, declaring **"Aachra!"**
(10 points) takes everything. If the tap that started the chain also happens
to empty the table, every score in the chain is one point higher (Bount
becomes 2, Khamsa becomes 6, Aachra becomes 11).

**Decisions made, because the source leaves these open:**

1. **Tapping is optional and distinct from an ordinary capture of the same
   card**, offered as a separate legal move (`TAP`) alongside the normal
   `PLAY`. A player who holds the matching card chooses which to do.
2. **An unanswered tap keeps the same cards an ordinary capture would have**
   — the stack *and* the ascending run of table cards above its rank — **plus
   the Bount/Khamsa/Aachra bonus on top.** This was not obvious from the
   source, which only describes "pairing" without clarifying whether the run
   above is included. The choice made here means tapping is never worse than
   an ordinary capture in terms of cards won, only riskier: if someone else
   extends the chain, the *entire* pile (stack and run both) goes to whoever
   laid the chain's last card instead, and the original tapper gets nothing
   from it.
3. **Reaching the table-clearing bonus is modeled as a separate, additional
   point award** ("Missa") rather than literally bumping the Bount/Khamsa/
   Aachra score by one. The *total* points awarded are identical either way
   (Bount 1 + Missa 1 = 2, matching the source's "becomes 2"; Khamsa 5 + Missa
   1 = 6; Aachra 10 + Missa 1 = 11) — this is purely a presentation choice, so
   the UI can show "Bount: +1, Missa: +1" instead of a single opaque "+2".
4. **The tap opportunity belongs to exactly one player at a time**, strictly in
   play order: the seat right after the thrower, then (if the chain continues)
   the seat right after them, and so on. If that player has no matching card
   at all, the chance simply doesn't arise (no `TAP`/`COUNTER` move is legal
   for them) — there's no separate "pass" needed in that case, only when they
   *do* hold a matching card but choose `DECLINE` instead.
5. **In a 2-player game, a chain can legitimately return to the original
   thrower** — if they happen to hold the stack's third copy, they're "the
   player after" the tapper, same as in any other player count, and the code
   doesn't special-case this out. It will feel odd narrated as "the opponent
   to your left" the way the source phrases it, but the underlying mechanic
   (whoever holds each next copy of the rank, in turn order) is unaffected by
   how few players there are.
6. **A chain that's still open when the round or deal would otherwise end is
   force-settled for whoever currently holds it**, rather than discarded or
   left dangling. This can't actually happen under the implemented turn
   sequencing as written (settling or asking for a decision always happens as
   part of applying the move that grew the chain, before any deal-end check),
   but the engine resolves this defensively rather than relying on that.

## Card-count scoring

At the end of a round, after the last capturer sweeps whatever remains on the
table, each side scores 1 point for every card it won beyond a threshold:
**13 cards with 3 players, 20 cards with 2 players or with 4 players in
teams** (`RondaRules.card_threshold`).

## Winning the match

Rounds are played, with the deal passing to the next seat each time, until a
side's total reaches **41 points** (`RondaRules.WIN_SCORE`,
`MatchState.target_score`). **Decision:** this is checked only at round
boundaries, after a round's points have all been added — if two sides would
both cross 41 in the same round, the higher total wins; an exact tie at the
top means the match continues with another round (`MatchState.winning_side`).

## Not implemented

- The optional **"dealer must win the last trick"** variant and its
  associated ±5-point rules, mentioned on the source page as a regional
  variant. Nothing in the engine currently accounts for it.
- Anything specific to **3 or 4 players beyond what the rules engine already
  supports** — see [ARCHITECTURE.md](ARCHITECTURE.md#known-gaps--where-to-extend-next)
  for exactly what's missing (it's UI, not rules).
