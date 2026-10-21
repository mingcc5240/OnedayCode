#include <windows.h>
#include <mmsystem.h>
#include <stdint.h>
#include <stdio.h>

#define PULL mem(++S, 1, 0, 0)
#define PUSH(x) mem(S--, 1, x, 1)

uint8_t *rom, *chrrom,                // Points to the start of PRG/CHR ROM
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
    mask[] = {128, 64, 1, 2,     // Masks used in branch instructions
              1,   0,  0, 1, 4, 0, 0, 4, 0,
              0,   64, 0, 8, 0, 0, 8}, // Masks used in SE*/CL* instructions.
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


// 상태 세이브 함수 (F1)
void save_state(const char* filename) {
     FILE* f = fopen(filename, "wb");
    if (!f) {
        return;
    }
    
    // CPU 레지스터 및 주요 변수 저장
    fwrite(&A, 1, 1, f);
    fwrite(&X, 1, 1, f);
    fwrite(&Y, 1, 1, f);
    fwrite(&P, 1, 1, f);
    fwrite(&S, 1, 1, f);
    fwrite(&PC_H, 1, 1, f);
    fwrite(&PCL, 1, 1, f);
    fwrite(&ppuctrl, 1, 1, f);
    fwrite(&ppumask, 1, 1, f);
    fwrite(&ppustatus, 1, 1, f);
    fwrite(&ppubuf, 1, 1, f);
    fwrite(&W, 1, 1, f);
    fwrite(&fine_x, 1, 1, f);
    fwrite(&mirror, 1, 1, f);
    fwrite(&scany, sizeof(scany), 1, f);
    fwrite(&dot, sizeof(dot), 1, f);
    fwrite(&T, sizeof(T), 1, f);
    fwrite(&V, sizeof(V), 1, f);
    fwrite(&shift_hi, sizeof(shift_hi), 1, f);
    fwrite(&shift_lo, sizeof(shift_lo), 1, f);
    fwrite(&shift_at, sizeof(shift_at), 1, f);
    // 메모리 및 뱅크 버퍼 저장
    fwrite(prg, 1, 4, f);
    fwrite(chr, 1, 8, f);
    fwrite(ram, 1, 8192, f);
    fwrite(vram, 1, 2048, f);
    fwrite(palette_ram, 1, 64, f);
    fwrite(chrram, 1, 8192, f);
    fwrite(prgram, 1, 8192, f);
    fwrite(oam, 1, 256, f);
    // 매퍼 상태 저장
    fwrite(&mmc1_bits, 1, 1, f);
    fwrite(&mmc1_data, 1, 1, f);
    fwrite(&mmc1_ctrl, 1, 1, f);
    fwrite(mmc3_chrprg, 1, 8, f);
    fwrite(&mmc3_bits, 1, 1, f);
    fwrite(&mmc3_irq, 1, 1, f);
    fwrite(&mmc3_latch, 1, 1, f);
    fwrite(&chrbank0, 1, 1, f);
    fwrite(&chrbank1, 1, 1, f);
    fwrite(&prgbank, 1, 1, f);
    fclose(f);
}

