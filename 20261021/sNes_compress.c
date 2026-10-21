#include <windows.h>
#include <mmsystem.h>
#include <stdio.h>
#include <stdint.h>

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
char sf[MAX_PATH];

#define SR 44100
#define SPF (SR / 60)
#define ABC 4

HWAVEOUT hWO;
WAVEHDR WH[ABC];
int16_t AB[ABC][SPF];
int CAB = 0, ar[24], al[4], pp[2], es[4], ed[4], ediv[4], sr[2], sdiv[2], tlin, trel, daddr = 0xC000, dlen = 1, dcaddr = 0xC000, dclen = 0;
u dshift = 0, dbits = 0, dsbuf = 0, dbemp = 1;
int dout = 0;
double dph = 0, aph[4];
U nlfsr = 1; // 정수형으로 정확히 분리 선언

const u alt[32] = { 10,254,20,2,40,4,80,6,160,8,60,10,14,12,26,14,12,16,24,18,48,20,96,22,192,24,72,26,16,28,32,30 };
const double dt[4] = { 0.125, 0.25, 0.5, 0.75 };
const U nft[16] = { 4,8,16,32,64,96,128,160,202,254,380,508,762,1016,2034,4068 };
const U drt[16] = { 428,380,340,286,253,214,179,160,133,118,89,80,64,54,48,36 };

u mm(u l, u h, u v, u w);
void ls() { FILE* f = fopen(sf, "rb"); k(f) { fread(pr, 1, 8192, f); fclose(f); } }
void ss() { FILE* f = fopen(sf, "wb"); k(f) { fwrite(pr, 1, 8192, f); fclose(f); } }
int gst(int ch) { int c = pp[ch] >> (ar[ch * 4 + 1] & 7); k(ar[ch * 4 + 1] & 8) c = (ch == 0) ? -c - 1 : -c; Q(int)pp[ch] + c; }

