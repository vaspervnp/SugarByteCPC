# SUGAR BYTE

**AMSTRAD CPC · 3" DISC · CASSETTE · 64K**

*A REVIVE8BIT production · VASPER · © 2026*

> Ελληνικά: [manual.el.md](manual.el.md)

---

## ★ YOUR CPC HAS A SWEET TOOTH ★

**Sixty boards. Six candies. One very hungry Amstrad.**

Swap two sweets, line up three, and watch the board go **pop**. Line up four
and you get a **striped candy** that wipes out a whole row. Make an L and you
get a **wrapped candy** that blows up everything around it. Line up five and
you get the **colour bomb** — swap it with any candy and every candy of that
colour on the board disappears at once.

And this isn't the CPC you know:

- **FULL OVERSCAN.** The picture fills the screen right to the edge of your
  monitor — no border, no wasted inches. 192 × 248 pixels of pure sugar.
- **IT TALKS.** *"Sugar Byte!" "Sweet!" "Delicious!" "Sugar Crush!"* — real
  digitised speech from the CPC's own sound chip. No speech box, no add-ons.
- **RASTER MAGIC.** Two palettes on one screen: the title cycles through every
  colour of the rainbow while the board keeps all sixteen of its own.
- **SUGAR CRUSH!** Finish a level with moves to spare and every leftover move
  turns into a striped candy — then they all go off at once.
- **THREE WAYS TO PLAY** — EASY to learn, MEDIUM to sweat, HARD to brag about.
- **SIXTY HAND-MADE LEVELS** — jelly to clear, icing to crack, chocolate that
  spreads, licorice that won't budge, cherries and hazelnuts to bring home, and
  boards shaped like diamonds, hourglasses and rings, where candies slide
  diagonally around the gaps.

**SUGAR BYTE.** *The sweetest thing that ever happened to your 6128.*

![The REVIVE8BIT screen, while the game loads.](docs/splash.png)

---

## LOADING

### From disc

1. Switch on your CPC and wait for the `Ready` prompt.
2. Put the disc in drive A, label side up.
3. Type

   ```
   RUN"SUGAR
   ```

   and press `ENTER`.
4. The **REVIVE8BIT** screen appears. Press `SPACE` to go straight on, or wait
   ten seconds and the game will load by itself.
5. You'll hear *"Sugar Byte!"* and the main menu appears.

**Do not** press `ESC` or reset while the drive light is on.

### From cassette

1. On a 6128 or a 664, type `|TAPE` and press `ENTER` first. (The `|` is
   `SHIFT` + `@`.) A 464 is already set up for tape.
2. Rewind the tape to the start.
3. Hold `CTRL` and press the small `ENTER` key, then press `PLAY` on the
   cassette deck and any key on the computer.
4. Loading takes about three and a half minutes. Then you'll hear
   *"Sugar Byte!"* and the main menu appears. (The cassette has no REVIVE8BIT
   screen.)

*Sugar Byte runs on any CPC with 64K: 464, 664 or 6128. The disc version needs
a disc drive. It was tested on the 6128.*

---

## THE MAIN MENU

![The main menu.](docs/menu.png)

Move the striped pointer with the **arrow keys** or the **joystick**, and choose
with **SPACE** or **FIRE**.

| | |
|---|---|
| **PLAY** | Start the level shown under it. |
| **LEVEL NN** | Enter a **level code** to jump to a level you've reached before (see *Level codes*). |
| **MODE EASY / MEDIUM / HARD** | Pick the difficulty: **SPACE** goes round the three (see *Difficulty*). |
| **SOUND ON / OFF** | Turn the music on or off. |
| **SCORES** | Your best score and stars for every level, for the difficulty you've picked. Twenty levels to a page: **←** and **→** turn the page, **SPACE** or **ESC** goes back. |

---

## HOW TO PLAY

![Level 17: jelly to clear and two cherries to bring down.](docs/level-17.png)

The board is 8 × 8. Move the cursor with the **arrows** or the **joystick**
and press **SPACE** / **FIRE** to pick up a candy — it lights up in cyan. Then
pick a candy right **next to it** (left, right, above or below) and the two
swap places.

- If the swap makes a line of **three or more of the same colour**, across or
  down, they pop. The candies above fall to fill the gap and new ones drop in
  from the top. If the falling candies make new lines, those pop too — that's
  a **chain**, and every link in the chain multiplies your points.
- If the swap doesn't make a line, the candies swap back and it doesn't cost
  you a move.
- Pick the same candy again to drop it. Pick one further away and your
  selection jumps to that one instead.

Every swap that works uses up **one move**. The moves left are shown next to
the two arrows in the panel on the right.

**Stuck?** Wait five seconds without touching anything and two candies will
start to wiggle towards each other — that's a move you can make. If there are
no moves left on the whole board at all, the board is shuffled for free.

| Key | |
|---|---|
| Arrows / joystick | Move the cursor |
| SPACE / FIRE | Pick up, swap |
| M | Music on / off |
| ESC | Back to the menu |

---

## THE PANEL

From top to bottom:

- **The jar** — your score.
- **The arrows** — moves left. **The padlock** — this level's code.
- **The goal** — what you need to do to win the level: points to reach, jelly
  squares left to clear, ingredients left to bring down.
- **LEVEL NN** — the level you're on, and under it the difficulty: **EASY**, **MEDIUM** or **HARD**.
- **Three stars** and the **progress bar** — they light up as your score
  passes each star's target.

---

## THE GOALS

Every level has a limited number of moves and one goal:

