# 컴파일러 및 플래그 설정
CC = gcc
# MINGW32 순수 32비트 환경이므로 -m32 옵션은 제외해도 안전합니다.
CFLAGS = -Wno-overflow -Wall -pedantic -DLOG_USE_COLOR -Wno-address-of-packed-member -ffast-math -Ofast -g -flto

# 라이브러리 링크 옵션
# Windows SDL2 컴파일 시 필수인 -lmingw32를 가장 앞에 추가했습니다.
LIBS = -lmingw32 -lSDL2main -lSDL2

# 소스 파일 디렉터리 정의 (MSYS2 표준인 슬래시 / 사용)
SRC_DIRS = psx psx/dev psx/input psx/dev/cdrom frontend

# 각 디렉터리 내의 모든 .c 파일 수집
SRCS = $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c))

# .c 파일을 바탕으로 빌드될 .o (목적 파일) 경로 지정
OBJ_DIR = obj
OBJS = $(patsubst %.c, $(OBJ_DIR)/%.o, $(SRCS))

# 최종 출력 실행 파일 이름 (경로 구분자 슬래시로 변경)
TARGET = exe/psxe.exe

# 기본 타겟
all: $(TARGET)

# 최종 실행 파일 링크 과정
$(TARGET): $(OBJS)
	@echo "==== 실행 파일 생성 중: $@ ===="
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $^ -o $@ $(LIBS)

# 각 .c 파일을 .o 파일로 컴파일하는 규칙 (MSYS2/리눅스 셸 완벽 호환)
$(OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	@echo "컴파일 중: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# 빌드 청소 (MSYS2/리눅스 셸용)
clean:
	@echo "==== 빌드 파일 삭제 중 ===="
	rm -rf $(OBJ_DIR)
	rm -f $(TARGET)

.PHONY: all clean
