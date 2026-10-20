#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL2/SDL.h>

#ifndef R
  #define R {0,0,0,0,0,0,0,0}
#endif

#define G t[6]
#define A t[7]
#define M Z(2,0)
#define E (G&128)
#define B (G&16)
#define O if(y
#define Y O ==
#define _(r) (b=I(r++),b|I(r++)<<8)
#define S _(F)
#define C (b=I(F++),b)

typedef unsigned char u; 
u w, X, T, D[1 << 16], t[8] = R, U = 255; 
unsigned short J = -2, F = 256, H = 65280, b;

// === MBC 및 확장 메모리 지원을 위한 전역 변수 ===
u *ROM = NULL;        // 전체 ROM 데이터 버퍼
int rom_banks = 2;    // 기본 16K Bank 개수
int rom_bank = 1;     // 현재 선택된 ROM Bank (0x4000-0x7FFF)
int ram_bank = 0;     // RAM Bank Index
int ram_enabled = 0;  // External RAM Enable Flag
u ext_ram[0x8000];    // MBC2/MBC3용 외부 RAM (32KB)

// Gameboy 픽셀 컬러 팔레트 (Grayscale 4단계)
const Uint32 PALETTE[4] = {
    0xFFFFFFFF, // 0: White
    0xFFAAAAAA, // 1: Light Gray
    0xFF555555, // 2: Dark Gray
    0xFF000000  // 3: Black
};

// ============================================================================
// 메모리 Read / Write (MBC2 / MBC3 구현)
// ============================================================================
int I(int a) { 
    a &= 0xFFFF;
    // 0x4000 ~ 0x7FFF : ROM Bank 1~N (Bank Switching)
    if (a >= 0x4000 && a < 0x8000) {
        if (ROM) return ROM[(a - 0x4000) + (rom_bank * 0x4000)];
    }
    // 0xA000 ~ 0xBFFF : External RAM / MBC2 Built-in RAM
    if (a >= 0xA000 && a < 0xC000) {
        if (!ram_enabled) return 0xFF;
        return ext_ram[(a - 0xA000) + (ram_bank * 0x2000)];
    }
    // I/O Registers & High RAM
    int r = D[a]; 
    return a ^ H ? r : (r & 16 ? U >> 4 : U) & 15 | r & 240;
} 

void N(int a, int v) { 
    a &= 0xFFFF;
    v &= 0xFF;

    // --- MBC 쓰기 제어 ($0000 ~ $7FFF) ---
    if (a < 0x2000) {
        // RAM Enable/Disable ($0000 ~ $1FFF)
        ram_enabled = ((v & 0x0F) == 0x0A);
        return;
    } 
    else if (a < 0x4000) {
        // ROM Bank Switch ($2000 ~ $3FFF) - MBC2 / MBC3 겸용
        int bank = v & 0x7F;
        if (bank == 0) bank = 1;
        rom_bank = bank % rom_banks;
        return;
    } 
    else if (a < 0x8000) {
        // RAM Bank Switch / RTC ($4000 ~ $5FFF)
        if (v <= 0x03) ram_bank = v;
        return;
    }
    else if (a >= 0xA000 && a < 0xC000) {
        // External RAM Write ($A000 ~ $BFFF)
        if (ram_enabled) {
            ext_ram[(a - 0xA000) + (ram_bank * 0x2000)] = v;
        }
        return;
    }

    // --- 기본 RAM / VRAM / Register 쓰기 ($8000 이상) ---
    if (a >> 15) {
        D[a] = v;
        // DMA Transfer 처리 ($FF46)
        if (a == H + 70) {
            for (int i = 0; i < 160; i++) {
                D[65024 + i] = I((v << 8) | i);
            }
        }
    } 
} 