void apu() {
    int16_t* out = AB[CAB];
    int si = 0;
    for (int q = 0; q < 4; q++) {
        for (int ch = 0; ch < 4; ch++) {
            k(ch != 2) {
                u reg = ar[ch * 4];
                k(es[ch]) { es[ch] = 0; ed[ch] = 15; ediv[ch] = reg & 15; }
                else k(ediv[ch] > 0) ediv[ch]--;
                else { ediv[ch] = reg & 15; k(ed[ch] > 0) ed[ch]--; else k(reg & 0x20) ed[ch] = 15; }
            }
        }
        k(trel) tlin = ar[8] & 0x7F; else k(tlin > 0) tlin--;
        k(!(ar[8] & 0x80)) trel = 0;

        k(q & 1) {
            for (int ch = 0; ch < 4; ch++) {
                int hlt = (ch == 2) ? (ar[8] & 0x80) : (ar[ch * 4] & 0x20);
                k(!hlt && al[ch] > 0) al[ch]--;
            }
            for (int ch = 0; ch < 2; ch++) {
                u sreg = ar[ch * 4 + 1];
                int tgt = gst(ch), mut = (pp[ch] < 8) || (tgt > 0x7FF);
                k(sdiv[ch] == 0 && (sreg & 0x80) && (sreg & 7) > 0 && !mut && al[ch] > 0) pp[ch] = (U)(tgt < 0 ? 0 : tgt);
                k(sdiv[ch] == 0 || sr[ch]) { sdiv[ch] = (sreg >> 4) & 7; sr[ch] = 0; } else sdiv[ch]--;
            }
        }

        int ei = (q + 1) * SPF / 4;
        for (; si < ei; si++) {
            int smp = 0;
            for (int ch = 0; ch < 2; ch++) {
                k((ar[21] & (1 << ch)) && al[ch] > 0) {
                    U per = pp[ch]; int tgt = gst(ch);
                    k(per >= 8 && tgt <= 0x7FF) {
                        double frq = 1789773.0 / (16.0 * (per + 1));
                        aph[ch] += frq / SR; k(aph[ch] >= 1.0) aph[ch] -= 1.0;
                        int vol = (ar[ch * 4] & 0x10) ? (ar[ch * 4] & 15) : ed[ch];
                        smp += (aph[ch] < dt[(ar[ch * 4] >> 6) & 3] ? vol : -vol) * 280;
                    }
                }
            }
            k((ar[21] & 4) && al[2] > 0 && tlin > 0) {
                U per = ((ar[11] & 7) << 8) | ar[10];
                k(per >= 2) {
                    double frq = 1789773.0 / (32.0 * (per + 1));
                    aph[2] += frq / SR; k(aph[2] >= 1.0) aph[2] -= 1.0;
                    int stp = (int)(aph[2] * 32.0) & 31;
                    smp += ((stp < 16 ? 15 - stp : stp - 16) - 8) * 350;
                }
            }
            k((ar[21] & 8) && al[3] > 0) {
                U per = nft[ar[14] & 15];
                double frq = 1789773.0 / per;
                aph[3] += frq / SR;
                while (aph[3] >= 1.0) { aph[3] -= 1.0; U bit = (nlfsr ^ (nlfsr >> ((ar[14] & 0x80) ? 6 : 1))) & 1; nlfsr = (nlfsr >> 1) | (bit << 14); }
                int vol = (ar[12] & 0x10) ? (ar[12] & 15) : ed[3];
                k(!(nlfsr & 1)) smp += vol * 180;
            }
            k(ar[21] & 0x10) {
                double dfrq = 1789773.0 / drt[ar[16] & 15];
                dph += dfrq / SR;
                while (dph >= 1.0) {
                    dph -= 1.0;
                    k(dbits == 0) { dbits = 8; k(dbemp) dshift = 0; else { dshift = dsbuf; dbemp = 1; } }
                    k(dbemp && dclen > 0) { dsbuf = m(dcaddr & 0xFF, dcaddr >> 8); dbemp = 0; dcaddr = (dcaddr + 1) > 0xFFFF ? 0x8000 : dcaddr + 1; dclen--; k(dclen == 0 && (ar[16] & 0x40)) { dcaddr = daddr; dclen = dlen; } }
                    k(dbits > 0) { k(dshift & 1) k(dout <= 125) dout += 2; else k(dout >= 2) dout -= 2; dshift >>= 1; dbits--; }
                }
                smp += (dout - 64) * 40;
            }
            k(smp > 32767) smp = 32767; k(smp < -32768) smp = -32768;
            out[si] = (int16_t)smp;
        }
    }
    k(WH[CAB].dwFlags & WHDR_DONE) { waveOutWrite(hWO, &WH[CAB], sizeof(WAVEHDR)); CAB = (CAB + 1) % ABC; }
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    k(msg == WM_DESTROY || msg == WM_CLOSE) { ss(); PostQuitMessage(0); Q 0; }
    Q DefWindowProc(hwnd, msg, wParam, lParam);
}

