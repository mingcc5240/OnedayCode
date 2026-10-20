// GameBoy terminal emulator

/* the things we should be including if we didn't want so many warnings! */
/* #include <stdio.h> */
/* #include <stdint.h> */
/* #include <stdlib.h> */
/* #include <string.h> */
/* #include <unistd.h> */
#include <iso646.h>

// --- Defines ---

/* #define B reg[0] */
/* #define C reg[1] */
/* #define D reg[2] */
/* #define E reg[3] */
/* #define H reg[4] */
/* #define L reg[5] */
#define F reg[6]
#define A reg[7]

// HL alone. Used enough times to be worth keeping as a #define
#define HL RP(2,0)

// Flags: Z=0x80, N=0x40, H=0x20, C=0x10. Stored in F.
#define Z_FLAG (F&0x80)
/* #define N_FLAG (F&0x40) */
#define C_FLAG (F&0x10)

// Read 2 bytes from (r)
#define grd16(r) (tmp=rb(r++),tmp|rb(r++)<<8)

// Read 2 bytes from (pc)
#define rd16 grd16(pc)

// Config constants
//                        B,    C,    D,    E,    H,    L,    F,    A
#define INITIAL_REGS { 0x00, 0x13, 0x00, 0xD8, 0x01, 0x4D, 0xB0, 0x01 }
#define KEYS "dawskj \r"

// --- Types ---

typedef unsigned char u8;

// --- Hardware State ---
// Uninitialized vars will be zeroed
u8 ime, halt, ei, mem[1<<16],
    reg[] = INITIAL_REGS, // Registers in instruction encoding order (0=B, 1=C, 2=D, 3=E, 4=H, 5=L, 6=(HL), 7=A)
    buttons = 0xFF;       // Bits: Start,Select,B,A,Down,Up,Left,Right (1=Released, 0=Pressed)
unsigned short sp=-2, pc=0x0100, offset=-256, tmp;

// --- Memory Management ---
rb(a) {
    int r = mem[a]; // int avoids casting later
    // If address is Joypad (0xFF00), return calculated input, else return RAM.
    return a ^ 0xFF00 ? r :
           (r & 16 ? buttons >> 4 : buttons) & 15 | r & 0xF0;
}
wb(a, v) {
    if (a >> 15) // ROM Protection (Bit 15 must be 1)
        for (mem[a] = a ^ 0xFF44 ? v : 0,  // Write to MEM (Reset LY if 0xFF44)
             a = (a == 0xFF46) * 160;      // Set 'a' to 160 if DMA, else 0
             a--;)                         // Loop 160 times or 0 times
            mem[0xFE00 | a] = mem[v << 8 | a];
}

// --- Register Access ---

// Access 16-bit register pair by index (0:BC, 1:DE, 2:HL, 3:SP/AF)
RP(k,p){return k<3?reg[k*2]<<8|reg[k*2+1]:p?A<<8|F:sp;}
// k<3: Set BC/DE/HL. p=1: Set AF (mask F). p=0: Set SP.
SET_RP(k,v,p){ k<3 ? (reg[k*2]=v>>8,reg[k*2+1]=v) : p ? (A=v>>8,F=v&240) : (sp=v); }

// Access 8-bit registers by index (0=B, 1=C, 2=D, 3=E, 4=H, 5=L, 6=(HL), 7=A)
GET_REG(i) { return i^6 ? reg[i] : rb(HL); }
SET_REG(i,v) { i^6 ? reg[i]=v : wb(HL,v); }

// Set the flags from individual bits
SETF(z,n,c) { F=(z?0x80:0)|(n?0x40:0)|(c?0x10:0); }

#if DEBUG
#include <time.h>

// Floating point time
double now(){
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec/1E9;
}

writes(char *a){
    int c = strlen(a);
    while(c){
        int n = write(1, a, strlen(a));
        if (n > 0) {
                c -= n;
                a += n;
        }
    }
}
#endif /*DEBUG*/

// --- CPU Core Helpers ---

// Push 2 bytes onto the stack
push(v){ wb(--sp, v>>8); wb(--sp, v); }