// ============================================================================
// CPU 연산 도우미 함수 (원래 난독화 유지)
// ============================================================================
int Z(int k, int p){ return k<3?t[k*2]<<8|t[k*2+1]:p?A<<8|G:J; } 
void P(int k, int v, int p){ k<3?(t[k*2]=v>>8,t[k*2+1]=v):p?(A=v>>8,G=v&240):(J=v); } 
int W(int i){ return i^6?t[i]:I(M); } 
void V(int i, int v){ i^6?t[i]=v:N(M,v); } 
void L(int z, int n, int c){ G=(z?128:0)|(n?64:0)|(c?16:0); } 
void Q(int v){ N(--J,v>>8); N(--J,v); } 

void j(int o, int v){ 
    int c=(o&1 && o<4)*(G>>4&1),e=o>1,h=o&4 && o^7,
    r=h?(o&1?A^v:o>4?A|v:A&v):(e?A-v-c:A+v+c); 
    G=(!(r&255)<<7)|((!h && e)<<6)|(!h &&(e?r<0:r>255))<<4; 
    if(o^7)A=r; 
} 

void m(void){
    if(X){ if(D[65535]&D[H+15])X=0; return; } 
    if(T){ w=1; T=0; } 
    { 
        u o=C, x=o>>6,y=o>>3&7,z=o&7,p=y>>1,q=y&1; 
        int a,c,e,r,v,k[]={ !E,E,!B,B }; 
        switch(x){ 
            case 0:switch(z){ 
                case 0:Y 2 || !y)return; Y 1){ a=S; N(a,J); N(a+1,J>>8); return; } { e=(signed char)C; Y 3 || k[y-4])F+=e; return; } 
                case 1:if(!q)P(p,S,0); else{ L(E,0,(r=M+Z(p,0))>65535); P(2,r,0); } return; 
                case 2:a=p>1?M:Z(p,0); q?(A=I(a)):N(a,A); if(p>1)P(2,M+5-2*p,0); return; 
                case 3:P(p,Z(p,0)+1-2*q,0); return; 
                case 4:case 5:o=W(y)+9-2*z; V(y,o); L(!o,z&1,B); return; 
                case 6:V(y,C); return; 
                default:O<4){ c=(y&1?A:A>>7)&1; A=y&1?A>>1:A<<1; A|=(y&2?!!B:c)<<((y&1)*7); L(0,0,c); } 
                else Y 4){ if(G&64){ if(B)A-=96; } else{ if(B||A>153){ A+=96; G|=16; } if((A&15)>9)A+=6; } L(!A,G&64,B); } 
                else Y 5){ A=~A; L(E,1,B); } 
                else{ L(E,0,y&1?!B:1); } return; 
            } 
            case 1:if(o==118)X=1; else V(y,W(z)); return; 
            case 2:j(y,W(z)); return; 
            default:switch(z){ 
                case 0:O<4){ if(k[y])F=_(J); return; } Y 4){ N(H|C,A); return; } Y 6){ A=I(H|C); return; } { e=(signed char)C; r=J+e; L(0,0,(J^e^r)&256); Y 5)J=r; else P(2,r,0); return; } 
                case 1:if(!q){ P(p,_(J),1); return; } if(p&2){ p&1?(J=M):(F=M); return; } F=_(J); w|=p; return; 
                case 2:a=(y<4 || y&1)?S:H|t[1]; O<4){ if(k[y])F=a; } else{ y&2?(A=I(a)):N(a,A); } return; 
                case 3:if(!y){ a=S; F=a; return; } O>5){ y==6?(w=T=0):(T=1); return; } o=C; x=o>>6; y=o>>3&7; z=o&7; v=r=W(z); 
                if(x==1){ L(!(v&(1<<y)),0,B); return; } 
                if(x)r=x==2?v&~(1<<y):v|(1<<y); 
                else{ c=(y!=6) & (v>>7 * !(y&1)); r=y==6?v<<4|v>>4:(y&1?v>>1:v<<1); O<4)r|=(y&2?!!B:c)<<((y&1)*7); Y 5)r|=v&128; x=r; L(!x,0,c); } 
                V(z,r); return; 
                case 4:O<4){ a=S; if(k[y]){ Q(F); F=a; } } return; 
                case 5:if(!q)Q(Z(p,1)); else if(!p){ a=S; Q(F); F=a; } return; 
                case 6:j(y,C); return; 
                default:Q(F); F=y*8; return; 
            } 
        } 
    } 
} 

