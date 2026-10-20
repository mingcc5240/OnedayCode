#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL2/SDL.h>

// 디폴트 매크로 및 상수 정의
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

// Gameboy 픽셀 컬러 팔레트 (Grayscale 4단계)
const Uint32 PALETTE[4] = {
    0xFFFFFFFF, // 0: White
    0xFFAAAAAA, // 1: Light Gray
    0xFF555555, // 2: Dark Gray
    0xFF000000  // 3: Black
};

// 모든 함수 정의
int I(int a){ int r=D[a]; return a^H?r:(r&16?U>>4: U)&15|r&240;} 
void N(int a, int v){ if(a>>15)for(D[a]=a^H+68?v:0,a=(a==H+70)*160;a--;) D[65024|a]=D[v<<8|a]; } 
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

// 특정 (x, y) 좌표의 픽셀 인덱스 (0~3) 추출 함수
int i(int x, int y){ 
    int e=D[H+64],c=0,p,q,h,k=0; u *o; 
    if(e&1){ 
        o=D+H+66; p=x+o[1]; q=y+*o; 
        h=D[38912+(q/8&31)*32+(p/8&31)]; 
        o=D+(e&16?8:9)*4096+(e&16?h:(signed char)h)*16+(q&7)*2; 
        c=(*o>>(7-(p&7))&1)|(o[1]>>(7-(p&7))&1)*2; 
    } 
    if(e&2)for(; k<40; k++){ 
        o=D+65024+k*4; q=y-*o+16; p=x-o[1]+8; 
        if((unsigned)q<8 && (unsigned)p<8){ 
            o=D+32768+o[2]*16+q*2; 
            h=(*o>>(7-p)&1)|(o[1]>>(7-p)&1)*2; 
            if(h)c=h; 
        } 
    } 
    return (e&128) ? c : 0; 
} 

int main(int argc, char* argv[]) { 
    // 1. ROM 파일 로드
    FILE* fp = NULL;
    if (argc > 1) {
        fp = fopen(argv[1], "rb");
    }
    if (fp) {
        fread(D, 1, 32768, fp);
        fclose(fp);
    } else {
        printf("ROM 파일을 인자로 전달해주세요. 예: %s game.gb\n", argv[0]);
        return 1;
    }

    // 2. SDL 초기화
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL 초기화 실패: %s\n", SDL_GetError());
        return 1;
    }

    // 160x144 해상도를 3배 확대한 창 생성 (480x432)
    SDL_Window* window = SDL_CreateWindow(
        "GameBoy Emulator (SDL2)",
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
        
        // V-Blank 시점 (프레임 렌더링 및 키보드 입력 체크)
        if (*a == 144 && !q) { 
            q = 1; 

            // 키보드 입력 처리
            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT) {
                    running = 0;
                }
            }

            const Uint8* state = SDL_GetKeyboardState(NULL);
            U = 255;
            
            // 키패드 매핑 (P1 Register 연동)
            // 방향키 / Z: A버튼 / X: B버튼 / Space: Select / Enter: Start
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

            // SDL 픽셀 버퍼에 160x144 그리기
            for (int f = 0; f < 144; f++) {
                for (int g = 0; g < 160; g++) {
                    int color_idx = i(g, f);
                    pixels[f * 160 + g] = PALETTE[color_idx];
                }
            }

            // 텍스처 업데이트 및 화면 렌더링
            SDL_UpdateTexture(texture, NULL, pixels, 160 * sizeof(Uint32));
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, NULL, NULL);
            SDL_RenderPresent(renderer);
        } 

        (w && (D[65535] & D[H + 15] & 1)) ? (w = 0, D[H + 15] &= ~1, Q(F), F = 64) : 0; 
    } 

    // 4. SDL 자원 해제
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}