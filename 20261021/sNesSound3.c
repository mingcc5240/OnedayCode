//완전축약본으로 만든 smolnes (60FPS + 5채널 APU + 컴파일 오류 수정)
#include <windows.h>
#include <mmsystem.h>
#include <stdio.h>
#include <stdint.h>

#pragma comment(lib, "winmm.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "user32.lib")

#define k if
#define _ 1024
#define G goto
#define Q return
#define Z switch
#define z m(++St,1)
#define W break;case
#define BD break;default:
#define m(l,h)mm(l,h,0,0)
#define g(x)mm(St--,1,x,1);
#define x(a,b)case a:case b:

typedef uint8_t u; typedef uint16_t U;
u* E, * C, K[4], M[8], e = 14, Mb = 12, S[8], MB, MI, ML, A, X, Y, P = 4, St = ~2, h, l, i, j, L, r, v, t, pm, p, H, pb, pw, fx, o, N, nb, pl, vr[_ * 2], Pr[_ * 2], D, ra[_ * 8], cr[_ * 8], pr[_ * 8], oa[_], bm[] = "\200@\1\2\1\0\0\1\4\0\0\4\0\0@\0\b\0\0\b", ks, mb, F, I, c0, c1, J, b[_ * _], * kb;
U y, T, V, d, at, a, s, c, fb[_ * _], yy = 992, xx = 35871;
int f;

HWND hwnd;
HDC hdc_win, hdc_mem;
HBITMAP hbm_dib;
uint16_t* dib_pixels;

// --- NES APU (5채널: Pulse1, Pulse2, Triangle, Noise, DMC) 및 오디오 전역 변수 ---
#define SAMPLE_RATE 44100
#define SAMPLES_PER_FRAME (SAMPLE_RATE / 60) // 735 샘플
#define AUDIO_BUF_COUNT 4

HWAVEOUT hWaveOut;
WAVEHDR waveHdr[AUDIO_BUF_COUNT];
int16_t audio_buf[AUDIO_BUF_COUNT][SAMPLES_PER_FRAME];
int cur_audio_buf = 0;

u apu_reg[24];
int apu_len[4];          // 길이 카운터 (Pulse1, Pulse2, Triangle, Noise)
U pulse_period[2];       // Pulse 1, 2 실제 주기(11-bit)

// Envelope 및 Sweep 상태 변수
u env_start[4], env_div[4], env_decay[4];
u sweep_reload[2], sweep_div[2];

// Triangle 선형 카운터 상태 변수
int tri_lin;
u tri_reload;

// DMC (Delta Modulation Channel) 상태 변수
U dmc_addr = 0xC000, dmc_len = 1;
U dmc_curr_addr = 0xC000, dmc_curr_len = 0;
u dmc_shift = 0, dmc_bits_left = 0, dmc_sample_buffer = 0, dmc_buffer_empty = 1;
int dmc_output = 0; // 0 ~ 127 DAC 레벨
double dmc_phase = 0;

double apu_phase[4];
U noise_lfsr = 1;

const u apu_len_tab[32] = {
    10, 254, 20,  2, 40,  4, 80,  6, 160,  8, 60, 10, 14, 12, 26, 14,
    12,  16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30
};
const double duty_tab[4] = { 0.125, 0.25, 0.5, 0.75 };
const U noise_freq_tab[16] = {
    4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068
};
const U dmc_rate_tab[16] = {
    428, 380, 340, 286, 253, 214, 179, 160, 133, 118, 89, 80, 64, 54, 48, 36
};

// 컴파일 오류 방지를 위한 mm 함수 프로토타입 선언
u mm(u l, u h, u v, u w);

// 스윕 타겟 주기 계산 헬퍼
int get_sweep_target(int ch) {
    int change = pulse_period[ch] >> (apu_reg[ch * 4 + 1] & 7);
    if (apu_reg[ch * 4 + 1] & 8) {
        change = (ch == 0) ? -change - 1 : -change;
    }
    return (int)pulse_period[ch] + change;
}