u* q(U a) { Q &C[M[a >> Mb] << Mb | a % (1 << Mb)]; }
u* nt(U a) { Q &vr[!D ? a % _ : D ^ 1 ? D ^ 2 ? a / 2 & _ | a % _ : a & 2047 : a % _ + _]; }
u mm(u l, u h, u v, u w) {
    U a = h << 8 | l; Z(h >>= 4) {
        x(0, 1) Q +w ? ra[a] = v : ra[a];
        x(2, 3) k((l &= 7) == 7) {
            t = pb; u* E = V < _ * 8 ? w & C != cr ? &t : q(V) : V < 16128 ? nt(V) : Pr + (u)(V & 19 ^ 16 ? V : V ^ 16);
            w ? *E = v : (pb = *E); V += p & 4 ? 32 : 1; V %= 16 * _; Q +t;
        }
        k(w) Z(l) {
            W +0: T = T & 62463 | v % 4 * _; p = v;
            W +1: pm = v;
            W +5: T = (pw ^= 1) ? fx = v & 7, T & ~31 | v / 8 : T & xx | v % 8 << 12 | v * 4 & yy;
            W +6: T = !(pw ^= 1) ? V = T & ~255 | v : (u)T | v % 64 << 8;
        } k(l == 2) Q t = H & 224, H &= 127, pw = 0, t;
        W +4:
        k(w && l < 24) {
            ar[l] = v;
            Z(l) {
                W +1: sdiv[0] = 1;
                W +2: pp[0] = (pp[0] & 0x700) | v;
                W +3: pp[0] = (pp[0] & 0x0FF) | ((v & 7) << 8); k(ar[21] & 1) al[0] = alt[v >> 3]; es[0] = 1;
                W +5: sdiv[1] = 1;
                W +6: pp[1] = (pp[1] & 0x700) | v;
                W +7: pp[1] = (pp[1] & 0x0FF) | ((v & 7) << 8); k(ar[21] & 2) al[1] = alt[v >> 3]; es[1] = 1;
                W +11: k(ar[21] & 4) al[2] = alt[v >> 3]; trel = 1;
                W +15: k(ar[21] & 8) al[3] = alt[v >> 3]; es[3] = 1;
                W +17: dout = v & 0x7F; break;
                W +18: daddr = 0xC000 + (v * 64); break;
                W +19: dlen = (v * 16) + 1; break;
                W +21: for (int ch = 0; ch < 4; ch++) k(!(v & (1 << ch))) al[ch] = 0; k(v & 0x10) { k(dclen == 0) { dcaddr = daddr; dclen = dlen; } } else dclen = 0;
            }
        }
        k(20 == l && w) for (U f = 256; f--;) oa[f] = m(f, v); for (t = 0, h = 8; h--;) t = t * 2 + kb["\33\35+(RQPO"[h]];
        Q +l == 22 ? w ? ks = t : (t = ks & 1, ks /= 2, t) : (l == 21 && !w ? (al[0] > 0) | ((al[1] > 0) << 1) | ((al[2] > 0) << 2) | ((al[3] > 0) << 3) | ((dclen > 0) << 4) : 0);
        x(6, 7) a &= 8191; Q w ? pr[a] = v : pr[a];
        BD k(w) Z(b[6] >> 4) {
            W +7: D = !(v / 16); K[1] = (*K = v % 8 * 2) + 1;
            W +4: w = a & 1; Z(h >> 1) {
                W +4: *(w ? &S[MB & 7] : &MB) = v; t = MB >> 5 & 4; for (l = 4; l--;) M[l + t] = S[l / 2] & ~!(l % 2) | l % 2, M[4 + l - t] = S[2 + l];
                K[t = MB / 32 & 2] = S[6]; K[1] = S[7]; K[2 - t] = (K[3] = b[4] * 2 - 1) - 1;
                W +5: k(!w) D = 2 + v % 2;
                W +6: k(!w) ML = v;
                W +7: MI = w;
            }
            W +3: M[1] = (*M = v % 4 * 2) + 1;
            W +2: *K = v & 31;
            W +1: v & 128 ? F = 0, mb = 5, I |= 12 : (F = F / 2 | v << 4 & 16, !--mb) ? t = a >> 13, *(t == 4 ? D = F & 3, &I : t ^ 5 ? t ^ 6 ? &J : &c1 : &c0) = F, mb = 5, *M = c0 & ~!(I & 16), M[1] = I & 16 ? c1 : c0 | 1, t = I / 4 % 4 - 2, *K = !t ? 0 : t ^ 1 ? J & ~1 : J, K[1] = !t ? J : t ^ 1 ? J | 1 : b[4] - 1 : 0;
        } Q +E[(K[h - 8 >> e - 12] & (b[4] << 14 - e) - 1) << e | a % (1 << e)];
    } Q ~0;
}

u R() { v = m(l, h); !++l && ++h; Q +v; }
u n(u v) { Q P = P & 125 | v & 128 | !v * 2; }

const uint32_t np[64] = {
    25356,34816,39011,30854,24714,4107,106,2311,2468,2561,4642,6592,20832,0,0,0,
    44373,49761,55593,51341,43186,18675,434,654,4939,5058,3074,19362,37667,0,0,0,
    ~0,~819,64497,64342,62331,43932,23612,9465,1429,1550,20075,36358,52713,16904,0,0,
    ~0,~328,~422,~452,~482,58911,50814,42620,40667,40729,48951,53078,61238,44405
};

