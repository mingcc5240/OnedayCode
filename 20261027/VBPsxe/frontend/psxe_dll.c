#include "../psx/psx.h"
#include "../psx/input/sda.h"
#include "../psx/input/guncon.h"
#include "../psx/dev/cdrom/cdrom.h"
#include "screen.h"
#include "config.h"

#include <windows.h>
#include <stdio.h>

#undef main

#define VB6_API __declspec(dllexport) __stdcall

#include <time.h>

// 전역 FPS 카운터 변수들
static int g_frame_count = 0;
static float g_current_fps = 0.0f;
static DWORD g_last_tick = 0;

// PSXE_RunFrame 내부에서 매 프레임마다 호출하여 FPS를 갱신하는 함수
static void update_fps_counter(void) {
    g_frame_count++;
    DWORD current_tick = GetTickCount();

    // 1초(1000ms)마다 FPS 계산 갱신
    if (current_tick - g_last_tick >= 1000) {
        g_current_fps = (float)g_frame_count * 1000.0f / (float)(current_tick - g_last_tick);
        g_frame_count = 0;
        g_last_tick = current_tick;
    }
}

// VB6에서 현재 FPS 값을 가져갈 수 있도록 Export 함수 추가
float VB6_API PSXE_GetFPS(void) {
    return g_current_fps;
}

extern void* g_external_hwnd;
extern int g_vblank_reached;

static psx_t* g_psx = NULL;
static psxe_screen_t* g_screen = NULL;
static psx_input_t* g_input = NULL;
static psxi_sda_t* g_controller = NULL;
static SDL_AudioDeviceID g_audio_dev = 0;

void audio_update(void* ud, uint8_t* buf, int size) {
    psx_cdrom_t* cdrom = ((psx_t*)ud)->cdrom;
    psx_spu_t* spu = ((psx_t*)ud)->spu;

    memset(buf, 0, size);

    psx_cdrom_get_audio_samples(cdrom, buf, size);
    psx_spu_update_cdda_buffer(spu, cdrom->cdda_buf);

    for (int i = 0; i < (size >> 2); i++) {
        uint32_t sample = psx_spu_get_sample(spu);

        int16_t left = (int16_t)(sample & 0xffff);
        int16_t right = (int16_t)(sample >> 16);

        *(int16_t*)(&buf[(i << 2) + 0]) += left;
        *(int16_t*)(&buf[(i << 2) + 2]) += right;
    }
}

// VB6의 빈 문자열("")을 C의 NULL 포인터로 안전하게 변환하는 헬퍼 함수
static const char* sanitize_path(const char* path) {
    if (!path || path[0] == '\0') return NULL;
    return path;
}

// 1. 에뮬레이터 초기화 (성공 시 0 반환, 실패 시 에러 코드 1, 2, 3 반환)
int VB6_API PSXE_Init(HWND hwnd, const char* bios_path, const char* exp_path, const char* cd_path, const char* exe_path) {
    if (g_psx != NULL) return -1;

    const char* safe_bios = sanitize_path(bios_path);
    const char* safe_exp = sanitize_path(exp_path);
    const char* safe_cd = sanitize_path(cd_path);
    const char* safe_exe = sanitize_path(exe_path);

    // psx_init 내부에서 부분 할당 후 실패하는 것을 막기 위해 BIOS 파일 존재 여부 선행 확인
    if (!safe_bios) return 1;
    FILE* f = fopen(safe_bios, "rb");
    if (!f) return 1;
    fclose(f);

    g_external_hwnd = (void*)hwnd;

    SDL_SetHint(SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP, "1");
    SDL_SetHint(SDL_HINT_VIDEO_FOREIGN_WINDOW_OPENGL, "1");

    log_set_quiet(1);

    g_psx = psx_create();
    if (!g_psx) return -1;

    // psx_init 실행 및 반환값(0: 성공, 1: BIOS 실패, 2: EXP1 실패) 검증
    int init_res = psx_init(g_psx, safe_bios, safe_exp);
    if (init_res != 0) {
        // 초기화 도중 실패한 경우 크래시 방지를 위해 g_psx 정리 후 에러 코드 반환
        free(g_psx);
        g_psx = NULL;
        return init_res;
    }

    // CD-ROM 이미지 마운트
    psx_cdrom_t* cdrom = psx_get_cdrom(g_psx);
    if (safe_cd) {
        if (!psx_cdrom_open(cdrom, safe_cd)) {
            // psx_cdrom_open이 실패(0 반환 가정)하더라도 바이오스 부팅은 가능하지만 필요시 체크
        }
    }

    // 화면(SDL) 초기화
    g_screen = psxe_screen_create();
    psxe_screen_init(g_screen, g_psx);
    psxe_screen_set_scale(g_screen, 2);
    psxe_screen_reload(g_screen);

    // 오디오(SDL) 초기화
    SDL_InitSubSystem(SDL_INIT_AUDIO);

    SDL_AudioSpec obtained, desired;
    desired.freq = 44100;
    desired.format = AUDIO_S16SYS;
    desired.channels = 2;
    desired.samples = CD_SECTOR_SIZE >> 2;
    desired.callback = &audio_update;
    desired.userdata = g_psx;

    g_audio_dev = SDL_OpenAudioDevice(NULL, 0, &desired, &obtained, 0);
    if (g_audio_dev) {
        SDL_PauseAudioDevice(g_audio_dev, 0);
    }

    // GPU 콜백 연결 (psx_init에서 생성된 gpu, timer 포인터 사용)
    psx_gpu_t* gpu = psx_get_gpu(g_psx);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_DMODE, psxe_gpu_dmode_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_VBLANK, psxe_gpu_vblank_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_HBLANK, psxe_gpu_hblank_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_VBLANK_END, psxe_gpu_vblank_end_event_cb);
    psx_gpu_set_event_callback(gpu, GPU_EVENT_HBLANK_END, psxe_gpu_hblank_end_event_cb);
    psx_gpu_set_udata(gpu, 0, g_screen);
    psx_gpu_set_udata(gpu, 1, g_psx->timer);

    // 입력 패드 및 메모리 카드 초기화
    g_input = psx_input_create();
    psx_input_init(g_input);

    g_controller = psxi_sda_create();
    psxi_sda_init(g_controller, SDA_MODEL_DIGITAL);
    psxi_sda_init_input(g_controller, g_input);

    psx_pad_attach_joy(g_psx->pad, 0, g_input);
    psx_pad_attach_mcd(g_psx->pad, 0, "slot1.mcd");
    psx_pad_attach_mcd(g_psx->pad, 1, "slot2.mcd");

    // PS-EXE 직접 실행 옵션이 있는 경우 BIOS 부팅 완료(0x80030000)까지 대기 후 주입
    if (safe_exe) {
        while (g_psx->cpu->pc != 0x80030000) {
            psx_update(g_psx);
        }
        psx_load_exe(g_psx, safe_exe);
    }

    return 0; // 0 = 정상 초기화 완료 (psx_init 관례와 동일)
}