// 5채널 APU 프레임(4 서브프레임) 합성 및 출력
void apu_step_frame() {
    int16_t* out = audio_buf[cur_audio_buf];
    int sample_idx = 0;

    for (int q = 0; q < 4; q++) {
        // [1] Quarter Frame (240Hz): Envelope 및 Triangle 선형 카운터 클럭
        for (int ch = 0; ch < 4; ch++) {
            if (ch == 2) continue;
            u reg = apu_reg[ch * 4];
            if (env_start[ch]) {
                env_start[ch] = 0;
                env_decay[ch] = 15;
                env_div[ch] = reg & 15;
            } else {
                if (env_div[ch] > 0) {
                    env_div[ch]--;
                } else {
                    env_div[ch] = reg & 15;
                    if (env_decay[ch] > 0) {
                        env_decay[ch]--;
                    } else if (reg & 0x20) {
                        env_decay[ch] = 15;
                    }
                }
            }
        }

        if (tri_reload) {
            tri_lin = apu_reg[8] & 0x7F;
        } else if (tri_lin > 0) {
            tri_lin--;
        }
        if (!(apu_reg[8] & 0x80)) {
            tri_reload = 0;
        }

        // [2] Half Frame (120Hz): Length Counter 및 Frequency Sweep 클럭
        if (q & 1) {
            for (int ch = 0; ch < 4; ch++) {
                int halt = (ch == 2) ? (apu_reg[8] & 0x80) : (apu_reg[ch * 4] & 0x20);
                if (!halt && apu_len[ch] > 0) {
                    apu_len[ch]--;
                }
            }

            for (int ch = 0; ch < 2; ch++) {
                u sreg = apu_reg[ch * 4 + 1];
                int target = get_sweep_target(ch);
                int mute = (pulse_period[ch] < 8) || (target > 0x7FF);

                if (sweep_div[ch] == 0 && (sreg & 0x80) && (sreg & 7) > 0 && !mute && apu_len[ch] > 0) {
                    pulse_period[ch] = (U)(target < 0 ? 0 : target);
                }
                if (sweep_div[ch] == 0 || sweep_reload[ch]) {
                    sweep_div[ch] = (sreg >> 4) & 7;
                    sweep_reload[ch] = 0;
                } else {
                    sweep_div[ch]--;
                }
            }
        }

        // [3] 현재 쿼터 프레임 구간 샘플링 (Pulse 1, 2, Triangle, Noise, DMC 통합 믹싱)
        int end_idx = (q + 1) * SAMPLES_PER_FRAME / 4;
        for (; sample_idx < end_idx; sample_idx++) {
            int sample = 0;

            // 1. Pulse 1 & 2
            for (int ch = 0; ch < 2; ch++) {
                if ((apu_reg[21] & (1 << ch)) && apu_len[ch] > 0) {
                    U period = pulse_period[ch];
                    int target = get_sweep_target(ch);
                    if (period >= 8 && target <= 0x7FF) {
                        double freq = 1789773.0 / (16.0 * (period + 1));
                        apu_phase[ch] += freq / SAMPLE_RATE;
                        if (apu_phase[ch] >= 1.0) apu_phase[ch] -= 1.0;

                        int vol = (apu_reg[ch * 4] & 0x10) ? (apu_reg[ch * 4] & 15) : env_decay[ch];
                        double duty = duty_tab[(apu_reg[ch * 4] >> 6) & 3];
                        sample += (apu_phase[ch] < duty ? vol : -vol) * 280;
                    }
                }
            }

            // 2. Triangle
            if ((apu_reg[21] & 4) && apu_len[2] > 0 && tri_lin > 0) {
                U period = ((apu_reg[11] & 7) << 8) | apu_reg[10];
                if (period >= 2) {
                    double freq = 1789773.0 / (32.0 * (period + 1));
                    apu_phase[2] += freq / SAMPLE_RATE;
                    if (apu_phase[2] >= 1.0) apu_phase[2] -= 1.0;

                    int step = (int)(apu_phase[2] * 32.0) & 31;
                    int tri_val = (step < 16) ? (15 - step) : (step - 16);
                    sample += (tri_val - 8) * 350;
                }
            }

            // 3. Noise
            if ((apu_reg[21] & 8) && apu_len[3] > 0) {
                U period = noise_freq_tab[apu_reg[14] & 15];
                double freq = 1789773.0 / period;
                apu_phase[3] += freq / SAMPLE_RATE;
                while (apu_phase[3] >= 1.0) {
                    apu_phase[3] -= 1.0;
                    int shift = (apu_reg[14] & 0x80) ? 6 : 1;
                    U bit = (noise_lfsr ^ (noise_lfsr >> shift)) & 1;
                    noise_lfsr = (noise_lfsr >> 1) | (bit << 14);
                }
                int vol = (apu_reg[12] & 0x10) ? (apu_reg[12] & 15) : env_decay[3];
                if (!(noise_lfsr & 1)) sample += vol * 180;
            }

            // 4. DMC (Delta Modulation Channel - 드럼 및 음성 샘플)
            if (apu_reg[21] & 0x10) {
                U dmc_period = dmc_rate_tab[apu_reg[16] & 15];
                double dmc_freq = 1789773.0 / dmc_period;
                dmc_phase += dmc_freq / SAMPLE_RATE;
                while (dmc_phase >= 1.0) {
                    dmc_phase -= 1.0;
                    if (dmc_bits_left == 0) {
                        dmc_bits_left = 8;
                        if (dmc_buffer_empty) {
                            dmc_shift = 0;
                        } else {
                            dmc_shift = dmc_sample_buffer;
                            dmc_buffer_empty = 1;
                        }
                    }
                    if (dmc_buffer_empty && dmc_curr_len > 0) {
                        dmc_sample_buffer = m(dmc_curr_addr & 0xFF, dmc_curr_addr >> 8);
                        dmc_buffer_empty = 0;
                        dmc_curr_addr++;
                        if (dmc_curr_addr > 0xFFFF) dmc_curr_addr = 0x8000;
                        dmc_curr_len--;
                        if (dmc_curr_len == 0) {
                            if (apu_reg[16] & 0x40) { // Loop 활성화
                                dmc_curr_addr = dmc_addr;
                                dmc_curr_len = dmc_len;
                            }
                        }
                    }
                    if (dmc_bits_left > 0) {
                        if (dmc_shift & 1) {
                            if (dmc_output <= 125) dmc_output += 2;
                        } else {
                            if (dmc_output >= 2) dmc_output -= 2;
                        }
                        dmc_shift >>= 1;
                        dmc_bits_left--;
                    }
                }
                sample += (dmc_output - 64) * 40;
            }

            if (sample > 32767) sample = 32767;
            if (sample < -32768) sample = -32768;
            out[sample_idx] = (int16_t)sample;
        }
    }

    if (waveHdr[cur_audio_buf].dwFlags & WHDR_DONE) {
        waveOutWrite(hWaveOut, &waveHdr[cur_audio_buf], sizeof(WAVEHDR));
        cur_audio_buf = (cur_audio_buf + 1) % AUDIO_BUF_COUNT;
    }
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (msg == WM_DESTROY || msg == WM_CLOSE) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

u* q(U a) { Q& C[M[a >> Mb] << Mb | a % (1 << Mb)]; }
u* nt(U a) { Q& vr[!D ? a % _ : D ^ 1 ? D ^ 2 ? a / 2 & _ | a % _ : a & 2047 : a % _ + _]; }
u mm(u l, u h, u v, u w) {
    U a = h << 8 | l; Z(h >>= 4) {
        x(0, 1)Q + w ? ra[a] = v : ra[a];
        x(2, 3)k((l &= 7) == 7) {
            t = pb; u* E = V < _ * 8 ? w & C != cr ? &t : q(V) : V < 16128 ? nt(V) : Pr + (u)(V & 19 ^ 16 ? V : V ^ 16);
            w ? *E = v : (pb = *E); V += p & 4 ? 32 : 1; V %= 16 * _; Q + t;
        }
        k(w)Z(l) {
            W + 0: T = T & 62463 | v % 4 * _; p = v;
            W + 1: pm = v;
            W + 5: T = (pw ^= 1) ? fx = v & 7, T & ~31 | v / 8 : T & xx | v % 8 << 12 | v * 4 & yy;
            W + 6: T = !(pw ^= 1) ? V = T & ~255 | v : (u)T | v % 64 << 8;
        }k(l == 2)Q t = H & 224, H &= 127, pw = 0, t;
        W + 4: 
        // --- APU 레지스터 ($4000~$4017) 쓰기 및 DMC 트리거 처리 ---
        k(w && l < 24) {
            apu_reg[l] = v;
            Z(l) {
                W + 1: sweep_reload[0] = 1;
                W + 2: pulse_period[0] = (pulse_period[0] & 0x700) | v;
                W + 3: pulse_period[0] = (pulse_period[0] & 0x0FF) | ((v & 7) << 8);
                       if (apu_reg[21] & 1) apu_len[0] = apu_len_tab[v >> 3];
                       env_start[0] = 1;
                W + 5: sweep_reload[1] = 1;
                W + 6: pulse_period[1] = (pulse_period[1] & 0x700) | v;
                W + 7: pulse_period[1] = (pulse_period[1] & 0x0FF) | ((v & 7) << 8);
                       if (apu_reg[21] & 2) apu_len[1] = apu_len_tab[v >> 3];
                       env_start[1] = 1;
                W + 11: if (apu_reg[21] & 4) apu_len[2] = apu_len_tab[v >> 3];
                        tri_reload = 1;
                W + 15: if (apu_reg[21] & 8) apu_len[3] = apu_len_tab[v >> 3];
                        env_start[3] = 1;
                W + 16: break;
                W + 17: dmc_output = v & 0x7F;
                        break;
                W + 18: dmc_addr = 0xC000 + (v * 64);
                        break;
                W + 19: dmc_len = (v * 16) + 1;
                        break;
                W + 21: for (int ch = 0; ch < 4; ch++) if (!(v & (1 << ch))) apu_len[ch] = 0;
                        if (v & 0x10) {
                            if (dmc_curr_len == 0) {
                                dmc_curr_addr = dmc_addr;
                                dmc_curr_len = dmc_len;
                            }
                        } else {
                            dmc_curr_len = 0;
                        }
            }
        }
        k(20 == l && w)for (U f = 256; f--;)oa[f] = m(f, v); for (t = 0, h = 8; h--;)t = t * 2 + kb["\33\35+(RQPO"[h]];
        Q + l == 22 ? w ? ks = t : (t = ks & 1, ks /= 2, t) : (l == 21 && !w ? (apu_len[0] > 0) | ((apu_len[1] > 0) << 1) | ((apu_len[2] > 0) << 2) | ((apu_len[3] > 0) << 3) | ((dmc_curr_len > 0) << 4) : 0);
        x(6, 7)a &= 8191; Q w ? pr[a] = v : pr[a];
        BD k(w)Z(b[6] >> 4) {
            W + 7: D = !(v / 16); K[1] = (*K = v % 8 * 2) + 1;
            W + 4: w = a & 1; Z(h >> 1) {
                W + 4: *(w ? &S[MB & 7] : &MB) = v; t = MB >> 5 & 4; for (l = 4; l--;)M[l + t] = S[l / 2] & ~!(l % 2) | l % 2, M[4 + l - t] = S[2 + l];
                K[t = MB / 32 & 2] = S[6]; K[1] = S[7]; K[2 - t] = (K[3] = b[4] * 2 - 1) - 1;
                W + 5: k(!w)D = 2 + v % 2;
                W + 6: k(!w)ML = v;
                W + 7: MI = w;
            }
            W + 3: M[1] = (*M = v % 4 * 2) + 1;
            W + 2: *K = v & 31;
            W + 1: v & 128 ? F = 0, mb = 5, I |= 12 : (F = F / 2 | v << 4 & 16, !--mb) ? t = a >> 13, *(t == 4 ? D = F & 3, &I : t ^ 5 ? t ^ 6 ? &J : &c1 : &c0) = F, mb = 5, *M = c0 & ~!(I & 16), M[1] = I & 16 ? c1 : c0 | 1, t = I / 4 % 4 - 2, *K = !t ? 0 : t ^ 1 ? J & ~1 : J, K[1] = !t ? J : t ^ 1 ? J | 1 : b[4] - 1 : 0;
        }Q + E[(K[h - 8 >> e - 12] & (b[4] << 14 - e) - 1) << e | a % (1 << e)];
    }Q ~0;
}

u R() { v = m(l, h); !++l && ++h; Q + v; }
u n(u v) { Q P = P & 125 | v & 128 | !v * 2; }

// 표준 NES 64색 BGR565 팔레트 테이블
const uint32_t standard_nes_palette[64] = {
    25356, 34816, 39011, 30854, 24714, 4107,  106,   2311,
    2468,  2561,  4642,  6592,  20832, 0,     0,     0,
    44373, 49761, 55593, 51341, 43186, 18675, 434,   654,
    4939,  5058,  3074,  19362, 37667, 0,     0,     0,
    ~0,    ~819,  64497, 64342, 62331, 43932, 23612, 9465,
    1429,  1550,  20075, 36358, 52713, 16904, 0,     0,
    ~0,    ~328,  ~422,  ~452,  ~482,  58911, 50814, 42620,
    40667, 40729, 48951, 53078, 61238, 44405
};

int main(int w, char** av) {
    if (w < 2) return 0;
    FILE* romFile = fopen(av[1], "rb");
    if (!romFile) return 0;
    fread(b, 1, _ * _, romFile);
    fclose(romFile);

    // --- Win32 창 및 768x672 DIBSection 초기화 ---
    WNDCLASSA wc = { 0 };
    wc.lpfnWndProc = WndProc;
    wc.hInstance = GetModuleHandle(NULL);
    wc.lpszClassName = "smolnes";
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    RegisterClassA(&wc);

    DWORD style = WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX;
    RECT rect = { 0, 0, 256 * 3, 224 * 3 };
    AdjustWindowRect(&rect, style, FALSE);

    hwnd = CreateWindowA("smolnes", "smolnes (256x224) - 60.0 FPS",
        style | WS_VISIBLE,
        CW_USEDEFAULT, CW_USEDEFAULT,
        rect.right - rect.left, rect.bottom - rect.top,
        NULL, NULL, wc.hInstance, NULL);

    hdc_win = GetDC(hwnd);
    hdc_mem = CreateCompatibleDC(hdc_win);

    struct {
        BITMAPINFOHEADER bmiHeader;
        DWORD masks[3];
    } bmi = { 0 };

    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = 256;
    bmi.bmiHeader.biHeight = -224; // Top-down DIB
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 16;
    bmi.bmiHeader.biCompression = BI_BITFIELDS;
    bmi.masks[0] = 0x001F; // Red
    bmi.masks[1] = 0x07E0; // Green
    bmi.masks[2] = 0xF800; // Blue

    hbm_dib = CreateDIBSection(hdc_win, (BITMAPINFO*)&bmi, DIB_RGB_COLORS, (void**)&dib_pixels, NULL, 0);
    SelectObject(hdc_mem, hbm_dib);

    // --- Win32 waveOut 오디오 초기화 ---
    WAVEFORMATEX wfx = { WAVE_FORMAT_PCM, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16, 0 };
    waveOutOpen(&hWaveOut, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);
    for (int idx = 0; idx < AUDIO_BUF_COUNT; idx++) {
        waveHdr[idx].lpData = (LPSTR)audio_buf[idx];
        waveHdr[idx].dwBufferLength = SAMPLES_PER_FRAME * sizeof(int16_t);
        waveOutPrepareHeader(hWaveOut, &waveHdr[idx], sizeof(WAVEHDR));
        waveHdr[idx].dwFlags |= WHDR_DONE;
    }

    // --- 고해상도 Waitable Timer 및 측정 변수 초기화 ---
    HANDLE hTimer = CreateWaitableTimerExA(NULL, NULL, 0x00000002, TIMER_ALL_ACCESS);
    if (!hTimer) {
        hTimer = CreateWaitableTimerA(NULL, FALSE, NULL);
    }

    LARGE_INTEGER freq, last_time, curr_time, fps_time;
    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&last_time);
    fps_time = last_time;
    int frame_count = 0;
    const LONGLONG target_ticks = freq.QuadPart / 60;

    E = b + 16; K[1] = (t = b[4]) - 1; C = (h = b[5]) ? E + (t << 14) : cr; M[1] = h ? h * 2 - 1 : 1; D = 3 - b[6] % 2;
    k(4 == b[6] / 16)mm(0, +128, 0, 1), Mb -= 2, e--; l = m(~3, ~0); h = m(~2, ~0); w = 0;

    static u win_kb[256];
    kb = win_kb;
  
Y: c = L = 0; k(N)G N; Z(f = 31 & (o = R())) {
    W + 0: k(o & 128) { R(); L = 1; G n; } Z(o >> 5) {
        W + 0: !++l && ++h; N: g(h)g(l)g(P | 32)l = m(N = ~1 - (N & 4), ~0); h = m(N + 1, ~0); N = 0; c++;
        W + 1: r = R(); g(h)g(l)h = R(); l = r;
        W + 2: P = z & ~32; l = z; h = z;
        W + 3: l = z; h = z; !++l && ++h;
    }c += 4;
    W + 16: R(); k(!(P & bm[o >> 6]) ^ o / 32 & 1)r = l + (int8_t)v >> 8, h += r, l += v, c += r ? 2 : 1;
    W - 1: x(8, 24)Z(o >>= 4) {
        W + 0: g(P | 48) c++;
        W + 2: P = z & ~16; c += 2;
        W + 4: g(A) c++;
        W + 6: n(A = z); c += 2;
        W + 8: n(--Y);
        W + 9: n(A = Y);
        W + 10: n(Y = A);
        W + 12: n(++Y);;
        W + 14: n(++X); BD P = P & ~bm[o + 3] | bm[o + 4];
    }
    W - 2: x(10, 26)Z(o >> 4) {
        W + 8: n(A = X);
        W + 9: St = X;
        W + 10: n(X = A);
        W + 11: n(X = St);
        W + 12: n(--X);
        W + 14: BD L = 1; v = A; G n;
    }
    W + 1: R(); i = m(v += X, 0); j = m(v + 1, 0); c += 4; G o;
    x(2, 9)R(); L = 1; G n;;
    W + 17: i = m(R(), 0); j = m(v + 1, 0); c++; G A;
    x(4, 5)x(6, 20)x(21, 22) i = R(); k(r = f > 6) i += 150 ^ 214 & o ? X : Y; j = 0; c -= !r; G o;
    W + 12: x(13, 14)x(25, 28)x(29, +30)i = R(); j = R(); k(f < 25) G o; A: v = f < 28 || 190 == o ? Y : X;
    j += r = i + v > +255; i += v; c = c + (128 == (o & 224) || o != 190 & o % 16 == 14) | r; o: c += 2; k(o ^ 76 && o & 224 ^ 128)v = m(i, j);
n: r = 0; Z(o & 227) {
    W + 1: n(A |= v);
    W + 33: n(A &= v);
    W + 65: n(A ^= v);
    W + 225: v = ~v;
    x(-1, 97) f = A + v + P % 2; P = P & ~65 | f > 255 | ((A ^ f) & 128 & (v ^ f)) / 2; n(A = f);
    W + 34: r = P & 1;
    x(2, -2)r |= v * 2; P = P & ~1 | v >> 7;; G m;
    W + 98: r = P << 7;
    x(66, -3)r |= v / 2; P = P & ~1 | v & 1; G m;
    W + 194: r = v - 1; G m;
    W + 226: r = v + 1;
m: n(r); L ? A = r : (c += 2, mm(i, j, r, 1));
    W + 32: P = P & 61 | 192 & v | !(A & v) * 2;
    W + 64: l = i; h = j; c--;;
    W + 96: l = v; h = m(i + 1, j); c++;
    BD{ f = o / 32; u* e = o % 4 ^ 2 && f ^ 7 ? o % 4 ^ 1 ? &Y : &A : &X; f ^ 4 ? f ^ 5 ? P = P & ~1 | v <= *e, n(*e - v) : n(*e = v) : +mm(i, j, *e, 1); }
}
}
for (t = c * 3 + 6; t--;) {
    k(+pm & +24) {
        k(y < 240) {
            k(-256 + d > +63u) {
                k(d < 256) {
                    u C = a >> 14 - fx & 2 | s >> 15 - fx & 1, P = w >> 28 - fx * 2 & 12,
                        T[] = "1%(+/0/,)&'%%%%%:&.278730'''(%%%D16;@AA>:30+.-%%D<>@BDCA@><;;:%%=%(\"\"%(-\"25630%%\"%O8.)*,29?CEB>%%%dKD?@AFLQUXUT5%%dZWVUUXX[]^_^P%%16841'%&&&'(/%%%:=@>:.%%''&.7%%%DDDDC:0)%%.6>-%%DDDDDA=988<>B:%%"; 
                    k(pm & 16)for (u* s = oa; s < oa + 256; s += 4) {
                        U h = p & 32 ? 16 : 8, X = d - s[3], Y = y - s[0] - 1; k(X < 8 & Y < h) {
                            U t = s[1], r = s[2], i = X ^ !(r & 64) * 7, j = Y ^ (r & 128 ? h - 1 : 0), a = (p & 32 ? t % 2 << 12 | t << 4 & -32 | j * 2 & 16 : (p & 8) << 9 | t << 4) | j & 7, c = *q(a + 8) >> i << 1 & 2 | *q(a) >> i & 1; k(c) { C && 32 & r ? 0 : (C = c, P = 16 | r * 4 & 12); C&& s == oa ? H |= 64 : 0; G X; }
                        }
                    }X: C = Pr[C ? P | C : 0];
                    fb[y * 256 + d] = C & 63;
                }k(d < 336)a *= 2, s *= 2, w *= 4; f = V >> 12 | p << 8 & _ * 4 | nb << 4; Z(d & 7) {
                    W + 1: nb = *nt(V);
                    W + 3: at = (*nt(V & 3072 | V >> 4 & 56 | 960 | V / 4 & 7) >> (V >> 5 & 2 | V / 2 & 1) * 2) % 4 * 21845;
                    W + 5: pl = *q(f);
                    W + 7: V = V % 32 ^ 31 ? V + 1 : V & ~31 ^ _; s |= pl, a |= *q(f | 8), w |= at;
                }
            }k(d == 256)V = (V >> 12 & 7 ^ 7 ? V + 4 * _ : V & yy ^ 928 ? V & yy ^ yy ? V & xx | V + 32 & yy : V & xx : V & xx ^ 2 * _) & ~1055 | T & 1055;
        }k((y + 1) % 262 < 241 & d == 261 & MI && !ML--)N = 1; k(y == 261 & 25u > d - 280)V = V & 33823 | T & 31712;
    }
    k(d == 1) {
        k(y == 241) {
            k(p & 128)N = 4; H |= 128;        
            for (int i = 0; i < 256 * 224; i++) {
                uint8_t pal_idx = fb[i + _ * 2] & 63;
                dib_pixels[i] = standard_nes_palette[pal_idx];
            }
             
            RECT rc;
            GetClientRect(hwnd, &rc);
            StretchBlt(hdc_win, 0, 0, rc.right, rc.bottom, hdc_mem, 0, 0, 256, 224, SRCCOPY);

            // --- 5채널 APU 프레임 합성 및 출력 ---
            apu_step_frame();

            MSG msg;
            while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_QUIT) {
                    waveOutReset(hWaveOut);
                    waveOutClose(hWaveOut);
                    CloseHandle(hTimer);
                    Q + 0;
                }
                TranslateMessage(&msg);
                DispatchMessage(&msg);
            }
            win_kb[27] = (GetAsyncKeyState('X') & 0x8000) != 0;
            win_kb[29] = (GetAsyncKeyState('Z') & 0x8000) != 0;
            win_kb[43] = (GetAsyncKeyState(VK_TAB) & 0x8000) != 0;
            win_kb[40] = (GetAsyncKeyState(VK_RETURN) & 0x8000) != 0;
            win_kb[82] = (GetAsyncKeyState(VK_UP) & 0x8000) != 0;
            win_kb[81] = (GetAsyncKeyState(VK_DOWN) & 0x8000) != 0;
            win_kb[80] = (GetAsyncKeyState(VK_LEFT) & 0x8000) != 0;
            win_kb[79] = (GetAsyncKeyState(VK_RIGHT) & 0x8000) != 0;

            // --- WaitableTimer 기반 60FPS 고정 ---
            QueryPerformanceCounter(&curr_time);
            LONGLONG remain_ticks = target_ticks - (curr_time.QuadPart - last_time.QuadPart);

            if (remain_ticks > 0) {
                LONGLONG wait_100ns = (remain_ticks * 10000000LL / freq.QuadPart) - 5000;
                if (wait_100ns > 5000) {
                    LARGE_INTEGER due_time;
                    due_time.QuadPart = -wait_100ns;
                    SetWaitableTimer(hTimer, &due_time, 0, NULL, NULL, FALSE);
                    WaitForSingleObject(hTimer, INFINITE);
                }
                do {
                    YieldProcessor();
                    QueryPerformanceCounter(&curr_time);
                } while (curr_time.QuadPart - last_time.QuadPart < target_ticks);
            }

            last_time.QuadPart += target_ticks;
            if (curr_time.QuadPart - last_time.QuadPart > freq.QuadPart / 10) {
                last_time = curr_time;
            }

            frame_count++;
            if (curr_time.QuadPart - fps_time.QuadPart >= freq.QuadPart) {
                double fps = (double)frame_count * freq.QuadPart / (curr_time.QuadPart - fps_time.QuadPart);
                char title[64];
                snprintf(title, sizeof(title), "smolnes (256x224) - %.1f FPS", fps);
                SetWindowTextA(hwnd, title);
                frame_count = 0;
                fps_time = curr_time;
            }
        }k(y == 261)H = 0;
    }k(++d == 341)d = 0, y++, y %= 262;
}G Y;
}