// 상태 로딩 함수 (F2)
void load_state(const char* filename) {
    FILE* f = fopen(filename, "rb");
    if (!f) return;
    fread(&A, 1, 1, f);
    fread(&X, 1, 1, f);
    fread(&Y, 1, 1, f);
    fread(&P, 1, 1, f);
    fread(&S, 1, 1, f);
    fread(&PC_H, 1, 1, f);
    fread(&PCL, 1, 1, f);
    fread(&ppuctrl, 1, 1, f);
    fread(&ppumask, 1, 1, f);
    fread(&ppustatus, 1, 1, f);
    fread(&ppubuf, 1, 1, f);
    fread(&W, 1, 1, f);
    fread(&fine_x, 1, 1, f);
    fread(&mirror, 1, 1, f);
    fread(&scany, sizeof(scany), 1, f);
    fread(&dot, sizeof(dot), 1, f);
    fread(&T, sizeof(T), 1, f);
    fread(&V, sizeof(V), 1, f);
    fread(&shift_hi, sizeof(shift_hi), 1, f);
    fread(&shift_lo, sizeof(shift_lo), 1, f);
    fread(&shift_at, sizeof(shift_at), 1, f);
    fread(prg, 1, 4, f);
    fread(chr, 1, 8, f);
    fread(ram, 1, 8192, f);
    fread(vram, 1, 2048, f);
    fread(palette_ram, 1, 64, f);
    fread(chrram, 1, 8192, f);
    fread(prgram, 1, 8192, f);
    fread(oam, 1, 256, f);
    fread(&mmc1_bits, 1, 1, f);
    fread(&mmc1_data, 1, 1, f);
    fread(&mmc1_ctrl, 1, 1, f);
    fread(mmc3_chrprg, 1, 8, f);
    fread(&mmc3_bits, 1, 1, f);
    fread(&mmc3_irq, 1, 1, f);
    fread(&mmc3_latch, 1, 1, f);
    fread(&chrbank0, 1, 1, f);
    fread(&chrbank1, 1, 1, f);
    fread(&prgbank, 1, 1, f);
    fclose(f);
}

// Win32 GDI 및 고정밀 타이머 전역 변수 (Scale3x: 768x672)
#define WIN_W (256 * 3) // 768
#define WIN_H (224 * 3) // 672

HWND hwnd;
HDC hdc_win, hdc_mem;
HBITMAP hbm_dib;
uint16_t *dib_pixels;

LARGE_INTEGER qpc_freq, next_frame_tick;
double ticks_per_frame;

/*
LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
  if (msg == WM_DESTROY) {
    PostQuitMessage(0);
    return 0;
  }
  return DefWindowProc(hWnd, msg, wParam, lParam);
} */

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_KEYDOWN:
        if (wParam == VK_F1) {
            save_state("smolnes_save.sav");
            SetWindowTextA(hWnd, "smolnes - State Saved! (F1)");
        }
        else if (wParam == VK_F2) {
            load_state("smolnes_save.sav");
            SetWindowTextA(hWnd, "smolnes - State Loaded! (F2)");
        }
        break;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}


// 타이머 초기화 함수
void init_timing(void) {
  timeBeginPeriod(1);
  QueryPerformanceFrequency(&qpc_freq);
  ticks_per_frame = (double)qpc_freq.QuadPart / 60.0988139;
  QueryPerformanceCounter(&next_frame_tick);
}

// Scale3x (AdvMAME3x) 픽셀 업스케일링 필터 (256x224 -> 768x672)
void apply_scale3x(const uint16_t *src, uint16_t *dst) {
  for (int y = 0; y < 224; y++) {
    const uint16_t *row_prev = src + (y > 0 ? y - 1 : y) * 256;
    const uint16_t *row_curr = src + y * 256;
    const uint16_t *row_next = src + (y < 223 ? y + 1 : y) * 256;

    uint16_t *dst0 = dst + (y * 3) * 768;
    uint16_t *dst1 = dst0 + 768;
    uint16_t *dst2 = dst1 + 768;

    for (int x = 0; x < 256; x++) {
      int xl = (x > 0) ? x - 1 : x;
      int xr = (x < 255) ? x + 1 : x;

      uint16_t A = row_prev[xl], B = row_prev[x], C = row_prev[xr];
      uint16_t D = row_curr[xl], E = row_curr[x], F = row_curr[xr];
      uint16_t G = row_next[xl], H = row_next[x], I = row_next[xr];

      int dx = x * 3;
      if (B != H && D != F) {
        dst0[dx]     = (D == B) ? D : E;
        dst0[dx + 1] = ((D == B && E != C) || (B == F && E != A)) ? B : E;
        dst0[dx + 2] = (B == F) ? F : E;
        dst1[dx]     = ((D == B && E != G) || (D == H && E != A)) ? D : E;
        dst1[dx + 1] = E;
        dst1[dx + 2] = ((B == F && E != I) || (H == F && E != C)) ? F : E;
        dst2[dx]     = (D == H) ? D : E;
        dst2[dx + 1] = ((D == H && E != I) || (H == F && E != G)) ? H : E;
        dst2[dx + 2] = (H == F) ? F : E;
      } else {
        dst0[dx] = dst0[dx + 1] = dst0[dx + 2] = E;
        dst1[dx] = dst1[dx + 1] = dst1[dx + 2] = E;
        dst2[dx] = dst2[dx + 1] = dst2[dx + 2] = E;
      }
    }
  }
}