- **SCORE** — reach the target score.
- **JELLY** — clear every jelly square. Jelly sits **under** the candies; it
  goes when a candy pops on top of it. Double jelly needs two pops.
- **INGREDIENTS** — bring the cherries and hazelnuts down to the bottom. They
  don't match and don't pop: clear the candies underneath them and they fall.
  They leave the board when they reach the bottom row — **or when they sit
  right on top of a gap**.
- **JELLY + INGREDIENTS** — both at once.

Reach the goal and you win, however many moves you have left. Then comes
**Sugar Crush**: every move you didn't use turns a random candy striped, and
then everything goes off at once, for points.

![Sugar Crush: the moves you didn't need become striped candies.](docs/sugar-crush.png)

When the level is won, the stars you earned appear on the board: **one** for
winning, **two** and **three** for higher scores. Press **SPACE** to go on to
the next level, with its code shown in the panel.

If you run out of moves first, the border flashes. Press **SPACE** to try the
same level again, or **ESC** for the menu.

---

## DIFFICULTY

Every level can be played three ways. Choose with **MODE** in the menu before
you press **PLAY**:

| | |
|---|---|
| **EASY** | All the moves the level was designed with. Start here. |
| **MEDIUM** | About four fifths of the moves. |
| **HARD** | About two thirds of the moves — every swap has to count. |

The board and the goal stay the same, so the same plan works — you just have
less room for mistakes. Fewer moves also means fewer points, so the stars are
harder to get too, and fewer moves are left over for Sugar Crush. Your best
scores and stars are kept separately for each difficulty, and a level code
works in all three.

---

## SPECIAL CANDIES

| Line up | You get | It does |
|---|---|---|
| 4 in a row | **Striped candy** | When it pops, it clears its whole row — or its whole column — with a beam. |
| An L or a T shape | **Wrapped candy** | When it pops, it blows up the 3 × 3 square around it. |
| 5 in a row | **Colour bomb** | Swap it with any candy: every candy of that colour pops. |

A special candy appears where you made the move, and it pops when it's part of
a line — or when another special candy hits it.

**Swap two special candies together** for something much bigger:

| Swap | Effect |
|---|---|
| Striped + striped | A whole row **and** a whole column. |
| Striped + wrapped | A cross three candies wide. |
| Wrapped + wrapped | A 5 × 5 explosion. |
| Bomb + striped | Every candy of that colour turns striped — and they all go off. |
| Bomb + wrapped | Every candy of that colour turns wrapped — and they all go off. |
| Bomb + bomb | The whole board. |

---

## WHAT'S ON THE BOARD

| | |
|---|---|
| **Jelly** | Under the candies. Pop a candy on top to clear one layer. |
| **Icing** (1–3 layers) | A block. Each line popped next to it, or a special candy's beam, breaks one layer. |
| **Chocolate** | A block that **spreads**: if you finish a move without breaking any chocolate, it grows onto a candy next to it. |
| **Licorice** | A block that breaks the way icing does. |
| **Gaps** | Holes in the board. Nothing ever goes there. |

Candies can't fall **through** a block or a gap. Instead they **slide
diagonally** around it: an empty square that nothing can reach from above takes
the candy from the square above-left or above-right. So even the oddest-shaped
boards fill up again — and blocks hold their shape until you break them.

![Level 56: a ring of icing, gaps, and jelly all around the edge.](docs/level-56.png)

---

## SCORING

| | Points |
|---|---|
| A line of 3 | 60 |
| A line of 4 | 120 |
| A line of 5 | 200 |
| Each candy hit by a special | 60 |
| Each layer of jelly | 100 |
| Each ingredient brought down | 1,000 |

**Everything is multiplied by the chain:** the first pop counts once, the pops
caused by falling candies count twice, the next ones three times, and so on.
A long chain also gets a *"Sweet!"* — and a really long one, *"Delicious!"*

---

## LEVEL CODES

Every level has its own four-digit code. It's shown next to the **padlock** in
the panel while you play, and when you win a level the panel shows the code for
the **next** one. Write them down.

To use a code, choose **LEVEL NN** in the menu and press **SPACE**. The plate
turns into `CODE 0000`:

- **← →** pick a digit (it flashes),
- **↑ ↓** change it,
- **SPACE** to accept, **ESC** to cancel.

A good code takes you straight to that level. A wrong one makes a sour noise
and lets you try again.

The first one's free: level 1 is **4721**.

*Best scores and stars are kept for as long as the computer stays on.*

---

## HINTS FROM THE KITCHEN

- **Play low.** Moves near the bottom of the board shake up everything above
  them and set off more chains than moves near the top.
- **Make special candies before you need them.** A line of four in the right
  place saves you three moves later.
- **Bring the ingredients down by their own column.** They only move when the
  squares right under them are cleared.
- **Never leave chocolate alone.** Break at least one piece every move, or it
  takes over.
- **Keep moves for the end.** Every move you don't use becomes a striped candy
  during Sugar Crush, and that's where the three stars are.

---

## CREDITS

**Design, code, graphics:** VASPER
**A REVIVE8BIT production · 2026**

Written in Z80 assembly with rasm. Graphics drawn in CPCArt. Speech generated
on a PC and played back as 4-bit samples through all three channels of the
CPC's AY sound chip at the same time.

---

*Sixty levels. Sixteen colours. One sweet tooth.*

## **SUGAR BYTE — Pop it. Swap it. Crush it.**

*Available on 3" disc and cassette for the Amstrad CPC.*
