#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <mmsystem.h> // timeBeginPeriod 사용 (-lwinmm 링크)


// Win32 GDI 및 고정밀 타이머 전역 변수
HWND hwnd;
HDC hdc_win, hdc_mem, hdc_stretch;
HBITMAP hbm_dib, hbm_stretch;
uint16_t* dib_pixels;

LARGE_INTEGER qpc_freq, next_frame_tick, fps_last_tick;
double ticks_per_frame;
int fps_frame_count = 0;

// 타이머 초기화 함수 (main 함수 시작 시 1회 호출)
void init_timing(void) {
    timeBeginPeriod(1); // Windows Sleep() 해상도를 1ms로 설정
    QueryPerformanceFrequency(&qpc_freq);
    // NTSC NES 정확 프레임 레이트: 60.0988138974405 Hz
    ticks_per_frame = (double)qpc_freq.QuadPart / 60.0988139;
    QueryPerformanceCounter(&next_frame_tick);
    fps_last_tick = next_frame_tick; // FPS 측정 시작 시각 초기화
}

// 화면 출력 및 정밀 60FPS 동기화 함수 (scany == 241 에서 호출)
int render_and_sync_frame(uint16_t* fb) {
    // 1. 상하단 8픽셀을 제외한 픽셀 데이터(256x224)를 DIBSection에 복사 후 출력
    memcpy(dib_pixels, fb + 2048, 256 * 224 * sizeof(uint16_t));
    StretchBlt(hdc_stretch, 0, 0, 1024, 840, hdc_mem, 0, 0, 256, 224, SRCCOPY);
    BitBlt(hdc_win, 0, 0, 1024, 840, hdc_stretch, 0, 0, SRCCOPY);

    // 2. 윈도우 메시지 처리
    MSG msg;
    while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
        if (msg.message == WM_QUIT)
            return 0; // 종료 신호
        TranslateMessage(&msg);
        DispatchMessageA(&msg);
    }

    // 3. 하이브리드 60FPS 타이밍 제어 (Sleep + Spin-wait)
    LARGE_INTEGER now;
    QueryPerformanceCounter(&now);

    // 다음 프레임 목표 시간 설정
    next_frame_tick.QuadPart += (LONGLONG)ticks_per_frame;

    // 창 이동 등으로 프레임이 너무 밀렸다면(3프레임 이상 지연) 현재 시간으로 리셋
    if (now.QuadPart > next_frame_tick.QuadPart + (LONGLONG)(ticks_per_frame * 3)) {
        next_frame_tick = now;
    }

    // 목표 시간까지 대기
    while (1) {
        QueryPerformanceCounter(&now);
        LONGLONG remain = next_frame_tick.QuadPart - now.QuadPart;
        if (remain <= 0)
            break;

        double remain_ms = (double)remain * 1000.0 / (double)qpc_freq.QuadPart;
        if (remain_ms > 2.0) {
            Sleep(1);
        }
        else {
            YieldProcessor();
        }
    }

    // 4. 1초(1000ms)마다 실시간 FPS 계산 및 타이틀바 갱신
    static DWORD fps_last_ms = 0;
    static int fps_frames = 0;

    fps_frames++;
    DWORD cur_ms = GetTickCount();
    if (fps_last_ms == 0) {
        fps_last_ms = cur_ms;
    }
    else if (cur_ms - fps_last_ms >= 1000) {
        DWORD dt = cur_ms - fps_last_ms;
        // 소수점 둘째 자리까지 정수로 계산 (예: 60.10 -> 6010)
        int fps_x100 = (fps_frames * 100000 + (dt / 2)) / dt;

        char title[64];
        wsprintfA(title, "smolnes (Win32 GDI) - %d.%02d FPS", fps_x100 / 100, fps_x100 % 100);
        SetWindowTextA(hwnd, title);

        fps_frames = 0;
        fps_last_ms = cur_ms;
    }

    return 1;
}
#define PULL mem(++S, 1, 0, 0)
#define PUSH(x) mem(S--, 1, x, 1)