// 화면 출력 및 정밀 60FPS 동기화 함수
int render_and_sync_frame(uint16_t *fb) {
  // 1. 상하단 8픽셀을 제외한 영역(fb + 2048)에 Scale3x를 적용해 DIBSection에 직접 기록
  apply_scale3x(fb + 2048, dib_pixels);

  // 2. StretchBlt 없이 순수 BitBlt로 768x672 화면을 1:1 출력
  BitBlt(hdc_win, 0, 0, WIN_W, WIN_H, hdc_mem, 0, 0, SRCCOPY);

  // 3. 윈도우 메시지 처리
  MSG msg;
  while (PeekMessageA(&msg, NULL, 0, 0, PM_REMOVE)) {
    if (msg.message == WM_QUIT)
      return 0;
    TranslateMessage(&msg);
    DispatchMessageA(&msg);
  }

  // 4. 하이브리드 60FPS 타이밍 제어 (Sleep + Spin-wait)
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  next_frame_tick.QuadPart += (LONGLONG)ticks_per_frame;

  if (now.QuadPart > next_frame_tick.QuadPart + (LONGLONG)(ticks_per_frame * 3)) {
    next_frame_tick = now;
  }

  while (1) {
    QueryPerformanceCounter(&now);
    LONGLONG remain = next_frame_tick.QuadPart - now.QuadPart;
    if (remain <= 0)
      break;

    double remain_ms = (double)remain * 1000.0 / (double)qpc_freq.QuadPart;
    if (remain_ms > 2.0) {
      Sleep(1);
    } else {
      YieldProcessor();
    }
  }

  // 5. 1초(1000ms)마다 실시간 FPS 계산 및 타이틀바 갱신
  static DWORD fps_last_ms = 0;
  static int fps_frames = 0;

  fps_frames++;
  DWORD cur_ms = GetTickCount();
  if (fps_last_ms == 0) {
    fps_last_ms = cur_ms;
  } else if (cur_ms - fps_last_ms >= 1000) {
    DWORD dt = cur_ms - fps_last_ms;
    int fps_x100 = (fps_frames * 100000 + (dt / 2)) / dt;

    char title[64];
    wsprintfA(title, "smolnes (Scale3x 768x672) - %d.%02d FPS", fps_x100 / 100, fps_x100 % 100);
    SetWindowTextA(hwnd, title);

    fps_frames = 0;
    fps_last_ms = cur_ms;
  }

   return 1;
}

// Read a byte from CHR ROM or CHR RAM.
uint8_t *get_chr_byte(uint16_t a) {
  return &chrrom[chr[a >> chrbits] << chrbits | a % (1 << chrbits)];
}