// 2. 런타임에 CD 이미지(롬) 교체 / 삽입 함수
void VB6_API PSXE_LoadCD(const char* cd_path) {
    if (!g_psx) return;
    const char* safe_cd = sanitize_path(cd_path);
    if (safe_cd) {
        psx_swap_disc(g_psx, safe_cd);
    }
}

// 3. 1프레임(VBlank) 실행
int VB6_API PSXE_RunFrame(void) {
    if (!g_psx || !g_screen) return 0;

    g_vblank_reached = 0;

    /*
    int safety_limit = 1000000;
    while (!g_vblank_reached && --safety_limit > 0) {
        psx_update(g_psx);
    } */

    
    // PS1 CPU 클럭 기준 1프레임당 대략적인 사이클 만큼 반복실행
    for (int i = 0; i < 564480 / 4; i++) {
        psx_update(g_psx);
    } 

    // [추가] 프레임이 바뀔 때마다 FPS 카운트 갱신
    update_fps_counter();

    return psxe_screen_is_open(g_screen);
}

// 4. VB6 키 입력 전달
void VB6_API PSXE_SetPadButton(uint32_t button_mask, int is_pressed) {
    if (!g_screen || !g_screen->pad) return;

    if (is_pressed) {
        psx_pad_button_press(g_screen->pad, 0, button_mask);
    }
    else {
        psx_pad_button_release(g_screen->pad, 0, button_mask);
    }
}

// 5. 단축키 명령 (F1~F5)
void VB6_API PSXE_Command(int cmd_id) {
    if (!g_screen || !g_psx) return;

    switch (cmd_id) {
    case 1: psxe_screen_toggle_debug_mode(g_screen); break;
    case 3:
        g_screen->vertical_mode = !g_screen->vertical_mode;
        psxe_gpu_dmode_event_cb(g_psx->gpu);
        break;
    case 4:
        g_screen->bilinear = !g_screen->bilinear;
        psxe_gpu_dmode_event_cb(g_psx->gpu);
        break;
    case 5: psx_soft_reset(g_psx); break;
    }
}

// 6. 종료 및 메모리 정리
void VB6_API PSXE_Shutdown(void) {
    if (g_audio_dev) {
        SDL_PauseAudioDevice(g_audio_dev, 1);
        SDL_CloseAudioDevice(g_audio_dev);
        g_audio_dev = 0;
    }

    if (g_psx) {
        psx_pad_detach_joy(g_psx->pad, 0);
        psx_destroy(g_psx);
        g_psx = NULL;
    }

    if (g_controller) {
        free(g_controller);
        g_controller = NULL;
    }

    if (g_input) {
        free(g_input);
        g_input = NULL;
    }

    if (g_screen) {
        psxe_screen_destroy(g_screen);
        g_screen = NULL;
    }
}