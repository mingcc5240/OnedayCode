### The "Tetris-Optimized" Terminal Game Boy Emulator

A Game Boy DMG emulator that fits in your pocket, assuming your pocket contains an ANSI-compliant terminal and a C compiler.

Requirements:
- needs POSIX `usleep`, `read`, `write` (Linux, macOS, WSL should do)
- a terminal with UTF-8 Support with Block Elements
- a terminal that has xterm-256color Support (ANSI 8-bit Color)
- a terminal window set to at minimum 160x72
- A monospaced font with **zero line spacing**. If your terminal adds padding between lines, your Game Boy screen will look like it's viewed through Venetian blinds.
- Optional: `curl` if you wish to download open source ROMs to run.

Build and run with:

```sh
./try.sh
```

#### How to Use

If you have a copy of the original 32K ROM files for *Tetris* or *Dr. Mario* then place them in the `roms/` folder with file extension `.gb`.

Run `./try.sh`. 

It will ask you if you wish to download some open source homebrew ROMs for your immediate enjoyment. It will then scan the `roms/` folder and serve up a menu of your available games. Use the arrow keys to select then press RETURN to run one.

You can also run individual ROMs like this `./try.sh roms/Test.gb`.

Game Boy Controls:
- `w`/`a`/`s`/`d`: D-Pad
- `j`: B button
- `k`: A button
- `SPACE`: Select
- `RETURN`: Start
- `CTRL-C`: Exit

Now go find some AA batteries and party like it's 1989!

#### Games

The following games have been tested with the emulator:

| Game        | Author         | Status       | License      | Homepage |
|-------------|----------------|--------------|--------------|----------|
| TicTacToe   | Fabien LOISON  | Downloadable | WTFPL        | https://github.com/flozz/gameboy-examples |
| Breakout    | Fabien LOISON  | Downloadable | WTFPL        | https://github.com/flozz/gameboy-examples |
| GameOfLife  | Daniel Borges  | Downloadable | BSD-3        | https://github.com/msklywenn/GB-GameOfLife/ |
| 2048        | Wyatt Ferguson | Downloadable | MIT          | https://github.com/wyattferguson/2048-gb/ |
| SimpleSnake | Shen Mansell   | Not Included | Unknown      | https://shenmansell.itch.io/simple-snake-gameboy |
| Test        | The Author     | Included     | CC BY-SA 4.0 | TBA |
| Oxo3d       | The Author     | Included     | CC BY-SA 4.0 | TBA |
| GBChess     | The Author     | Included     | CC BY-SA 4.0 | TBA |
| Pi          | The Author     | Included     | CC BY-SA 4.0 | TBA |
| Tetris      | Nintendo       | Not Included | Commercial   | https://en.wikipedia.org/wiki/Tetris_(Game_Boy_video_game) |
| Dr. Mario   | Nintendo       | Not Included | Commercial   | https://en.wikipedia.org/wiki/Dr._Mario |

Games marked "Downloadable" are optionally fetched by `./try.sh`. The "Not Included" games you will have to source for yourself.

`Test.Gb` is a bespoke test ROM written by The Author and Gemini Pro 3 in assembler designed specifically to exercise this emulator. It gives the video, input, and DMA logic a good workout. Features include binary timer displays, a `D-PAD` controllable smiley face, and a physics-enabled bouncing ball that pauses with `START` and resets with `SELECT`. Use `A` and `B` to scroll the screen.

`Oxo3d.gb` is a game written by The Author in C to play 3D Tic Tac Toe. You're O and you have to get 4 in a row. The board is a cube viewed in slices. To see a different view of the cube press `B`. Watch out for tricky diagonal lines! It has 3 levels, `Easy` for getting started, `Medium` once you've learned how to play and `Hard` for when you just want to be crushed every game. `D-PAD` moves the cursor, `A` places your piece, `B` rotates the view, `SELECT` sets the level and `START` makes a new game.

`GBChess.gb` is a chess game written by The Author and Gemini Pro 3 in C. See the in game help for how to play. On the top setting it plays at ELO 1325 in 30-60s. The Author can beat it on the bottom level only!

