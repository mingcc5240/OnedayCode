; ==================================================================================
;  Minimalist GB Emulator Test Suite
;  - Complete Feature Set:
;    D-PAD: Move Face | A/B: Scroll | START: Pause Ball | SELECT: Reset Ball
; ==================================================================================

; --- Hardware Constants ---
DEF rP1     EQU $FF00
DEF rDIV    EQU $FF04
DEF rIF     EQU $FF0F
DEF rLCDC   EQU $FF40
DEF rSTAT   EQU $FF41
DEF rSCY    EQU $FF42
DEF rSCX    EQU $FF43
DEF rLY     EQU $FF44
DEF rDMA    EQU $FF46
DEF rBGP    EQU $FF47
DEF rOBP0   EQU $FF48
DEF rOBP1   EQU $FF49
DEF rIE     EQU $FFFF

DEF _RAM    EQU $C000
DEF _STACK  EQU $DFFF
DEF _ShadowOAM EQU $C000
DEF _HRAM_DMA  EQU $FF80

; --- Bit Definitions ---
DEF BIT_A      EQU 0
DEF BIT_B      EQU 1
DEF BIT_SELECT EQU 2
DEF BIT_START  EQU 3
DEF BIT_RIGHT  EQU 4
DEF BIT_LEFT   EQU 5
DEF BIT_UP     EQU 6
DEF BIT_DOWN   EQU 7

; --- Variables ---
SECTION "Vars", WRAM0[_RAM + $00A0]
vblank_flag: db
joypad:      db
last_joypad: db ; Used to detect "New Presses" vs "Held"
frame_count: db

; Ball Physics
ball_y:      db
ball_x:      db
ball_dy:     db
ball_dx:     db
pause_flag:  db ; 0 = Moving, 1 = Paused

; ==================================================================================
;  Vectors
; ==================================================================================
SECTION "Vectors", ROM0[$0000]
    ret
    DS 7
    ret
    DS 7
    ret
    DS 7
    ret
    DS 7
    ret
    DS 7
    ret
    DS 7
    ret
    DS 7
    ret
    DS $40 - @

    ; $0040: V-Blank
    push af
    ld a, 1
    ld [vblank_flag], a
    pop af
    reti

    DS $100 - @

; ==================================================================================
;  Header
; ==================================================================================
SECTION "Header", ROM0[$0100]
    nop
    jp Start
    DS $150 - @, 0

; ==================================================================================
;  Main Program
; ==================================================================================
SECTION "Main", ROM0[$0150]

Start:
    di
    ld sp, _STACK

    ; Safety Clears
    xor a
    ld [rIE], a
    ld [rIF], a
    ld [rLCDC], a

    ; Copy DMA Routine to HRAM
    ld hl, DMARoutine
    ld de, _HRAM_DMA
    ld c, DMARoutineEnd - DMARoutine
.copyDMA
    ld a, [hl+]
    ld [de], a
    inc de
    dec c
    jr nz, .copyDMA

    ; Setup Palette
    ld a, %11100100
    ld [rBGP], a
    ld [rOBP0], a

    ; Load Tiles
    ld hl, $8000
    ld de, TileData
    call LoadTiles

    ; Clear Tilemap
    ld hl, $9800
    ld bc, 1024
    ld a, 0
    call FillMem

    ; Clear Shadow OAM
    ld hl, _ShadowOAM
    ld b, 160
    xor a
.clearOAM
    ld [hl+], a
    dec b
    jr nz, .clearOAM

    ; Draw Border
    ld hl, $9800 ; TL
    ld a, 1
    ld [hl], a
    ld hl, $9813 ; TR
    ld [hl], a
    ld hl, $9A20 ; BL
    ld [hl], a
    ld hl, $9A33 ; BR
    ld [hl], a

    ; Initialize Variables
    ld a, 80
    ld [_ShadowOAM], a
    ld a, 88
    ld [_ShadowOAM+1], a
    ld a, 2
    ld [_ShadowOAM+2], a
    ld a, 0
    ld [_ShadowOAM+3], a

    ld a, 40
    ld [ball_y], a
    ld a, 30
    ld [ball_x], a
    ld a, 1
    ld [ball_dx], a
    ld [ball_dy], a

    xor a
    ld [pause_flag], a
    ld [last_joypad], a

    ; Enable LCD
    ld a, %00000001
    ld [rIE], a
    ld a, %10010011
    ld [rLCDC], a
    ei