int main(int w, char** av) {
    k(w < 2) Q 0;
    snprintf(sf, sizeof(sf), "%s", av[1]);
    char* ext = strrchr(sf, '.'); k(ext) strcpy(ext, ".sav"); else strcat(sf, ".sav");

    FILE* rf = fopen(av[1], "rb"); k(!rf) Q 0; fread(b, 1, _ * _, rf); fclose(rf);
    ls();

    WNDCLASSA wc = { 0 }; wc.lpfnWndProc = WndProc; wc.hInstance = GetModuleHandle(NULL); wc.lpszClassName = "smolnes"; wc.hCursor = LoadCursor(NULL, IDC_ARROW); RegisterClassA(&wc);
    DWORD st = WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX;
    RECT rc = { 0, 0, 256 * 3, 224 * 3 }; AdjustWindowRect(&rc, st, FALSE);
    hwnd = CreateWindowA("smolnes", "smolnes (256x224) - 60.0 FPS", st | WS_VISIBLE, CW_USEDEFAULT, CW_USEDEFAULT, rc.right - rc.left, rc.bottom - rc.top, NULL, NULL, wc.hInstance, NULL);

    hdc_win = GetDC(hwnd); hdc_mem = CreateCompatibleDC(hdc_win);
    struct { BITMAPINFOHEADER bmiHeader; DWORD masks[3]; } bmi = { 0 };
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER); bmi.bmiHeader.biWidth = 256; bmi.bmiHeader.biHeight = -224; bmi.bmiHeader.biPlanes = 1; bmi.bmiHeader.biBitCount = 16; bmi.bmiHeader.biCompression = BI_BITFIELDS;
    bmi.masks[0] = 0x001F; bmi.masks[1] = 0x07E0; bmi.masks[2] = 0xF800;
    hbm_dib = CreateDIBSection(hdc_win, (BITMAPINFO*)&bmi, DIB_RGB_COLORS, (void**)&dib_pixels, NULL, 0);
    SelectObject(hdc_mem, hbm_dib);

    WAVEFORMATEX wfx = { WAVE_FORMAT_PCM, 1, SR, SR * 2, 2, 16, 0 };
    waveOutOpen(&hWO, WAVE_MAPPER, &wfx, 0, 0, CALLBACK_NULL);
    for (int i = 0; i < ABC; i++) { WH[i].lpData = (LPSTR)AB[i]; WH[i].dwBufferLength = SPF * sizeof(int16_t); waveOutPrepareHeader(hWO, &WH[i], sizeof(WAVEHDR)); WH[i].dwFlags |= WHDR_DONE; }

    HANDLE hTimer = CreateWaitableTimerExA(NULL, NULL, 0x00000002, TIMER_ALL_ACCESS);
    k(!hTimer) hTimer = CreateWaitableTimerA(NULL, FALSE, NULL);

    LARGE_INTEGER freq, lt, ct, ft; QueryPerformanceFrequency(&freq); QueryPerformanceCounter(&lt); ft = lt;
    int fc = 0; const LONGLONG tt = freq.QuadPart / 60;

    E = b + 16; K[1] = (t = b[4]) - 1; C = (h = b[5]) ? E + (t << 14) : cr; M[1] = h ? h * 2 - 1 : 1; D = 3 - b[6] % 2;
    k(4 == b[6] / 16) mm(0, +128, 0, 1), Mb -= 2, e--; l = m(~3, ~0); h = m(~2, ~0); w = 0;
    static u wkb[256]; kb = wkb;