uint8_t* rom, * chrrom,                // Points to the start of PRG/CHR ROM
prg[4], chr[8],                   // Current PRG/CHR banks
prgbits = 14, chrbits = 12,       // Number of bits per PRG/CHR bank
A, X, Y, P = 4, S = ~2, PC_H, PCL, // CPU Registers
addr_lo, addr_hi,                 // Current instruction address
nomem,  // 1 => current instruction doesn't write to memory
result, // Temp variable
val,    // Current instruction value
cross,  // 1 => page crossing occurred
tmp,    // Temp variables
ppumask, ppuctrl, ppustatus, // PPU registers
ppubuf,                      // PPU buffered reads
W,                           // Write toggle PPU register
fine_x,                      // X fine scroll offset, 0..7
opcode,                      // Current instruction opcode
nmi_irq,                     // 1 => IRQ occurred
// 4 => NMI occurred
ntb,                         // Nametable byte
ptb_lo,                      // Pattern table lowbyte
vram[2048],                  // Nametable RAM
palette_ram[64],             // Palette RAM
ram[8192],                   // CPU RAM
chrram[8192],                // CHR RAM (only used for some games)
prgram[8192],                // PRG RAM (only used for some games)
oam[256],                    // Object Attribute Memory (sprite RAM)
mask[] = { 128, 64, 1, 2,     // Masks used in branch instructions
          1,   0,  0, 1, 4, 0, 0, 4, 0,
          0,   64, 0, 8, 0, 0, 8 }, // Masks used in SE*/CL* instructions.
    keys,                              // Joypad shift register
    mirror,                            // Current mirroring mode
    mmc1_bits, mmc1_data, mmc1_ctrl,   // Mapper 1 (MMC1) registers
    mmc3_chrprg[8], mmc3_bits,         // Mapper 4 (MMC3) registers
    mmc3_irq, mmc3_latch,              //
    chrbank0, chrbank1, prgbank,       // Current PRG/CHR bank
    rombuf[1024 * 1024];               // Buffer to read ROM file into

uint16_t scany,          // Scanline Y
T, V,                // "Loopy" PPU registers
sum,                 // Sum used for ADC/SBC
dot,                 // Horizontal position of PPU, from 0..340
atb,                 // Attribute byte
shift_hi, shift_lo,  // Pattern table shift registers
cycles,              // Cycle count for current instruction
frame_buffer[61440]; // 256x240 pixel frame buffer. Top and bottom 8 rows
// are not drawn.

int shift_at = 0;

// Win32 전역 변수
HWND hwnd;
HDC hdc_win, hdc_mem, hdc_stretch;
HBITMAP hbm_dib, hbm_stretch;
uint16_t* dib_pixels;

// 윈도우 프로시저
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}

// Read a byte from CHR ROM or CHR RAM.
uint8_t* get_chr_byte(uint16_t a) {
    return &chrrom[chr[a >> chrbits] << chrbits | a % (1 << chrbits)];
}

// Read a byte from nametable RAM.
uint8_t* get_nametable_byte(uint16_t a) {
    return &vram[mirror == 0 ? a % 1024                  // single bank 0
        : mirror == 1 ? a % 1024 + 1024           // single bank 1
        : mirror == 2 ? a & 2047                  // vertical mirroring
        : a / 2 & 1024 | a % 1024]; // horizontal mirroring
}