`Pi.gb` is a "game" handcrafted by The Author. It features 500 levels of excitement - if by "levels" you mean "digits of π calculated via an assembler-coded Rabinowitz and Wagon Spigot Algorithm." This ROM is included solely because The Author's game design skills are very poor; It turns out calculating irrational numbers is significantly easier than making a sprite jump without getting stuck in the floor.

#### Makefile configuration

Some features of the emulator may be configured in the Makefile:

- **`-DK='"dawskj \r"'`**: This defines the **Keyboard Input Matrix**. While lesser emulators hardcode their keybinds, we allow you to redefine the physical reality of your keyboard at compile time. Keys are in the order `Right`, `Left`, `Up`, `Down`, `A`, `B`, `Select`, `Start`

- **`-DR='{ 0,19,0,216,1,77,176,1 }'`**: This sets the **Register Initialization**. It configures the CPU registers to simulate having run the Game Boy boot ROM. Changing these values allows you to emulate different boot ROM versions. Registers are in the order: `B`, `C`, `D`, `E`, `H`, `L`, `F`, `A`.
 
- **`-DC='I(F++)'`**: This flag controls the **Non-User-Serviceable Part** of the Game Boy emulator. Tampering with this value strictly voids the warranty you never had.

#### "Features" & Design Philosophy

We engaged in a rigorous profiling process to determine which hardware features were essential. The methodology was simple: "Does Tetris need this to run?"

- **Half-Carry Flag:** Deleted. We assume BCD math is a myth.
- **Window Layer:** Windows are for houses, not Game Boys.
- **Sprite Flipping:** Tetris blocks are symmetrical (mostly). Who needs flipping?
- **Audio:** In space, no one can hear you clear four lines at once.

#### Obfuscation Details

We didn't just smash keys until it compiled; we smashed keys until it compiled *weirdly*.

##### The "Python" Transformation (`iso646.h`)

We included `<iso646.h>` not because we care about digraphs or 7-bit character sets, but because `or`, `and`, and `not_eq` look unsettlingly readable in C . The goal was to make the source code resemble a Python script that was tragically forced to manage its own memory. It creates a cognitive dissonance where the code *looks* like high-level pseudocode but behaves like pointer arithmetic soup.

##### The File Descriptor 3 Trick

You won't find `fopen`, `fclose`, or `argv` parsing here. Why waste bytes on file handling when the shell can do it for you? The emulator blindly reads from **File Descriptor 3**, assuming you (or the `try.sh` script) have already piped a ROM into it. If you run it without redirection it does absolutely nothing and leaves you wondering why you expected error handling in 2 kilobytes.

##### The "One-Liner" ALU

The Game Boy CPU (an 8080/Z80 hybrid) has dozens of arithmetic operations. We have *one*. By abusing the fact that boolean operators in C return exactly `0` or `1`, we collapsed the carry logic for shifts, rotates, and carry-flag calculations into a single, terrifying expression:

```c
c = y != 6 & v >> 7 * !(y & 1);
```

Better hope you've memorised the C operator precedence chart!

##### Variable Type Roulette

We use `int` for everything, except when we use `unsigned char` to implicitly truncate values via overflow. We call this "hardware emulation via undefined behavior."

#### Known "Issues" (Features)

- **Timing:** The CPU runs as fast as `usleep()` allows. Accuracy is bounded by your OS scheduler's mood.
- **Compatibility:** This is strictly a *Tetris* and *Dr. Mario* machine. If you try to run *Pokémon Red*, the emulator will likely Halt and Catch Fire (HCF).
- **Input:** Uses raw stdin to simulate a "sticky buttons" experience. Each keystroke triggers a non-negotiable 150ms hold. If the game ignores you, mash harder - just like a real Game Boy covered in jam.
- **Sound:** The only sound it makes is the whirring of your cooling fans as `main()` runs its infinite loop.

#### Acknowledgments

- To the [gbdev Game Boy documentation](https://gbdev.io/pandocs/) for documenting the undocumented.
- To the C preprocessor, for enabling my life long addiction to `#define`.
- To `git bisect`, for finding the exact commit where I broke the HALT instruction.
- To Gemini 3 Pro, for its ruthless code golfing suggestions and for possessing a disturbingly specific knowledge of Game Boy hardware internals.