Y: c = L = 0; k(N) G N; Z(f = 31 & (o = R())) {
    W +0: k(o & 128) { R(); L = 1; G n; } Z(o >> 5) {
        W +0: !++l && ++h; N: g(h) g(l) g(P | 32) l = m(N = ~1 - (N & 4), ~0); h = m(N + 1, ~0); N = 0; c++;
        W +1: r = R(); g(h) g(l) h = R(); l = r;
        W +2: P = z & ~32; l = z; h = z;
        W +3: l = z; h = z; !++l && ++h;
    } c += 4;
    W +16: R(); k(!(P & bm[o >> 6]) ^ o / 32 & 1) r = l + (int8_t)v >> 8, h += r, l += v, c += r ? 2 : 1;
    W - 1: x(8, 24) Z(o >>= 4) {
        W +0: g(P | 48) c++;
        W +2: P = z & ~16; c += 2;
        W +4: g(A) c++;
        W +6: n(A = z); c += 2;
        W +8: n(--Y);
        W +9: n(A = Y);
        W +10: n(Y = A);
        W +12: n(++Y);;
        W +14: n(++X); BD P = P & ~bm[o + 3] | bm[o + 4];
    }
    W - 2: x(10, 26) Z(o >> 4) {
        W +8: n(A = X);
        W +9: St = X;
        W +10: n(X = A);
        W +11: n(X = St);
        W +12: n(--X);
        W +14: BD L = 1; v = A; G n;
    }
    W +1: R(); i = m(v += X, 0); j = m(v + 1, 0); c += 4; G o;
    x(2, 9) R(); L = 1; G n;;
    W +17: i = m(R(), 0); j = m(v + 1, 0); c++; G A;
    x(4, 5) x(6, 20) x(21, 22) i = R(); k(r = f > 6) i += 150 ^ 214 & o ? X : Y; j = 0; c -= !r; G o;
    W +12: x(13, 14) x(25, 28) x(29, +30) i = R(); j = R(); k(f < 25) G o; A: v = f < 28 || 190 == o ? Y : X;
    j += r = i + v > +255; i += v; c = c + (128 == (o & 224) || o != 190 & o % 16 == 14) | r; o: c += 2; k(o ^ 76 && o & 224 ^ 128) v = m(i, j);
n: r = 0; Z(o & 227) {
    W +1: n(A |= v);
    W +33: n(A &= v);
    W +65: n(A ^= v);
    W +225: v = ~v;
    x(-1, 97) f = A + v + P % 2; P = P & ~65 | f > 255 | ((A ^ f) & 128 & (v ^ f)) / 2; n(A = f);
    W +34: r = P & 1;
    x(2, -2) r |= v * 2; P = P & ~1 | v >> 7;; G m;
    W +98: r = P << 7;
    x(66, -3) r |= v / 2; P = P & ~1 | v & 1; G m;
    W +194: r = v - 1; G m;
    W +226: r = v + 1;
m: n(r); L ? A = r : (c += 2, mm(i, j, r, 1));
    W +32: P = P & 61 | 192 & v | !(A & v) * 2;
    W +64: l = i; h = j; c--;;
    W +96: l = v; h = m(i + 1, j); c++;
    BD { f = o / 32; u* e = o % 4 ^ 2 && f ^ 7 ? o % 4 ^ 1 ? &Y : &A : &X; f ^ 4 ? f ^ 5 ? P = P & ~1 | v <= *e, n(*e - v) : n(*e = v) : +mm(i, j, *e, 1); }
}
}
for (t = c * 3 + 6; t--;) {
    k(+pm & +24) {
        k(y < 240) {
            k(-256 + d > +63u) {
                k(d < 256) {
                    u C = a >> 14 - fx & 2 | s >> 15 - fx & 1, P = w >> 28 - fx * 2 & 12,
                    T[] = "1%(+/0/,)&'%%%%%:&.278730'''(%%%D16;@AA>:30+.-%%D<>@BDCA@><;;:%%=%(\"\"%(-\"25630%%\"%O8.)*,29?CEB>%%%dKD?@AFLQUXUT5%%dZWVUUXX[]^_^P%%16841'%&&&'(/%%%:=@>:.%%''&.7%%%DDDDC:0)%%.6>-%%DDDDDA=988<>B:%%";
                    k(pm & 16) for (u* s = oa; s < oa + 256; s += 4) {
                        U h = p & 32 ? 16 : 8, X = d - s[3], Y = y - s[0] - 1; k(X < 8 & Y < h) {
                            U t = s[1], r = s[2], i = X ^ !(r & 64) * 7, j = Y ^ (r & 128 ? h - 1 : 0), a = (p & 32 ? t % 2 << 12 | t << 4 & -32 | j * 2 & 16 : (p & 8) << 9 | t << 4) | j & 7, c = *q(a + 8) >> i << 1 & 2 | *q(a) >> i & 1; k(c) { C && 32 & r ? 0 : (C = c, P = 16 | r * 4 & 12); C&& s == oa ? H |= 64 : 0; G X; }
                        }
                    } X: C = Pr[C ? P | C : 0];
                    fb[y * 256 + d] = C & 63;
                } k(d < 336) a *= 2, s *= 2, w *= 4; f = V >> 12 | p << 8 & _ * 4 | nb << 4; Z(d & 7) {
                    W +1: nb = *nt(V);
                    W +3: at = (*nt(V & 3072 | V >> 4 & 56 | 960 | V / 4 & 7) >> (V >> 5 & 2 | V / 2 & 1) * 2) % 4 * 21845;
                    W +5: pl = *q(f);
                    W +7: V = V % 32 ^ 31 ? V + 1 : V & ~31 ^ _; s |= pl, a |= *q(f | 8), w |= at;
                }
            } k(d == 256) V = (V >> 12 & 7 ^ 7 ? V + 4 * _ : V & yy ^ 928 ? V & yy ^ yy ? V & xx | V + 32 & yy : V & xx : V & xx ^ 2 * _) & ~1055 | T & 1055;
        } k((y + 1) % 262 < 241 & d == 261 & MI && !ML--) N = 1; k(y == 261 & 25u > d - 280) V = V & 33823 | T & 31712;
    }
    k(d == 1) {
        k(y == 241) {
            k(p & 128) N = 4; H |= 128;
            for (int i = 0; i < 256 * 224; i++) dib_pixels[i] = np[fb[i + _ * 2] & 63];
            RECT rc; GetClientRect(hwnd, &rc); StretchBlt(hdc_win, 0, 0, rc.right, rc.bottom, hdc_mem, 0, 0, 256, 224, SRCCOPY);
            
            apu();

            MSG msg; while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                k(msg.message == WM_QUIT) { ss(); waveOutReset(hWO); waveOutClose(hWO); CloseHandle(hTimer); Q +0; }
                TranslateMessage(&msg); DispatchMessage(&msg);
            }
            wkb[27] = (GetAsyncKeyState('X') & 0x8000) != 0;
            wkb[29] = (GetAsyncKeyState('Z') & 0x8000) != 0;
            wkb[43] = (GetAsyncKeyState(VK_TAB) & 0x8000) != 0;
            wkb[40] = (GetAsyncKeyState(VK_RETURN) & 0x8000) != 0;
            wkb[82] = (GetAsyncKeyState(VK_UP) & 0x8000) != 0;
            wkb[81] = (GetAsyncKeyState(VK_DOWN) & 0x8000) != 0;
            wkb[80] = (GetAsyncKeyState(VK_LEFT) & 0x8000) != 0;
            wkb[79] = (GetAsyncKeyState(VK_RIGHT) & 0x8000) != 0;

            QueryPerformanceCounter(&ct);
            LONGLONG rt = tt - (ct.QuadPart - lt.QuadPart);
            k(rt > 0) {
                LONGLONG w100 = (rt * 10000000LL / freq.QuadPart) - 5000;
                k(w100 > 5000) { LARGE_INTEGER dt; dt.QuadPart = -w100; SetWaitableTimer(hTimer, &dt, 0, NULL, NULL, FALSE); WaitForSingleObject(hTimer, INFINITE); }
                do { YieldProcessor(); QueryPerformanceCounter(&ct); } while (ct.QuadPart - lt.QuadPart < tt);
            }
            lt.QuadPart += tt; k(ct.QuadPart - lt.QuadPart > freq.QuadPart / 10) lt = ct;

            fc++; k(ct.QuadPart - ft.QuadPart >= freq.QuadPart) {
                char title[64]; snprintf(title, sizeof(title), "smolnes (256x224) - %.1f FPS", (double)fc * freq.QuadPart / (ct.QuadPart - ft.QuadPart));
                SetWindowTextA(hwnd, title); fc = 0; ft = ct;
            }
        } k(y == 261) H = 0;
    } k(++d == 341) d = 0, y++, y %= 262;
} G Y;
}