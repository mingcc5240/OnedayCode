#  The "Tetris-Optimized" Terminal Game Boy Emulator

This is my third IOCCC 29 (2026) entry.

Look at [remarks.md](./remarks.md) for instructions.

Check the  source code out [prog.c](./prog.c). That should give you a bit hint as to what it does!

Here is what the output should look like:

<img alt="2048" src="./screenshots/2048.png" width="250"> <img alt="Breakout" src="./screenshots/breakout.png" width="250"> <img alt="Game of Life" src="./screenshots/gameoflife.png" width="250"> <img alt="Pi" src="./screenshots/pi.png" width="250"> <img alt="Test" src="./screenshots/test.png" width="250"> <img alt="Tetris" src="./screenshots/tetris.png" width="250"> <img alt="Tic Tac Toe" src="./screenshots/tictactoe.png" width="250"> <img alt="Oxo3d" src="./screenshots/oxo3d.png" width="250"> <img alt="Game Boy Chess" src="./screenshots/gbchess.png" width="250">

Things to look at:
- [gb.c](./gb.c) for the source. I hesitate to say it is unobfuscated, but it is easier to read than `prog.c`!
- [crunch.py](./crunch.py) and [shape_code.py](./shape_code.py) to see how `prog.c` was generated.
- [test_rom](./test_rom/) for the source of the `Test.gb` ROM.
- [oxo3d](https://github.com/ncw/gameboy-oxo3d) for the source of the 3d tic-tac-toe ROM.
- [gbchess](https://github.com/ncw/gbchess) for the source of the chess ROM.
- [gbpi](https://github.com/ncw/gbpi) for the source of the pi generating ROM.

The rest of the repo is how it was made if you are interested - more info (scrappy) in [NOTES.md](./NOTES.md)