; ==================================================================================
;  Game Loop
; ==================================================================================
MainLoop:
    ; Wait for VBlank
.waitVBlank
    ld a, [vblank_flag]
    and a
    jr z, .waitVBlank
    xor a
    ld [vblank_flag], a

    ; Read Input
    call ReadJoypad

    ; --- INPUT EDGE DETECTION ---
    ; Calculate which keys were pressed *just this frame*
    ; Pressed = Current AND (NOT Last)
    ld a, [joypad]
    ld b, a           ; B = Current
    ld a, [last_joypad]
    cpl               ; Invert Last
    and b             ; A = Just Pressed
    ld c, a           ; C = Just Pressed Keys

    ; Save current to last for next frame
    ld a, b
    ld [last_joypad], a

    ; --- HANDLE START (Pause) ---
    bit BIT_START, c  ; Check "Just Pressed"
    jr z, .noStart
    ld a, [pause_flag]
    xor 1             ; Toggle 0 <-> 1
    ld [pause_flag], a
.noStart

    ; --- HANDLE SELECT (Reset Ball) ---
    bit BIT_SELECT, c
    jr z, .noSelect
    ld a, 40
    ld [ball_y], a
    ld a, 30
    ld [ball_x], a
    ; Reset speed too just in case
    ld a, 1
    ld [ball_dx], a
    ld [ball_dy], a
.noSelect

    ; Player Movement (D-PAD Held)
    ld hl, _ShadowOAM
    ld a, [joypad]

    bit BIT_UP, a
    jr z, .noUp
    dec [hl]
.noUp
    bit BIT_DOWN, a
    jr z, .noDown
    inc [hl]
.noDown
    inc hl
    bit BIT_LEFT, a
    jr z, .noLeft
    dec [hl]
.noLeft
    bit BIT_RIGHT, a
    jr z, .noRight
    inc [hl]
.noRight

    ; Ball Logic (Only update if not paused)
    ld a, [pause_flag]
    and a
    call z, UpdateBall  ; Call if Zero (Not Paused)

    ; Scroll Logic (A/B Held)
    ld a, [joypad]
    bit BIT_A, a
    jr z, .chkLeft
    ld a, [rSCX]
    inc a
    ld [rSCX], a
    jr .scrollDone
.chkLeft
    bit BIT_B, a
    jr z, .scrollDone
    ld a, [rSCX]
    dec a
    ld [rSCX], a
.scrollDone

    ; Draw Timer
    ld hl, $9806
    ld a, [rDIV]
    ld b, a
    call PlotBinary

    ; Draw frame count
    ld hl, $9806+32*17
    ld a, [frame_count]
    inc a
    ld [frame_count], a
    ld b, a
    call PlotBinary

    ; HRAM DMA
    di
    ld a, HIGH(_ShadowOAM)
    call _HRAM_DMA
    ei

    jp MainLoop

; ==================================================================================
;  Subroutines
; ==================================================================================

; Plot B at HL in binary
PlotBinary:
    ld a, [pause_flag]
    and a
    ret nz
    ld c, 8
.plotLoop
    rlc b
    jr c, .plotOne
    ld a, 4
    jr .plotDone
.plotOne
    ld a, 5
.plotDone
    ld [hl+], a
    dec c
    jr nz, .plotLoop
    ret

UpdateBall:
    ; Move X
    ld a, [ball_x]
    ld b, a
    ld a, [ball_dx]
    add b
    ld [ball_x], a

    ; Check X Bounds (8 to 160)
    cp 8
    jr c, .flipX
    cp 160
    jr nc, .flipX
    jr .checkY

.flipX
    ld a, [ball_dx]
    cpl
    inc a
    ld [ball_dx], a
    ld a, [ball_x]
    cp 8
    jr nc, .fixRight
    ld a, 8
    ld [ball_x], a
    jr .checkY
.fixRight
    ld a, 160
    ld [ball_x], a

