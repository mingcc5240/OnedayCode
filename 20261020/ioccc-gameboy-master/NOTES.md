# GameBoy Terminal

Emulates a GameBoy original DMG in the terminal.

Needs unicode capable terminal set to at least 

## Accuracy

In order to get the emulator to fit in the constraints available, we had to strip out a lot of features.

We aimed for the lowest spec of games

- 32k ROM only
- No sound
- Non accurate CPU cycle timing
- No H flag emulation which breaks DAA after subtract
- Graphics: Sprites cut down to the minimum 8x8 support
- Hardcoded Palette (Assume standard 0xE4 mapping)

This leaves us with the classic Tetris and Dr. Mario.

## Missing features

Here are the missing features in detail

### CPU & Core Logic

- Precise Timing: Instructions execute instantly in a single step. There is no concept of M-cycles or T-cycles, meaning the CPU speed is not accurately throttled relative to the PPU or Timer.
- Interrupt Delays: The `EI` (Enable Interrupts) instruction sets `IME` immediately. On real hardware, the effect is delayed by one instruction.
- STOP Instruction: The `STOP` instruction (opcode 0x10) is treated as a NOP, missing the specific "speed switch" logic (for CGB) or state freezing until a button press.
- H Flag (Half-Carry): The Half-Carry flag is completely ignored. This breaks the `DAA` instruction, which relies on accurate H flag state. The `DAA` instruction should work for addition though.

### Memory & Hardware

- Memory Bank Controllers (MBC): There is no support for MBC chips (MBC1, MBC3, etc.). The emulator reads a flat 32KB, limiting compatibility to 32KB games like *Tetris* or *Dr. Mario*.
- External RAM (SRAM): No support for external cartridge RAM or saving games (battery-backed RAM).
- DMA Timing: The OAM DMA transfer (register 0xFF46) is instantaneous. On real hardware, this locks the bus for ~160 microseconds.
- Timer Accuracy: The timer (DIV register 0xFF04) increments once per CPU step. It ignores the TAC register (0xFF07) configuration (frequency selection and start/stop) and does not trigger the Timer Interrupt (Bit 2 of IF).
- Serial Port: The Serial Data transfer (SB 0xFF01, SC 0xFF02) is not implemented (used for Link Cable). This means selecting 2 player in *Tetris* freezes the emulator.

### Graphics (PPU)

- LCD Status Interrupts (STAT): The STAT register (0xFF41) logic is missing. It does not trigger interrupts for H-Blank, V-Blank (STAT source), or LY=LYC coincidence.
- LY=LYC Check: The hardware feature that compares the current scanline (LY) to a comparison value (LYC) and sets a status bit/interrupt is missing.
- Sprite Limits: The hardware limit of 10 sprites per scanline is not enforced; all valid sprites are drawn.
- VRAM Accessibility: The emulator allows the CPU to read/write VRAM and OAM at any time. Real hardware blocks access during Mode 2 (OAM Search) and Mode 3 (Pixel Transfer).
- Window Layer: The Window layer (overlay) is completely removed.
- Sprite Features: No priority handling (background over sprite), no x/y flipping, and no 8x16 sprite mode.

### Audio

- APU (Audio Processing Unit): Completely missing. Writes to 0xFF10-0xFF3F are ignored.

### General

- Boot ROM: The boot sequence is skipped, and registers are manually initialized to their post-boot values.
- Game Boy Color (CGB) Features: No double-speed mode, VRAM banking, or palette memory (CGB palettes) are supported.

## Rule hacking

Based on the `rule_count.c` source code provided, here is a breakdown of specific tricks to lower the IOCCC Rule 2b score. The tool contains several logic quirks to exploit.

### 1. The "Space-After" Exploit (Biggest Savings)

The tool explicitly ignores `{`, `}`, and `;` if they are followed by whitespace.

* **Source Logic:** `if (strchr("{;}", ch) != NULL && (isspace(next_ch) || next_ch == EOF)) continue;`
* **Trick:** Ensure every `;`, `{`, and `}` is followed by a space or newline.
* **Score Change:**
* `if(a){b;}` → `{`, `;`, `}` count as 3 points.
* `if(a){ b; } ` → `{`, `;`, `}` count as 0 points.

### 2. The String-Whitespace Loophole

The tool processes "ignore whitespace" *inside* the main loop, even when it is inside a string state. This means **spaces inside string literals are free**.

* **Source Logic:** The `if (isspace(ch)) continue;` check runs before the character counting increment, and it does not check if `quote` is active.
* **Trick:** You do not need to compress strings like `"Hello\nWorld"`. You can write `"Hello \n World"` with extra spaces for readability or formatting without increasing your score.

### 3. The `iso646.h` Operator Swap