// TETRIS OPTIMIZED ALU
// - Removed: Half-Carry (H) calculation.
// - Simplified: Carry (C) and Zero (Z) logic.
alu(o, v) {
    // c: Carry-in (only for ADC(1) and SBC(3))
    // e: Subtraction mode (SUB, SBC, CP)
    // h: Logic mode (AND, XOR, OR). 
    int c = (o & 1 and o < 4) * (F >> 4 & 1),
        e = o > 1,
        h = o & 4 and o ^ 7,
    
    // Calculate Result
        r = h ? (o & 1 ? A ^ v : o > 4 ? A | v : A & v) 
              : (e ? A - v - c : A + v + c);

    // Update Flags: Z (Zero), N (Subtract), H (ALWAYS 0), C (Carry)
    // We strictly assume H is not needed for core gameplay logic.
    F = (!(r & 255) << 7) |                    // Z
        ((!h and e) << 6) |                     // N
        (!h and (e ? r < 0 : r > 255)) << 4;    // C

    if (o ^ 7) A = r; // Write back if not CP (7)
}

cpu_step() {
    if(halt) { if(mem[0xFFFF] & mem[0xFF0F]) halt = 0; return; }
    if(ei) { ime = 1; ei = 0; } {

    u8 o = rb(pc++), x = o >> 6, y = o >> 3 & 7, z = o & 7, p = y >> 1, q = y & 1;
    int a, c, e, r, v, k[] = {!Z_FLAG, Z_FLAG, !C_FLAG, C_FLAG};

    switch(x) {
    case 0:
        switch(z) {
        case 0:
            if(y== 2 or !y) return;
            if(y== 1) { a = rd16; wb(a, sp); wb(a + 1, sp >> 8); return; }
            { e = (signed char)rb(pc++); if(y== 3 or k[y - 4]) pc += e; return; }
        case 1:
            if(!q) SET_RP(p, rd16, 0);
            else { SETF(Z_FLAG, 0, (r = HL + RP(p, 0)) > 0xFFFF); SET_RP(2, r, 0); }
            return;
        case 2:
            a = p > 1 ? HL : RP(p, 0);
            q ? (A = rb(a)) : wb(a, A);
            if(p > 1) SET_RP(2, HL + 5 - 2 * p, 0);
            return;
        case 3: SET_RP(p, RP(p, 0) + 1 - 2 * q, 0); return;
        case 4:
        case 5: o = GET_REG(y) + 9 - 2 * z; SET_REG(y, o); SETF(!o, z & 1, C_FLAG); return;
        case 6: SET_REG(y, rb(pc++)); return;
        default:
            if(y < 4) {
                // Unified Rotate/Shift
                // Calculate Carry Out (c)
                c = (y & 1 ? A : A >> 7) & 1;
                // Perform the Shift (Left or Right)
                A = y & 1 ? A >> 1 : A << 1;
                // OR in the "Fill" bit
                //    Fill is OldCarry if y>=2 (RLA/RRA), else c (RLCA/RRCA).
                //    Shift fill to bit 7 if Right (y is odd), else 0.
                A or_eq (y & 2 ? !!C_FLAG : c) << ((y & 1) * 7);
                SETF(0, 0, c);
            } else if(y== 4) { // DAA (Decimal Adjust) without temp 'a'
                // N_FLAG is set (Subtract Mode)
                if (F & 64) {
                    if (C_FLAG) A -= 96;
                }
                // N_FLAG is clear (Add Mode)
                else {
                    if (C_FLAG | A > 153) { A += 96; F or_eq 16; }
                    if ((A & 15) > 9) A += 6;
                }
                SETF(!A, F & 64, C_FLAG);
            } else if(y== 5) { // CPL (Complement)
                A = ~A;
                SETF(Z_FLAG, 1, C_FLAG);
            } else {
                // Merged SCF (6) and CCF (7)
                // If y=6 (SCF), new C is 1.
                // If y=7 (CCF), new C is !C.
                // y&1 is 0 for SCF, 1 for CCF.
                SETF(Z_FLAG, 0, y & 1 ? !C_FLAG : 1);
            }
            return;
        }

    case 1:
        if(o == 0x76) halt = 1; else SET_REG(y, GET_REG(z));
        return;

    case 2: alu(y, GET_REG(z)); return;

    default:
        switch(z) {
        case 0:
            if(y < 4) { if(k[y]) pc = grd16(sp); return; }
            if(y== 4) { wb(0xFF00 | rb(pc++), A); return; }
            if(y== 6) { A = rb(0xFF00 | rb(pc++)); return; }
            { e = (signed char)rb(pc++); r = sp + e; SETF(0, 0, (sp ^ e ^ r) & 0x100);
              if(y== 5) sp = r; else SET_RP(2, r, 0); return; }

        case 1:
            // POP (q=0)
            if(!q) { SET_RP(p, grd16(sp), 1); return; }

            // Jump/Load HL (p >= 2) -> No Stack Pop
            //    Check bit 1 (p & 2) to catch p=2 (JP HL) and p=3 (LD SP, HL).
            //    Distinguish between them using bit 0 (p & 1).
            if(p & 2) { p & 1 ? (sp = HL) : (pc = HL); return; }

            // Returns (p=0 RET, p=1 RETI) -> Stack Pop
            pc = grd16(sp);
            //    RETI (p=1) enables interrupts (ime=1). RET (p=0) preserves them.
            //    'ime |= p' handles both if p is exactly 0 or 1.
            ime or_eq p; 
            return;

        case 2:
            // Unified Address/Immediate Fetch
            // Covers Jumps (0-3) and Odd Memory Ops (5, 7) vs Even Ops (4, 6)
            a = (y < 4 or y & 1) ? rd16 : 0xFF00 | reg[1];

            // Execution Split
            if(y < 4) {
                // Conditional Jump
                if (k[y]) pc = a;
            } else {
                // Memory Ops: Bit 1 (values 6,7) means Read, else Write
                y & 2 ? (A = rb(a)) : wb(a, A);
            }
            return;

        case 3:
            if (!y) { a = rd16; pc = a; return; }
            if(y > 5) { y == 6 ? (ime = ei = 0) : (ei = 1); return; }
            
            // CB Prefix Processing
            o = rb(pc++); x = o >> 6; y = o >> 3 & 7; z = o & 7;
            v = r = GET_REG(z);

            if (x == 1) { SETF(!(v & (1 << y)), 0, C_FLAG); return; } // BIT
            if (x) r = x == 2 ? v & ~(1 << y) : v | 1 << y;           // RES, SET
            else { // Rotates & Shifts
                c = y not_eq 6 & v >> 7 * !(y & 1);
                r = y == 6 ? v << 4 | v >> 4 : (y & 1 ? v >> 1 : v << 1);
                
                // Rotates (0-3): Inject carry/wrap bit at pos 0 or 7
                if(y < 4) r or_eq (y & 2 ? !!C_FLAG : c) << (y & 1)*7;
                // SRA (5): Restore MSB
                if(y== 5) r or_eq v & 0x80;

                x = r;
                SETF(!x, 0, c);
            }
            SET_REG(z, r); return;

        case 4: // Conditional Call
            if(y < 4) { a = rd16; if(k[y]) { push(pc); pc = a; } }
            return;

        case 5: // PUSH / Unconditional CALL
            if(!q) push(RP(p, 1));
            else if(!p) { a = rd16; push(pc); pc = a; }
            return;

        case 6: // ALU Immediate
            alu(y, rb(pc++)); return;

        default /*case 7*/: // RST (Restart)
            push(pc); pc = y * 8; return;
        }
    }
    /*return; never executed */
}}

