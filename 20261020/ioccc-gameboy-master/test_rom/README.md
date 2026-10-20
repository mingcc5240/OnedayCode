# Test ROM

This is a bespoke test ROM written by The Author and Gemini Pro 3 specifically for this cut down emulator.

**Features include:**

- **The Binary Bars of Truth:** A flickering row of blocks at the top and bottom of the screen that proves the Timer is ticking (and that you can do math in binary).
- **The Smiley of Destiny:** A controllable sprite that tests the D-Pad and OAM DMA logic.
- **The Ball of Chaos:** A bouncing ball with collision detection that ruthlessly hunts the Smiley. Use **START** to freeze time (pause) and **SELECT** to banish it back to its starting coordinates when it inevitably corners you.
- **Scroll-o-Vision:** Press **A** or **B** to slide the entire world left and right, proving that `SCX` registers actually do something.

## Technical Details

The ROM relies on a subset of the hardware and allows for "instant" timing behaviors while still functioning correctly on cycle-accurate emulators.

### Memory Map & Constraints

- **ROM:** Flat 32KB (No MBC).
- **RAM:** Uses WRAM (Bank 0) at `$C000`.
- **Stack:** Initialized at `$DFFF`.
- **HRAM:** Uses `$FF80` for the OAM DMA transfer routine.

### Hardware Registers Exercised

| Register | Address | Function in ROM |
| --- | --- | --- |
| `P1` | `$FF00` | Written to select D-Pad/Buttons; read to poll input state. |
| `DIV` | `$FF04` | Read every frame to render the binary counter at the top of the screen. |
| `IF` | `$FF0F` | Written to `0` during initialization to clear pending interrupts. |
| `LCDC` | `$FF40` | Configured to `$93` (LCD On, BG On, OBJ On, BG Map `$9800`, Tile Data `$8000`). |
| `SCX` | `$FF43` | Incremented/Decremented by `A` and `B` buttons to test background scrolling. |
| `DMA` | `$FF46` | Written to trigger the OAM Transfer from `$C000` to `$FE00`. |
| `BGP` | `$FF47` | Set to `%11100100` (Standard Grey Palette). |
| `OBP0` | `$FF48` | Set to `%11100100` (Standard Sprite Palette). |
| `IE` | `$FFFF` | Set to `$01` to enable VBlank interrupts only. |

### Critical Behaviors

**VBlank Interrupt:** The ROM relies on the VBlank interrupt (`INT 40h`) to throttle the main loop. If your emulator does not fire this interrupt (or does not handle `EI`/`RETI` logic), the ROM will hang at the startup screen.

**OAM DMA (`$FF46`):**
- The ROM executes the DMA trigger from **HRAM (`$FF80`)**.
- This ensures compatibility with both "Instant DMA" emulators (like this one) and accurate emulators (Emulicious/BGB) that lock the bus during transfer.
- **Note for Developers:** If the sprites (Smile/Ball) do not move, check your DMA logic.

**Input Handling:**
- **START:** Implements a "rising edge" check (toggles Pause state once per press).
- **SELECT:** Implements a state reset.
- **A/B/D-Pad:** Standard continuous polling.

### Intentionally Unused Features

- **Timer Interrupts:** The Timer (`TAC`) is ignored; the ROM only reads the raw `DIV` register.
- **LCD STAT Interrupts:** No HBlank/VBlank STAT interrupts are enabled.
- **Window Layer:** The Window layer is not used.
- **Sound:** No APU registers are touched.
