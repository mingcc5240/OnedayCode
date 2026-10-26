# MSYS2 UCRT64 환경 변수 강제 로드 (pkg-config와 gcc 경로 인식용)
$env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\usr\bin;" + $env:PATH

# 1. 시스템 정보 및 버전 태그 가져오기
git fetch --all --tags

$VERSION_TAG = git describe --always --tags --abbrev=0
$COMMIT_HASH = git rev-parse --short HEAD
$OS_INFO = (Get-WMIObject win32_operatingsystem).caption + " " + `
           (Get-WMIObject win32_operatingsystem).version + " " + `
           (Get-WMIObject win32_operatingsystem).OSArchitecture

$PSX_DIR = "."

# 2. 출력 디렉토리 생성
mkdir -Force -Path bin > $null

# 3. pkg-config를 통해 MSYS2에 설치된 SDL2 플래그 가져오기
$SDL2_CFLAGS = (pkg-config --cflags sdl2) -split ' '
$SDL2_LIBS = (pkg-config --libs sdl2) -split ' '

# 4. GCC 컴파일 실행
gcc -I"$($PSX_DIR)" `
    -I"$($PSX_DIR)\psx" `
    $SDL2_CFLAGS `
    "psx\*.c" `
    "psx\dev\*.c" `
    "psx\dev\cdrom\*.c" `
    "psx\input\*.c" `
    "frontend\*.c" `
    -o "bin\psxe.exe" `
    -DREP_VERSION="`"$($VERSION_TAG)`"" `
    -DREP_COMMIT_HASH="`"$($COMMIT_HASH)`"" `
    -DOS_INFO="`"$($OS_INFO)`"" `
    -lmingw32 -lSDL2main $SDL2_LIBS `
    -m64 -Wno-overflow `
    -Wall -pedantic -DLOG_USE_COLOR `
    -Wno-address-of-packed-member `
    -ffast-math -Ofast -g -flto -Werror