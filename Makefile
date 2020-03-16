CC = clang
CFLAGS=-target x86_64-apple-macos10.8 -fmessage-length=0 -fdiagnostics-show-note-include-stack -fmacro-backtrace-limit=0 -std=gnu99 -Wno-trigraphs -fpascal-strings -O0 -Wno-missing-field-initializers -Wno-missing-prototypes -Wno-missing-braces -Wparentheses -Wswitch -Wno-unused-function -Wno-unused-label -Wno-unused-parameter -Wunused-variable -Wunused-value -Wempty-body -Wuninitialized -Wno-unknown-pragmas -Wno-shadow -Wno-four-char-constants -Wno-conversion -Wconstant-conversion -Wint-conversion -Wno-bool-conversion -Wenum-conversion -Wno-float-conversion -Wno-non-literal-null-conversion -Wno-objc-literal-conversion -Wshorten-64-to-32 -Wpointer-sign -Wno-newline-eof -DDEBUG=1 -fasm-blocks -fstrict-aliasing -Wdeprecated-declarations -g -Wno-sign-conversion -Wno-infinite-recursion -Wno-comma -Wno-block-capture-autoreleasing -Wno-strict-prototypes -Wno-semicolon-before-method-body

TARGET=macbit

TARGET = macbit

all: $(TARGET)

$(TARGET): src/main.c
	$(CC) $(CFLAGS) -o $(TARGET) src/main.c

clean:
	$(RM) $(TARGET)
