# ==========================================
# MinGW32 전용 GLEW 빌드 Makefile (DllMain 충돌 수정본)
# ==========================================

# 컴파일러 및 도구 설정
CC      = gcc
AR      = ar
CFLAGS  = -O2 -Wall -Iinclude -DGLEW_BUILD
# -nostartfiles 옵션을 추가하여 중복 정의(multiple definition) 에러를 방지합니다.
LDFLAGS = -nostartfiles -luser32 -lgdi32 -lopengl32

# 출력 디렉토리 설정
BIN_DIR = bin
LIB_DIR = lib

# 최종 결과물 명칭
TARGET_STATIC = $(LIB_DIR)/libglew32.a
TARGET_IMPORT = $(LIB_DIR)/libglew32.dll.a
TARGET_DLL    = $(BIN_DIR)/glew32.dll

# 소스 파일 위치
SRC = src/glew.c

# 기본 빌드 타겟 (모두 빌드)
all: directories $(TARGET_STATIC) $(TARGET_DLL)

# 폴더 생성
directories:
	@mkdir -p $(BIN_DIR) $(LIB_DIR)

# 1. 정적 라이브러리 빌드 (libglew32.a)
$(TARGET_STATIC): $(SRC)
	$(CC) $(CFLAGS) -DGLEW_STATIC -c $(SRC) -o glew_static.o
	$(AR) rcs $(TARGET_STATIC) glew_static.o
	@rm -f glew_static.o
	@echo "[성공] 정적 라이브러리 생성 완료: $(TARGET_STATIC)"

# 2. 동적 라이브러리 및 임포트 라이브러리 빌드 (glew32.dll, libglew32.dll.a)
$(TARGET_DLL): $(SRC)
	$(CC) $(CFLAGS) -shared $(SRC) -o $(TARGET_DLL) -Wl,--out-implib,$(TARGET_IMPORT) $(LDFLAGS)
	@echo "[성공] 동적 라이브러리 생성 완료: $(TARGET_DLL)"
	@echo "[성공] 임포트 라이브러리 생성 완료: $(TARGET_IMPORT)"

# 정리 명령어
clean:
	rm -rf $(BIN_DIR) $(LIB_DIR) *.o
	@echo "빌드 파일 삭제 완료."

.PHONY: all directories clean