.checkY
    ; Move Y
    ld a, [ball_y]
    ld b, a
    ld a, [ball_dy]
    add b
    ld [ball_y], a

    ; Check Y Bounds (16 to 152)
    cp 16
    jr c, .flipY
    cp 152
    jr nc, .flipY
    jr .checkCollision

.flipY
    ld a, [ball_dy]
    cpl
    inc a
    ld [ball_dy], a
    ld a, [ball_y]
    cp 16
    jr nc, .fixBottom
    ld a, 16
    ld [ball_y], a
    jr .checkCollision
.fixBottom
    ld a, 152
    ld [ball_y], a

.checkCollision
    ; Collision with Player
    ld a, [ball_x]
    ld b, a
    ld a, [_ShadowOAM+1] ; Player X
    sub b
    bit 7, a
    jr z, .posX
    cpl
    inc a
.posX
    cp 8
    ret nc

    ld a, [ball_y]
    ld b, a
    ld a, [_ShadowOAM]   ; Player Y
    sub b
    bit 7, a
    jr z, .posY
    cpl
    inc a
.posY
    cp 8
    ret nc

    ; COLLISION -> Bounce
    ld a, [ball_dx]
    cpl
    inc a
    ld [ball_dx], a
    ld a, [ball_dy]
    cpl
    inc a
    ld [ball_dy], a
    ret

DMARoutine:
    ld [rDMA], a
    ld a, 40
.wait
    dec a
    jr nz, .wait
    ret
DMARoutineEnd:

ReadJoypad:
    ld a, %00100000
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    cpl
    and $0F
    swap a
    ld b, a
    ld a, %00010000
    ld [rP1], a
    ld a, [rP1]
    ld a, [rP1]
    ld a, [rP1]
    cpl
    and $0F
    or b
    ld [joypad], a
    ld a, $30
    ld [rP1], a

    ; Update Ball Sprite in OAM
    ld a, [ball_y]
    ld [_ShadowOAM+4], a
    ld a, [ball_x]
    ld [_ShadowOAM+5], a
    ld a, 3                ; Tile 3
    ld [_ShadowOAM+6], a
    ld a, 0                ; Pal 0
    ld [_ShadowOAM+7], a
    ret

LoadTiles:
    ld c, 16 * 6
.loop
    ld a, [de]
    inc de
    ld [hl+], a
    dec c
    jr nz, .loop
    ret

FillMem:
    ld d, a
.loop
    ld a, d
    ld [hl+], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    ret

; ==================================================================================
;  Graphics Data
; ==================================================================================
TileData:
    ; Background (0)
    DB %00000000, %00000000
    DB %00000000, %00000000
    DB %00000000, %00000000
    DB %00010000, %00000000
    DB %00000000, %00000000
    DB %00000000, %00000000
    DB %00000000, %00000000
    DB %00000000, %00000000
    ; Square (1)
    DB %11111111, %11111111
    DB %10000001, %10000001
    DB %10000001, %10000001
    DB %10000001, %10000001
    DB %10000001, %10000001
    DB %10000001, %10000001
    DB %10000001, %10000001
    DB %11111111, %11111111
    ; Smiley (2)
    DB %00111100, %00111100
    DB %01000010, %01000010
    DB %10100101, %10100101
    DB %10000001, %10000001
    DB %10100101, %10100101
    DB %10011001, %10011001
    DB %01000010, %01000010
    DB %00111100, %00111100
    ; Ball (3)
    DB %00000000, %00111100
    DB %00100000, %01000010
    DB %00010000, %10000001
    DB %00011000, %10000001
    DB %00011000, %10000001
    DB %00001000, %10000001
    DB %00000100, %01000010
    DB %00000000, %00111100
    ;0 (4)
    DB %01111110, %00000000
    DB %11111111, %00000000
    DB %11111111, %00111000
    DB %11111111, %00101000
    DB %11111111, %00101000
    DB %11111111, %00111000
    DB %11111111, %00000000
    DB %01111110, %00000000
    ;1 (5)
    DB %01111110, %00000000
    DB %11111111, %00000000
    DB %11111111, %00010000
    DB %11111111, %00110000
    DB %11111111, %00010000
    DB %11111111, %00111000
    DB %11111111, %00000000
    DB %01111110, %00000000