The tool counts any C keyword (defined in its `cwords` list) as **1 point**, regardless of length. This list includes the alternative operator keywords from `<iso646.h>` (even if you don't include the header, the tool sees the text; but your code must compile).

* **Source Logic:** `counts.rule_2b_size = counts.rule_2b_size - wordi + 1;`
* **Trick:** Replace multi-character operators with their keyword equivalents.
* `!=` (2 points) → `not_eq` (1 point). **Save 1.**
* `&&` (2 points) → `and` (1 point). **Save 1.**
* `||` (2 points) → `or` (1 point). **Save 1.**
* `^=` (2 points) → `xor_eq` (1 point). **Save 1.**
* `&=` (2 points) → `and_eq` (1 point). **Save 1.**
* `|=` (2 points) → `or_eq` (1 point). **Save 1.**

* *Note:* You may need to `#include <iso646.h>` or use compiler flags (`-fno-operator-names` usually disables them, but they are standard in C++ and available in C via header). If the `#include` costs too much (approx 15 points), define them yourself: `#define not_eq !=` (Cost ~15 points). Only worth it if you use these operators 15+ times.

### 4. Keyword Padding

Because all keywords count as 1 point, prefer verbose keywords over complex syntax if it saves token count.

### 5. Comments are NOT Free

Contrary to standard expectation, this tool **counts comments** in Rule 2b.

* **Source Logic:** When inside a comment (`is_comment` is true), the `IS_CODE` check fails, so keywords aren't detected, but the code falls through to `counts.rule_2b_size++` for every non-whitespace character.
* **Trick:** Delete all comments. `// a` costs 2 points (slashes) + 1 point (`a`) = 3 points.

### 6. Avoid `#define` for simple aliases

The tool explicitly **excludes** `#define` from the keyword list (see the comment `/* Yes Virginia, we left #define off the list on purpose! K&R */`).

* **Cost:** `#define` counts as 7 points (`#` + `define`).
* **Trick:** Do not use `#define` to alias single keywords (e.g., `#define R return`).
* `#define R return` costs ~10 points.
* `return;` (1 pt) vs `R;` (1 pt). You never make back the investment.
* Only use `#define` to replace long sequences of *symbols* or structures (e.g., `for(;;)` is 4 points, aliased to 1 point).

### Summary Checklist for Lower Score:

1. Python script to ensure spaces after `{;}`.
2. Replace `!=` with `not_eq`, `&&` with `and`, etc.
3. Remove all comments.
4. Use standard types/identifiers (1 point) rather than multi-word types (`unsigned long` = 2 points) where possible, unless using `typedef`.
5. Feel free to format strings with spaces.

### Keywords

All of these only score 1 point. (Note `#define` is not on this list!)

```c
#elif
#elifdef
#elifndef
#else
#embed
#endif
#error
#ident
#if
#ifdef
#ifndef
#include
#line
#pragma
#sccs
#warning
#undef

_Alignas
_Alignof
_Atomic
_BitInt
_Bool
_Complex
_Decimal128
_Decimal64
_Decimal32
_Generic
_Imaginary
_Noreturn
_Pragma
_Static_assert
_Thread_local

alignas
alignof
and
and_eq
auto
bitand
bitor
bool
break
case
char
compl
const
constexpr
continue
default
do
double
else
enum
extern
false
float
for
goto
if
inline
int
long
noreturn
not
not_eq
nullptr
or
or_eq
register
restrict
return
short
signed
sizeof
static
static_assert
struct
switch
thread_local
true
typedef
typeof
typeof_unequal
union
unsigned
void
volatile
while
xor
xor_eq
```

## Art

Gameboy is

- 376 pix wide
- 625 tall

Text is approx 2:1 aspect ratio so want something in the ratio w:h
376:625/2 = 1.2032:1

Leave 300 characters for #defines gives

4096 - 300 = 3796 chars

w * h = 3796

- 1.2032 * h**2 = 3796
- h = 56
- w = 68
- 56*68 = 3808 bytes

Have 3083 characters of source not including spaces.
Stencil has 3391 * characters and is 3823 chars in size.

## ROM Testing

- Original tetris - OK
- gbpi - OK (except for timer)
- pongus - OK

From https://github.com/flozz/gameboy-examples
- Licence WTFPL
- hello.gb - OK
- gamepad.gb - OK
- tictactoe.gb - OK
- breakout.gb - OK (no restart game button.)
- graphics1 - OK
- graphics2 - OK
- graphics3 - OK
- graphics4 - sprite handling not quite right (expected since sprite handing incomplete)
- graphics5 - works but no window (expected)
- graphics6 - works but no color (expected) 

https://github.com/flozz/evoland.gb
- Evoland GB
- a fan-made port of the Evoland game
- You are free to reproduce and distributes unmodified version of the Evoland.gb ROMs but for non-commercial purpose only.
- The assets (files in the gassets/ and src/gassets/ folders), the Evoland trademark and the Evoland logo are the property of Shiro Games studio, you are not allowed to reuse them in your own project or modified version of Evoland.gb.
- **Needs Window Support**

https://github.com/nitro2k01/whichboot.gb - OK but not a good demo

https://github.com/mattcurrie/which.gb - OK but not a good demo

https://github.com/jdeschena/Gameboj.git
- Has a nice collection of roms - not attributed though
- 2048.gb - http://sanqui.rustedlogic.net - Did not work...
- flappyboy.gb - @bitnenfer - Did not work :-(
- snake.gb - sanky - Did not work. Suspect interrupts.

https://github.com/msklywenn/GB-GameOfLife/
- BSD
- **WORKS!**
- gameoflife.gb

https://github.com/lancekindle/damaged-chip8/
- ?LICENSE
- Doesn't work

https://github.com/wyattferguson/2048-gb/
- **WORKS!**
- MIT
- 2048.gb

https://shenmansell.itch.io/simple-snake-gameboy
- NO Licence
- SimpleSnake.gb

Dr. Mario
- It is a 32KB ROM (no banking needed). It shares the same "falling blocks in a jar" static background logic as Tetris.
- **WORKS!** The viruses look a little weird but they dance!

Alleyway
- It is a Mario-themed *Breakout* clone. It is a 32KB launch title.
- **FAIL** Does not work - something weird with keyboard input

Motocross Maniacs
- It is a 32KB ROM.
- **FAIL** Doesn't work - blank screen

Boxxle
- A standard *Sokoban* box-pushing puzzle game. 32KB.
- **FAIL** Uses Window