// Read a byte from nametable RAM.
uint8_t *get_nametable_byte(uint16_t a) {
  return &vram[mirror == 0   ? a % 1024                  // single bank 0
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
      uint8_t *rom =
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
      } else {
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
        } else if (mmc1_data = mmc1_data / 2 | val << 4 & 16, !--mmc1_bits) {
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

// Read a byte at address `PC_H:PCL` and increment PC.
uint8_t read_pc() {
  val = mem(PCL, PC_H, 0, 0);
  !++PCL && ++PC_H;
  return val;
}

// Set N (negative) and Z (zero) flags of `P` register, based on `val`.
uint8_t set_nz(uint8_t val) { return P = P & 125 | val & 128 | !val * 2; }

int main(int argc, char **argv) {
  if (argc < 2) return 1;
  FILE *f = fopen(argv[1], "rb");
  if (!f) return 1;
  fread(rombuf, 1, 1024 * 1024, f);
  fclose(f);

  rom = rombuf + 16;
  prg[1] = rombuf[4] - 1;
  chrrom = rombuf[5] ? rom + (rombuf[4] << 14) : chrram;
  chr[1] = rombuf[5] ? rombuf[5] * 2 - 1 : 1;
  mirror = 3 - rombuf[6] % 2;
  if (rombuf[6] / 16 == 4) {
    mem(0, 128, 0, 1);
    prgbits--;
    chrbits -= 2;
  }

  PCL = mem(~3, ~0, 0, 0);
  PC_H = mem(~2, ~0, 0, 0);

  // --- Win32 창 및 768x672 DIBSection 초기화 ---
  WNDCLASSA wc = {0};
  wc.lpfnWndProc = WndProc;
  wc.hInstance = GetModuleHandle(NULL);
  wc.lpszClassName = "smolnes";
  wc.hCursor = LoadCursor(NULL, IDC_ARROW);
  RegisterClassA(&wc);

  DWORD style = WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX;
  RECT rect = {0, 0, WIN_W, WIN_H};
  AdjustWindowRect(&rect, style, FALSE);

  hwnd = CreateWindowA("smolnes", "smolnes (Scale3x 768x672)",
                       style | WS_VISIBLE,
                       CW_USEDEFAULT, CW_USEDEFAULT,
                       rect.right - rect.left, rect.bottom - rect.top,
                       NULL, NULL, wc.hInstance, NULL);

  hdc_win = GetDC(hwnd);
  hdc_mem = CreateCompatibleDC(hdc_win);

  struct {
    BITMAPINFOHEADER bmiHeader;
    DWORD masks[3];
  } bmi = {0};

  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = WIN_W;   // 768
  bmi.bmiHeader.biHeight = -WIN_H; // -672 (Top-down DIB)
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 16;
  bmi.bmiHeader.biCompression = BI_BITFIELDS;
  // 원본 BGR565 팔레트에 맞춘 채널 마스크
  bmi.masks[0] = 0x001F; // Red
  bmi.masks[1] = 0x07E0; // Green
  bmi.masks[2] = 0xF800; // Blue

  hbm_dib = CreateDIBSection(hdc_win, (BITMAPINFO *)&bmi, DIB_RGB_COLORS, (void **)&dib_pixels, NULL, 0);
  SelectObject(hdc_mem, hbm_dib);

  init_timing();

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
      uint8_t *reg = opcode % 4 == 2 | opcodehi3 == 7 ? &X
                     : opcode % 4 == 1                ? &A
                                                      : &Y;
      if (opcodehi3 == 4) {  // STY/STA/STX
        mem(addr_lo, addr_hi, *reg, 1);
      } else if (opcodehi3 != 5) {  // CPY/CMP/CPX
        P = P & ~1 | *reg >= val;
        set_nz(*reg - val);
      } else {  // LDY/LDA/LDX
        set_nz(*reg = val);
      }
      break;
    }
    }
  }

  // Update PPU, which runs 3 times faster than CPU.
  for (tmp = cycles * 3 + 6; tmp--;) {
    if (ppumask & 24) {
      if (scany < 240) {
        if (dot - 256 > 63u) {
          if (dot < 256) {
            uint8_t color = shift_hi >> 14 - fine_x & 2 |
                            shift_lo >> 15 - fine_x & 1,
                    palette = shift_at >> 28 - fine_x * 2 & 12;

            if (ppumask & 16) {
              for (uint8_t *sprite = oam; sprite < oam + 256; sprite += 4) {
                uint16_t sprite_h = ppuctrl & 32 ? 16 : 8,
                         sprite_x = dot - sprite[3],
                         sprite_y = scany - sprite[0] - 1,
                         sx = sprite_x ^ !(sprite[2] & 64) * 7,
                         sy = sprite_y ^ (sprite[2] & 128 ? sprite_h - 1 : 0);
                if (sprite_x < 8 && sprite_y < sprite_h) {
                  uint16_t sprite_tile = sprite[1],
                           sprite_addr =
                               (ppuctrl & 32
                                    ? sprite_tile % 2 << 12 |
                                          sprite_tile << 4 & -32 | sy * 2 & 16
                                    : (ppuctrl & 8) << 9 | sprite_tile << 4) |
                               sy & 7,
                           sprite_color =
                               *get_chr_byte(sprite_addr + 8) >> sx << 1 & 2 |
                               *get_chr_byte(sprite_addr) >> sx & 1;
                  if (sprite_color) {
                    if (!(sprite[2] & 32 && color)) {
                      color = sprite_color;
                      palette = 16 | sprite[2] * 4 & 12;
                    }
                    if (sprite == oam && color)
                      ppustatus |= 64;
                    break;
                  }
                }
              }
            }

            frame_buffer[scany * 256 + dot] =
                (uint16_t[64]){
                    25356, 34816, 39011, 30854, 24714, 4107,  106,   2311,
                    2468,  2561,  4642,  6592,  20832, 0,     0,     0,
                    44373, 49761, 55593, 51341, 43186, 18675, 434,   654,
                    4939,  5058,  3074,  19362, 37667, 0,     0,     0,
                    ~0,    ~819,  64497, 64342, 62331, 43932, 23612, 9465,
                    1429,  1550,  20075, 36358, 52713, 16904, 0,     0,
                    ~0,    ~328,  ~422,  ~452,  ~482,  58911, 50814, 42620,
                    40667, 40729, 48951, 53078, 61238, 44405}
                    [palette_ram[color ? palette | color : 0]];
          }

          if (dot < 336) {
            shift_hi *= 2;
            shift_lo *= 2;
            shift_at *= 4;
          }

          int temp = ppuctrl << 8 & 4096 | ntb << 4 | V >> 12;
          switch (dot & 7) {
          case 1:
            ntb = *get_nametable_byte(V);
            break;
          case 3:
            atb = (*get_nametable_byte(V & 0xc00 | 0x3c0 | V >> 4 & 0x38 |
                                       V / 4 & 7) >>
                   (V >> 5 & 2 | V / 2 & 1) * 2) %
                  4 * 0x5555;
            break;
          case 5:
            ptb_lo = *get_chr_byte(temp);
            break;
          case 7: {
            uint8_t ptb_hi = *get_chr_byte(temp | 8);
            V = V % 32 == 31 ? V & ~31 ^ 1024 : V + 1;
            shift_hi |= ptb_hi;
            shift_lo |= ptb_lo;
            shift_at |= atb;
            break;
          }
          }
        }

        if (dot == 256) {
          V = ((V & 7 << 12) != 7 << 12 ? V + 4096
               : (V & 0x3e0) == 928     ? V & 0x8c1f ^ 2048
               : (V & 0x3e0) == 0x3e0   ? V & 0x8c1f
                                        : V & 0x8c1f | V + 32 & 0x3e0) &
                  ~0x41f |
              T & 0x41f;
        }
      }

      if ((scany + 1) % 262 < 241 && dot == 261 && mmc3_irq && !mmc3_latch--)
        nmi_irq = 1;

      if (scany == 261 && dot - 280 < 25u)
        V = V & 0x841f | T & 0x7be0;
    }

    if (dot == 1) {
      if (scany == 241) {
        if (ppuctrl & 128)
          nmi_irq = 4;
        ppustatus |= 128;

        if (!render_and_sync_frame(frame_buffer)) {
          timeEndPeriod(1);
          return 0;
        }
      }

      if (scany == 261)
        ppustatus = 0;
    }

    if (++dot == 341) {
      dot = 0;
      scany++;
      scany %= 262;
    }
  }
  goto loop;
}