// ============================================================================
// PPU / Graphic 렌더링 함수 (8x8 및 8x16 스프라이트 완벽 지원)
// ============================================================================

// 특정 (x, y) 좌표의 픽셀 명암 값 (0~3) 반환 함수 (팔레트 레지스터 및 Window 반영)
int i(int x, int y) { 
    int lcdc = D[H + 64]; 
    if (!(lcdc & 0x80)) return 0; // LCD Off 시 흰색 처리

    int raw_color = 0; 
    int final_color = 0;
    u *o; 

    // 1. Background / Window Layer
    if (lcdc & 1) { 
        int wy = D[H + 74];       // 0xFF4A: WY
        int wx = D[H + 75] - 7;   // 0xFF4B: WX (-7 오프셋)
        int is_win = (lcdc & 32) && (y >= wy) && (x >= wx); // Window 활성화 체크

        int p, q, map_offset;

        if (is_win) {
            // Window 좌표 및 타일맵 위치 (Bit 6: 0x9C00 / 0x9800)
            p = x - wx;
            q = y - wy;
            map_offset = (lcdc & 64) ? 1024 : 0;
        } else {
            // Background 좌표 및 타일맵 위치 (Bit 3: 0x9C00 / 0x9800)
            o = D + H + 66; // SCY(66), SCX(67)
            p = x + o[1]; 
            q = y + *o; 
            map_offset = (lcdc & 8) ? 1024 : 0;
        }

        // 기존의 검증된 타일 및 비트 읽기 수식 유지
        int h = D[38912 + map_offset + (q / 8 & 31) * 32 + (p / 8 & 31)]; 
        o = D + (lcdc & 16 ? 8 : 9) * 4096 + (lcdc & 16 ? h : (signed char)h) * 16 + (q & 7) * 2; 
        raw_color = (*o >> (7 - (p & 7)) & 1) | (o[1] >> (7 - (p & 7)) & 1) * 2; 
        
        // BGP 레지스터 (0xFF47) 적용
        u bgp = D[H + 71]; 
        final_color = (bgp >> (raw_color * 2)) & 3;
    } 

    // 2. Sprite (OBJ) Layer
    if (lcdc & 2) {
        int sprite_height = (lcdc & 4) ? 16 : 8; // 8x16 스프라이트 체크

        for (int k = 0; k < 40; k++) { 
            o = D + 65024 + k * 4; 
            int sy = o[0] - 16;
            int sx = o[1] - 8;
            int tile_idx = o[2];
            int flags = o[3];

            if (x >= sx && x < sx + 8 && y >= sy && y < sy + sprite_height) { 
                int py = y - sy;
                int px = x - sx;

                if (flags & 0x40) py = sprite_height - 1 - py; // Vertical Flip
                if (flags & 0x20) px = 7 - px;                 // Horizontal Flip

                if (sprite_height == 16) {
                    tile_idx &= 0xFE;
                    if (py >= 8) {
                        tile_idx |= 1;
                        py -= 8;
                    }
                }

                u* tile_data = D + 32768 + tile_idx * 16 + py * 2; 
                int obj_raw_color = (*tile_data >> (7 - px) & 1) | (tile_data[1] >> (7 - px) & 1) * 2; 

                // 투명색(0)이 아니면 출력 (스프라이트 BG 우선순위 적용)
                if (obj_raw_color != 0) {
                    int bg_priority = flags & 0x80;
                    if (!bg_priority || raw_color == 0) {
                        u obp = (flags & 0x10) ? D[H + 73] : D[H + 72];
                        final_color = (obp >> (obj_raw_color * 2)) & 3;
                    }
                    break; 
                }
            } 
        } 
    }

    return final_color; 
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================
int main(int argc, char* argv[]) { 
    // 1. ROM 파일 로드 및 MBC 설정
    if (argc <= 1) {
        printf("사용법: %s <ROM_FILE.gb>\n", argv[0]);
        return 1;
    }

    FILE* fp = fopen(argv[1], "rb");
    if (!fp) {
        printf("ROM 파일을 열 수 없습니다: %s\n", argv[1]);
        return 1;
    }

    fseek(fp, 0, SEEK_END);
    long rom_size = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    ROM = (u*)malloc(rom_size);
    fread(ROM, 1, rom_size, fp);
    fclose(fp);

    // ROM Bank 개수 계산 (16KB 단위)
    rom_banks = rom_size / 0x4000;
    if (rom_banks < 2) rom_banks = 2;

    // D[0x0000 ~ 0x7FFF] 메모리에 기본 Bank 0, 1 로드
    memcpy(D, ROM, rom_size > 0x8000 ? 0x8000 : rom_size);

    // 2. SDL2 초기화
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL 초기화 실패: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "GameBoy Emulator - Zelda Supported",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        160 * 3, 144 * 3,
        SDL_WINDOW_SHOWN
    );

    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    SDL_Texture* texture = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING,
        160, 144
    );

    Uint32 pixels[160 * 144];

    u* a = D + H + 68; 
    int p = 0, q = 0; 
    int running = 1;

    D[H] = 207; a[-4] = 145; a[187] = 1; 

    // 3. 메인 에뮬레이션 루프
    while (running) { 
        m(); 
        D[H + 4]++; 
        p += 8; 

        for (; p >= 456; p -= 456) 
            ++*a == 144 ? D[H + 15] |= 1, q = 0 : *a > 153 ? *a = q = 0 : 0; 
        
        // V-Blank 시점 (화면 갱신 및 입력 처리)
        if (*a == 144 && !q) { 
            q = 1; 

            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT) {
                    running = 0;
                }
            }

            const Uint8* state = SDL_GetKeyboardState(NULL);
            U = 255;
            
            u key_state = 0;
            if (state[SDL_SCANCODE_RIGHT])  key_state |= (1 << 0);
            if (state[SDL_SCANCODE_LEFT])   key_state |= (1 << 1);
            if (state[SDL_SCANCODE_UP])     key_state |= (1 << 2);
            if (state[SDL_SCANCODE_DOWN])   key_state |= (1 << 3);
            if (state[SDL_SCANCODE_Z])      key_state |= (1 << 4); // A
            if (state[SDL_SCANCODE_X])      key_state |= (1 << 5); // B
            if (state[SDL_SCANCODE_SPACE])  key_state |= (1 << 6); // Select
            if (state[SDL_SCANCODE_RETURN]) key_state |= (1 << 7); // Start

            U ^= key_state;

            // 160x144 픽셀 버퍼 생성
            for (int f = 0; f < 144; f++) {
                for (int g = 0; g < 160; g++) {
                    int color_idx = i(g, f);
                    pixels[f * 160 + g] = PALETTE[color_idx];
                }
            }

            SDL_UpdateTexture(texture, NULL, pixels, 160 * sizeof(Uint32));
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, NULL, NULL);
            SDL_RenderPresent(renderer);

       // 60FPS 타이밍 맞추기 (1 프레임당 약 16ms)
        static Uint32 last_time = 0;
        Uint32 current_time = SDL_GetTicks();
        if (current_time - last_time < 16) {
            SDL_Delay(16 - (current_time - last_time));
        }
        last_time = SDL_GetTicks();
       } 

        (w && (D[65535] & D[H + 15] & 1)) ? (w = 0, D[H + 15] &= ~1, Q(F), F = 64) : 0; 
    } 

    // 4. 자원 해제
    if (ROM) free(ROM);
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}