// If `write` is non-zero, writes `val` to the address `hi:lo`, otherwise reads
// a value from the address `hi:lo`.
uint8_t mem(uint8_t lo, uint8_t hi, uint8_t val, uint8_t write) {
    uint16_t addr = hi << 8 | lo;

    switch (hi >>= 4) {
    case 0: case 1: // $0000...$1fff RAM
        return write ? ram[addr] = val : ram[addr];

    case 2: case 3: // $2000..$2007 PPU (mirrored)
        lo &= 7;

        // read/write $2007
        if (lo == 7) {
            tmp = ppubuf;
            uint8_t* rom =
                // Access CHR ROM or CHR RAM
                V < 8192 ? write && chrrom != chrram ? &tmp : get_chr_byte(V)
                // Access nametable RAM
                : V < 16128 ? get_nametable_byte(V)
                // Access palette RAM
                : palette_ram + (uint8_t)((V & 19) == 16 ? V ^ 16 : V);
            write ? *rom = val : (ppubuf = *rom);
            V += ppuctrl & 4 ? 32 : 1;
            V %= 16384;
            return tmp;
        }

        if (write)
            switch (lo) {
            case 0: // $2000 ppuctrl
                ppuctrl = val;
                T = T & 0xf3ff | val % 4 << 10;
                break;

            case 1: // $2001 ppumask
                ppumask = val;
                break;

            case 5: // $2005 ppuscroll
                T = (W ^= 1)
                    ? fine_x = val & 7, T & ~31 | val / 8
                    : T & 0x8c1f | val % 8 << 12 | val * 4 & 0x3e0;
                break;

            case 6: // $2006 ppuaddr
                T = (W ^= 1)
                    ? T & 0xff | val % 64 << 8
                    : (V = T & ~0xff | val);
            }

        if (lo == 2) { // $2002 ppustatus
            tmp = ppustatus & 0xe0;
            ppustatus &= 0x7f;
            W = 0;
            return tmp;
        }
        break;

    case 4:
        if (write && lo == 20) // $4014 OAM DMA
            for (uint16_t i = 256; i--;)
                oam[i] = mem(i, val, 0, 0);

        // $4016 Joypad 1 (GetAsyncKeyState 사용)
        if (lo == 22) {
            if (write) {
                static const int vkeys[8] = {
                    'X',       // A
                    'Z',       // B
                    VK_TAB,    // Select
                    VK_RETURN, // Start
                    VK_UP,     // Dpad Up
                    VK_DOWN,   // Dpad Down
                    VK_LEFT,   // Dpad Left
                    VK_RIGHT   // Dpad Right
                };
                for (tmp = 0, hi = 8; hi--;)
                    tmp = tmp * 2 + ((GetAsyncKeyState(vkeys[hi]) & 0x8000) != 0);
                keys = tmp;
            }
            else {
                tmp = keys & 1;
                keys /= 2;
                return tmp;
            }
        }
        return 0;

    case 6: case 7: // $6000...$7fff PRG RAM
        addr &= 8191;
        return write ? prgram[addr] = val : prgram[addr];

    default: // $8000...$ffff ROM
        // handle mapper writes
        if (write)
            switch (rombuf[6] >> 4) {
            case 7: // mapper 7
                mirror = !(val / 16);
                prg[0] = val % 8 * 2;
                prg[1] = prg[0] + 1;
                break;

            case 4: { // mapper 4
                uint8_t addr1 = addr & 1;
                switch (hi >> 1) {
                case 4: // Bank select/bank data
                    *(addr1 ? &mmc3_chrprg[mmc3_bits & 7] : &mmc3_bits) = val;
                    tmp = mmc3_bits >> 5 & 4;
                    for (int i = 4; i--;) {
                        chr[0 + i + tmp] = mmc3_chrprg[i / 2] & ~!(i % 2) | i % 2;
                        chr[4 + i - tmp] = mmc3_chrprg[2 + i];
                    }
                    tmp = mmc3_bits >> 5 & 2;
                    prg[0 + tmp] = mmc3_chrprg[6];
                    prg[1] = mmc3_chrprg[7];
                    prg[3] = rombuf[4] * 2 - 1;
                    prg[2 - tmp] = prg[3] - 1;
                    break;
                case 5: // Mirroring
                    if (!addr1) {
                        mirror = 2 + val % 2;
                    }
                    break;
                case 6:  // IRQ Latch
                    if (!addr1) {
                        mmc3_latch = val;
                    }
                    break;
                case 7:  // IRQ Enable
                    mmc3_irq = addr1;
                    break;
                }
                break;
            }

            case 3: // mapper 3
                chr[0] = val % 4 * 2;
                chr[1] = chr[0] + 1;
                break;

            case 2: // mapper 2
                prg[0] = val & 31;
                break;

            case 1: // mapper 1
                if (val & 0x80) {
                    mmc1_bits = 5;
                    mmc1_data = 0;
                    mmc1_ctrl |= 12;
                }
                else if (mmc1_data = mmc1_data / 2 | val << 4 & 16, !--mmc1_bits) {
                    mmc1_bits = 5;
                    tmp = addr >> 13;
                    *(tmp == 4 ? mirror = mmc1_data & 3, &mmc1_ctrl
                        : tmp == 5 ? &chrbank0
                        : tmp == 6 ? &chrbank1
                        : &prgbank) = mmc1_data;

                    // Update CHR banks.
                    chr[0] = chrbank0 & ~!(mmc1_ctrl & 16);
                    chr[1] = mmc1_ctrl & 16 ? chrbank1 : chrbank0 | 1;

                    // Update PRG banks.
                    tmp = mmc1_ctrl / 4 % 4 - 2;
                    prg[0] = !tmp ? 0 : tmp == 1 ? prgbank : prgbank & ~1;
                    prg[1] = !tmp ? prgbank : tmp == 1 ? rombuf[4] - 1 : prgbank | 1;
                }
            }
        return rom[(prg[hi - 8 >> prgbits - 12] & (rombuf[4] << 14 - prgbits) - 1)
            << prgbits |
            addr & (1 << prgbits) - 1];
    }

    return ~0;
}