// --- PPU (returns palette index 0..3 encoded into ANSI terminal color) ---
// TETRIS OPTIMIZED PPU
// - Removed: Window Logic (Window is never used)
// - Removed: Sprite Flipping (Tetris rotates via software tile swaps)
// - Removed: Sprite Priority (Sprites are always on top)
// - Removed: 8x16 mode (Tetris uses 8x8 only)
// - Hardcoded Palette (Assume standard 0xE4 mapping)
get_pixel_idx(x, y) {
    int e = mem[0xFF40], c = 0, p, q, h, k = 0;
    u8 *o;
    
    // Background Layer
    if (e & 1) {
        o = mem + 0xFF42;
        p = x + o[1]; 
        q = y + *o;
        h = mem[0x9800 + (q / 8 & 31) * 32 + (p / 8 & 31)];
        o = mem + (e & 16 ? 0x8 : 0x9)*4096 + (e & 16 ? h : (signed char)h) * 16 + (q & 7) * 2;
        
        // DIRECT ASSIGNMENT: No palette lookup
        c = (*o >> (7 - (p & 7)) & 1) | (o[1] >> (7 - (p & 7)) & 1) * 2;
    }

    // Sprite Layer
    if (e & 2) for (; k < 40; k++) {
        o = mem + 0xFE00 + k * 4;
        q = y - *o + 16;
        p = x - o[1] + 8;
        if ((unsigned)q < 8 and (unsigned)p < 8) {
            o = mem + 0x8000 + o[2] * 16 + q * 2;
            h = (*o >> (7 - p) & 1) | (o[1] >> (7 - p) & 1) * 2;
            
            // DIRECT ASSIGNMENT: If opaque (t!=0), overwrite c
            if (h) c = h; 
        }
    }
    // Return ANSI terminal color directly
    return 255-7*(e & 128 ? c : 0);
}

