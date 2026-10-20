# Compiler and flags
CC      := gcc
CFLAGS  := -O3 -Wall -Wextra -std=gnu17 -DDEBUG \
-Wno-implicit-int -Wno-return-type -Wno-parentheses -Wno-char-subscripts -Wno-misleading-indentation \
-Wno-unused-result -Wno-return-mismatch \
-include iso646.h -include string.h -include stdio.h -include unistd.h \
-DK='"dawskj \r"' -DR='{0,19,0,216,1,77,176,1}' -DC='I(F++)' 

# These includes remove the following errors
# -include string.h -include stdio.h -include unistd.h 
# -Wno-implicit-function-declaration  -Wno-builtin-declaration-mismatch

# These includes remove the following errors
# -include string.h -include stdio.h
# -Wno-implicit-function-declaration  


# File discovery
# This automatically finds all .c files in the current directory
SRCS    := $(wildcard *.c)
OBJS    := $(SRCS:.c=.o)

.PHONY: ioccc

# Build unobfuscated code
gb: gb.o
	$(CC) $(CFLAGS) -o gb gb.o

# Build obfuscated code
prog: prog.o
	$(CC) $(CFLAGS) -o prog prog.o

prog.crunched.c: gb.c crunch.py
	python crunch.py gb.c prog.crunched.c

prog.c: prog.crunched.c shape_code.py gameboy-stencil.txt
	python shape_code.py prog.crunched.c gameboy-stencil.txt prog.c

prog.indented.c: prog.c
	indent -l999 <prog.c >prog.indented.c

# Build indented obfuscated code for debugging
prog.indented: prog.indented.o
	$(CC) $(CFLAGS) -o prog.indented prog.indented.o

ioccc: prog.c Makefile.ioccc
	rm -f prog.o prog
	make -f Makefile.ioccc

iocccclang: prog.c Makefile.ioccc
	rm -f prog.o prog
	make CC=clang -f Makefile.ioccc

# Rule for object files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Cleanup
.PHONY: clean
clean:
	rm -f gb prog prog.indented prog.crunched prog.crunched.c *~ $(OBJS)