// Read a byte at address `PCH:PCL` and increment PC.
uint8_t read_pc() {
    val = mem(PCL, PC_H, 0, 0);
    !++PCL && ++PC_H;
    return val;
}

// Set N (negative) and Z (zero) flags of `P` register, based on `val`.
uint8_t set_nz(uint8_t val) { return P = P & 125 | val & 128 | !val * 2; }

int main(int argc, char** argv) {
    if (argc < 2) return 1;
    FILE* f = fopen(argv[1], "rb");
    if (!f) return 1;
    fread(rombuf, 1, 1024 * 1024, f);
    fclose(f);

    // Start PRG0 after 16-byte header.
    rom = rombuf + 16;
    // PRG1 is the last bank. `rombuf[4]` is the number of 16k PRG banks.
    prg[1] = rombuf[4] - 1;
    // CHR0 ROM is after all PRG data in the file. `rombuf[5]` is the number of
    // 8k CHR banks. If it is zero, assume the game uses CHR RAM.
    chrrom = rombuf[5] ? rom + (rombuf[4] << 14) : chrram;
    // CHR1 is the last 4k bank.
    chr[1] = rombuf[5] ? rombuf[5] * 2 - 1 : 1;
    // Bit 0 of `rombuf[6]` is 0=>horizontal mirroring, 1=>vertical mirroring.
    mirror = 3 - rombuf[6] % 2;
    if (rombuf[6] / 16 == 4) {
        mem(0, 128, 0, 1); // Update to default mmc3 banks
        prgbits--;         // 8kb PRG banks
        chrbits -= 2;      // 1kb CHR banks
    }

    // Start at address in reset vector, at $FFFC.
    PCL = mem(~3, ~0, 0, 0);
    PC_H = mem(~2, ~0, 0, 0);

    // --- Win32 창 및 GDI 초기화 ---
    WNDCLASSA wc = { 0 };
    wc.lpfnWndProc = WndProc;
    wc.hInstance = GetModuleHandle(NULL);
    wc.lpszClassName = "smolnes";
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassA(&wc);

    // 클라이언트 영역이 정확히 1024x840이 되도록 창 크기 계산
    RECT rect = { 0, 0, 1024, 840 };
    AdjustWindowRect(&rect, WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX, FALSE);

    hwnd = CreateWindowA("smolnes", "smolnes (Win32 GDI)",
        (WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX) | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rect.right - rect.left, rect.bottom - rect.top,
        NULL, NULL, wc.hInstance, NULL);

    hdc_win = GetDC(hwnd);
    hdc_mem = CreateCompatibleDC(hdc_win);
    hdc_stretch = CreateCompatibleDC(hdc_win);
    hbm_stretch = CreateCompatibleBitmap(hdc_win, 1024, 840);
    SelectObject(hdc_stretch, hbm_stretch);

    // RGB565 포맷을 위한 BITMAPINFO 설정 (BI_BITFIELDS 사용)
    struct {
        BITMAPINFOHEADER bmiHeader;
        DWORD masks[3];
    } bmi = { 0 };

    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = 256;
    bmi.bmiHeader.biHeight = -224; // Top-down DIB (위에서 아래로 그림)
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 16;
    bmi.bmiHeader.biCompression = BI_BITFIELDS;
    bmi.masks[0] = 0xF800; // Red (하위 5비트)
    bmi.masks[1] = 0x07E0; // Green (중간 6비트)
    bmi.masks[2] = 0x001F; // Blue (상위 5비트)

    hbm_dib = CreateDIBSection(hdc_win, (BITMAPINFO*)&bmi, DIB_RGB_COLORS, (void**)&dib_pixels, NULL, 0);
    SelectObject(hdc_mem, hbm_dib);

    DWORD last_tick = GetTickCount();

loop:
    cycles = nomem = 0;
    if (nmi_irq)
        goto nmi_irq;

    opcode = read_pc();
    uint8_t opcodelo5 = opcode & 31;
    switch (opcodelo5) {
    case 0:
        if (opcode & 0x80) { // LDY/CPY/CPX imm
            read_pc();
            nomem = 1;
            goto nomemop;
        }

        switch (opcode >> 5) {
        case 0: { // BRK or nmi_irq
            !++PCL && ++PC_H;
        nmi_irq:
            PUSH(PC_H);
            PUSH(PCL);
            PUSH(P | 32);
            // BRK/IRQ vector is $ffff, NMI vector is$fffa
            uint16_t veclo = ~1 - (nmi_irq & 4);
            PCL = mem(veclo, ~0, 0, 0);
            PC_H = mem(veclo + 1, ~0, 0, 0);
            nmi_irq = 0;
            cycles++;
            break;
        }

        case 1: // JSR
            result = read_pc();
            PUSH(PC_H);
            PUSH(PCL);
            PC_H = read_pc();
            PCL = result;
            break;

        case 2: // RTI
            P = PULL & ~32;
            PCL = PULL;
            PC_H = PULL;
            break;

        case 3: // RTS
            PCL = PULL;
            PC_H = PULL;
            !++PCL && ++PC_H;
            break;
        }

        cycles += 4;
        break;

    case 16: // BPL, BMI, BVC, BVS, BCC, BCS, BNE, BEQ
        read_pc();
        if (!(P & mask[opcode >> 6]) ^ opcode / 32 & 1) {
            cross = PCL + (int8_t)val >> 8;
            PC_H += cross;
            PCL += val;
            cycles += cross ? 2 : 1;
        }
        break;

    case 8: case 24:
        switch (opcode >>= 4) {
        case 0: // PHP
            PUSH(P | 48);
            cycles++;
            break;

        case 2: // PLP
            P = PULL & ~16;
            cycles += 2;
            break;

        case 4: // PHA
            PUSH(A);
            cycles++;
            break;

        case 6: // PLA
            set_nz(A = PULL);
            cycles += 2;
            break;

        case 8: // DEY
            set_nz(--Y);
            break;

        case 9: // TYA
            set_nz(A = Y);
            break;

        case 10: // TAY
            set_nz(Y = A);
            break;

        case 12: // INY
            set_nz(++Y);
            break;

        case 14: // INX
            set_nz(++X);
            break;

        default: // CLC, SEC, CLI, SEI, CLV, CLD, SED
            P = P & ~mask[opcode + 3] | mask[opcode + 4];
            break;
        }
        break;

    case 10: case 26:
        switch (opcode >> 4) {
        case 8: // TXA
            set_nz(A = X);
            break;

        case 9: // TXS
            S = X;
            break;

        case 10: // TAX
            set_nz(X = A);
            break;

        case 11: // TSX
            set_nz(X = S);
            break;

        case 12: // DEX
            set_nz(--X);
            break;

        case 14: // NOP
            break;

        default: // ASL/ROL/LSR/ROR A
            nomem = 1;
            val = A;
            goto nomemop;
        }
        break;

    case 1: // X-indexed, indirect
        read_pc();
        val += X;
        addr_lo = mem(val, 0, 0, 0);
        addr_hi = mem(val + 1, 0, 0, 0);
        cycles += 4;
        goto opcode;

    case 2: case 9: // Immediate
        read_pc();
        nomem = 1;
        goto nomemop;

    case 17: // Zeropage, Y-indexed
        addr_lo = mem(read_pc(), 0, 0, 0);
        addr_hi = mem(val + 1, 0, 0, 0);
        cycles++;
        goto add_x_or_y;

    case 4: case 5: case 6:     // Zeropage                +1
    case 20: case 21: case 22:  // Zeropage, X-indexed     +2
        addr_lo = read_pc();
        cross = opcodelo5 > 6;
        if (cross) {
            addr_lo += (opcode & 214) == 150 ? Y : X;  // LDX/STX use Y
        }
        addr_hi = 0;
        cycles -= !cross;
        goto opcode;

    case 12: case 13: case 14: // Absolute                +2
    case 25:                   // Absolute, Y-indexed     +2/3
    case 28: case 29: case 30: // Absolute, X-indexed     +2/3
        addr_lo = read_pc();
        addr_hi = read_pc();
        if (opcodelo5 < 25) goto opcode;
    add_x_or_y:
        val = opcodelo5 < 28 | opcode == 190 ? Y : X;
        cross = addr_lo + val > 255;
        addr_hi += cross;
        addr_lo += val;
        cycles +=
            ((opcode & 224) == 128 | opcode % 16 == 14 & opcode != 190) | cross;
    opcode:
        cycles += 2;
        if (opcode != 76 & (opcode & 224) != 128) {
            val = mem(addr_lo, addr_hi, 0, 0);
        }

    nomemop:
        result = 0;
        switch (opcode & 227) {
        case 1: set_nz(A |= val); break;  // ORA
        case 33: set_nz(A &= val); break; // AND
        case 65: set_nz(A ^= val); break; // EOR
        case 225: // SBC
            val = ~val;
            // fallthrough
        case 97: // ADC
            sum = A + val + P % 2;
            P = P & ~65 | sum > 255 | ((A ^ sum) & (val ^ sum) & 128) / 2;
            set_nz(A = sum);
            break;

        case 34: // ROL
            result = P & 1;
            // fallthrough
        case 2: // ASL
            result |= val * 2;
            P = P & ~1 | val / 128;
            goto memop;

        case 98: // ROR
            result = P << 7;
            // fallthrough
        case 66: // LSR
            result |= val / 2;
            P = P & ~1 | val & 1;
            goto memop;

        case 194: // DEC
            result = val - 1;
            goto memop;

        case 226: // INC
            result = val + 1;
            // fallthrough

        memop:
            set_nz(result);
            // Write result to A or back to memory.
            nomem ? A = result : (cycles += 2, mem(addr_lo, addr_hi, result, 1));
            break;

        case 32: // BIT
            P = P & 61 | val & 192 | !(A & val) * 2;
            break;

        case 64: // JMP
            PCL = addr_lo;
            PC_H = addr_hi;
            cycles--;
            break;

        case 96: // JMP indirect
            PCL = val;
            PC_H = mem(addr_lo + 1, addr_hi, 0, 0);
            cycles++;
            break;

        default: {
            uint8_t opcodehi3 = opcode / 32;
            uint8_t* reg = opcode % 4 == 2 | opcodehi3 == 7 ? &X
                : opcode % 4 == 1 ? &A
                : &Y;
            if (opcodehi3 == 4) {  // STY/STA/STX
                mem(addr_lo, addr_hi, *reg, 1);
            }
            else if (opcodehi3 != 5) {  // CPY/CMP/CPX
                P = P & ~1 | *reg >= val;
                set_nz(*reg - val);
            }
            else {  // LDY/LDA/LDX
                set_nz(*reg = val);
            }
            break;
        }
        }
    }

    // Update PPU, which runs 3 times faster than CPU. Each CPU instruction
    // takes at least 2 cycles.
    for (tmp = cycles * 3 + 6; tmp--;) {
        if (ppumask & 24) { // If background or sprites are enabled.
            if (scany < 240) {
                if (dot - 256 > 63u) {  // dot [0..255,320..340]
                    // Draw a pixel to the framebuffer.
                    if (dot < 256) {
                        // Read color and palette from shift registers.
                        uint8_t color = shift_hi >> 14 - fine_x & 2 |
                            shift_lo >> 15 - fine_x & 1,
                            palette = shift_at >> 28 - fine_x * 2 & 12;

                        // If sprites are enabled.
                        if (ppumask & 16) {
                            // Loop through all sprites.
                            for (uint8_t* sprite = oam; sprite < oam + 256; sprite += 4) {
                                uint16_t sprite_h = ppuctrl & 32 ? 16 : 8,
                                    sprite_x = dot - sprite[3],
                                    sprite_y = scany - sprite[0] - 1,
                                    sx = sprite_x ^ !(sprite[2] & 64) * 7,
                                    sy = sprite_y ^ (sprite[2] & 128 ? sprite_h - 1 : 0);
                                if (sprite_x < 8 && sprite_y < sprite_h) {
                                    uint16_t sprite_tile = sprite[1],
                                        sprite_addr =
                                        (ppuctrl & 32
                                            // 8x16 sprites
                                            ? sprite_tile % 2 << 12 |
                                            sprite_tile << 4 & -32 | sy * 2 & 16
                                            // 8x8 sprites
                                            : (ppuctrl & 8) << 9 | sprite_tile << 4) |
                                        sy & 7,
                                        sprite_color =
                                        *get_chr_byte(sprite_addr + 8) >> sx << 1 & 2 |
                                        *get_chr_byte(sprite_addr) >> sx & 1;
                                    // Only draw sprite if color is not 0 (transparent)
                                    if (sprite_color) {
                                        // Don't draw sprite if BG has priority.
                                        if (!(sprite[2] & 32 && color)) {
                                            color = sprite_color;
                                            palette = 16 | sprite[2] * 4 & 12;
                                        }
                                        // Maybe set sprite0 hit flag.
                                        if (sprite == oam && color)
                                            ppustatus |= 64;
                                        break;
                                    }
                                }
                            }
                        }

                        // Write pixel to framebuffer (RGB565 포맷: RRRRRGGGGGGBBBBB)
                        frame_buffer[scany * 256 + dot] =
                            (uint16_t[64]){
                                25356, 17,    16395, 22543, 36876, 45058, 43008, 30880,
                                16704, 320,   384,   288,   411,   0,     0,     0,
                                44373, 1085,  17117, 37599, 55925, 57609, 55712, 47552,
                                35328, 704,   832,   713,   850,   0,     0,     0,
                                ~0,    15999, 36479, 52863, 65183, 64981, 64941, 64804,
                                62848, 32512, 16265, 24535, 1983,  31727, 0,     0,
                                ~0,    44991, 51039, 57183, 65375, 65339, 59190, 65365,
                                65430, 59350, 47093, 47098, 40959, 59293, 0,     0 }
                        [palette_ram[color ? palette | color : 0]];
                    }
                 
                    // Update shift registers every cycle.
                    if (dot < 336) {
                        shift_hi *= 2;
                        shift_lo *= 2;
                        shift_at *= 4;
                    }

                    int temp = ppuctrl << 8 & 4096 | ntb << 4 | V >> 12;
                    switch (dot & 7) {
                    case 1: // Read nametable byte.
                        ntb = *get_nametable_byte(V);
                        break;
                    case 3: // Read attribute byte.
                        atb = (*get_nametable_byte(V & 0xc00 | 0x3c0 | V >> 4 & 0x38 |
                            V / 4 & 7) >>
                            (V >> 5 & 2 | V / 2 & 1) * 2) %
                            4 * 0x5555;
                        break;
                    case 5: // Read pattern table low byte.
                        ptb_lo = *get_chr_byte(temp);
                        break;
                    case 7: { // Read pattern table high byte.
                        uint8_t ptb_hi = *get_chr_byte(temp | 8);
                        // Increment horizontal VRAM read address.
                        V = V % 32 == 31 ? V & ~31 ^ 1024 : V + 1;
                        shift_hi |= ptb_hi;
                        shift_lo |= ptb_lo;
                        shift_at |= atb;
                        break;
                    }
                    }
                }

                // Increment vertical VRAM address.
                if (dot == 256) {
                    V = ((V & 7 << 12) != 7 << 12 ? V + 4096
                        : (V & 0x3e0) == 928 ? V & 0x8c1f ^ 2048
                        : (V & 0x3e0) == 0x3e0 ? V & 0x8c1f
                        : V & 0x8c1f | V + 32 & 0x3e0) &
                        // Reset horizontal VRAM address to T value.
                        ~0x41f |
                        T & 0x41f;
                }
            }

            // Check for MMC3 IRQ.
            if ((scany + 1) % 262 < 241 && dot == 261 && mmc3_irq && !mmc3_latch--)
                nmi_irq = 1;

            // Reset vertical VRAM address to T value.
            if (scany == 261 && dot - 280 < 25u)  // dot [280..304]
                V = V & 0x841f | T & 0x7be0;
        }

        if (dot == 1) {
            if (scany == 241) {
                // If NMI is enabled, trigger NMI.
                if (ppuctrl & 128)
                    nmi_irq = 4;
                ppustatus |= 128;

                // 프레임 출력 및 60FPS 동기화 함수 호출 (창을 닫으면 0을 반환하여 종료)
                if (!render_and_sync_frame(frame_buffer)) {
                    timeEndPeriod(1);
                    return 0;
                }

                /*
                // 1. 상하단 8픽셀을 제외한 픽셀 데이터(256x224)를 DIBSection 메모리에 복사
                memcpy(dib_pixels, frame_buffer + 2048, 256 * 224 * sizeof(uint16_t));

                // 2. 메모리 버퍼에서 1024x840 크기로 확대한 뒤, 최종적으로 BitBlt로 화면에 출력
                // (만약 256x224 1:1 원본 크기로 바로 찍고 싶다면 StretchBlt 줄을 지우고
                //  BitBlt(hdc_win, 0, 0, 256, 224, hdc_mem, 0, 0, SRCCOPY); 로 바꾸면 됩니다.)
                StretchBlt(hdc_stretch, 0, 0, 1024, 840, hdc_mem, 0, 0, 256, 224, SRCCOPY);
                BitBlt(hdc_win, 0, 0, 1024, 840, hdc_stretch, 0, 0, SRCCOPY);

                // 3. Win32 메시지 루프 처리
                MSG msg;
                while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
                    if (msg.message == WM_QUIT)
                        return 0;
                    TranslateMessage(&msg);
                    DispatchMessageA(&msg);
                }

                // 4. 약 60FPS 속도 유지 (약 16ms 대기)
                DWORD now = GetTickCount();
                if (now - last_tick < 16) {
                    Sleep(16 - (now - last_tick));
                }
                last_tick = GetTickCount();
                */

                // StretchBlt 확대 시 픽셀이 뭉개지지 않도록 최근접 이웃(Nearest Neighbor) 필터 강제 지정
                SetStretchBltMode(hdc_stretch, COLORONCOLOR);

                // 고정밀 타이머 초기화
                init_timing();
            }

            // Clear ppustatus.
            if (scany == 261)
                ppustatus = 0;
        }

        // Increment to next dot/scany. 341 dots per scanline, 262 scanlines per
        // frame. Scanline 261 is represented as -1.
        if (++dot == 341) {
            dot = 0;
            scany++;
            scany %= 262;
        }
    }
    goto loop;
}