/*
// --- Terminal renderer: 160x144 pixels using kitty graphics protocol
void render_terminal_frame() {
    char b[700], *p;
    int x, y = 0;
    writes("\x1b[H"); // Home cursor
    for (; y < 144; y++) {
        // Build header. First line adds metadata. Last line sets m=0.
        p = b + sprintf(b, "\x1b_G%sm=%d;", y ? "" : "a=T,f=24,s=160,v=144,c=80,r=36,", y < 143);
        
        // Copy 4-byte chunks from string literal LUT directly to buffer
        for (x = 0; x < 160; x++)
            *(int*)p = ((int*)"////qqqqVVVVAAAA")[get_pixel_idx(x, y)], p += 4;
            
        // Append ST (\x1b\) and null terminate
        *p++ = 27; *p++ = 92; *p = 0;
        writes(b);
    }
}
*/

main() {
    static u8 d[9];
    u8 *a = mem + 0xFF44, c;
    char *k = KEYS, *x, *e, frame[1<<20];
    int p = 0, q = 0, f, g;
#if DEBUG
    double start_render = now();
    double fps = 0.0;
#endif /*DEBUG*/

    // Setup: Read ROM (fd 3), Joypad, LCDC, IE
    read(3, mem, 32768);
    mem[0xFF00] = 0xCF; a[-4] = 0x91; a[187] = 1;

    for (;;) {
        cpu_step();
        mem[0xFF04]++;
        p += 8;

        // PPU: Scanline & Frame Logic
        for (; p >= 456; p -= 456)
            ++*a == 144 ? mem[0xFF0F] or_eq 1, q = 0 : *a > 153 ? *a = q = 0 : 0;

        // VBlank: Input, Render, Throttle
        if (*a == 144 and !q) {
            q = 1;
            
            // Input: Read non-blocking, update decay 'd', set global 'buttons'
            while (read(0, &c, 1) > 0) x = strchr(k, c), x ? d[x - k] = 9 : 0;
            for (buttons = 255, f = 0; f < 8; f++) d[f] ? d[f]--, buttons xor_eq 1 << f : 0;

            // Render: 160x144 pixels -> 160x72 chars (upper/lower half block)
            for (e = strcpy(frame, "\x1b[H") + 3, f = 0; f < 144; *e++ = 10, f += 2)
                for (g = 0; g < 160; g++)
                    e += sprintf(e, "\x1b[38;5;%dm\x1b[48;5;%dm▀", get_pixel_idx(g, f), get_pixel_idx(g, f + 1));
            
            write(1, frame, e - frame);

#if DEBUG
            // If DEBUG is set then write CPU state and FPS
            double end_render = now();
            double new_fps = 1/(end_render-start_render);
            start_render = end_render;
            char buf[256];
            fps = 0.95*fps + 0.05*new_fps;
            sprintf(buf, "\033[0m\nCPU pc=%04X op=%02X ime=%d ei=%d halt=%d IF=%02X IE=%02X fps=%.1f \n",
                    pc, rb(pc), ime, ei, halt, mem[0xFF0F], mem[0xFFFF], fps);
            writes(buf);
#endif /*DEBUG*/

            // 60 Hz frame rate is 16666 uS. We allow a 2.6 mS for CPU Emulation
            // which makes 60 fps on the Author's Computer. If in the distant
            // future CPUs get infinitely fast then this will run at 71.4 fps
            // which is within the acceptable bounds.
            usleep(14000);
        }

        // Interrupt Dispatch: VBlank (Bit 0)
        ime and (mem[0xFFFF] & mem[0xFF0F] & 1) ? ime = 0, mem[0xFF0F] and_eq ~1, push(pc), pc = 0x40 : 0;
    }
}
