#!/bin/bash
set -e
rgbasm -o main.o main.asm
rgblink -o test.gb main.o
rgbfix -v -p 0xFF test.gb
cp -av test.gb ../roms/Test.gb
