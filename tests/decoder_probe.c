#include <Zydis/Zydis.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Catch the old decoder's assertion in user space, never in the kernel. */
static jmp_buf assertion;
static const char *failed_expression;
static int failed_line;
void __assert_rtn(const char *function, const char *file, int line,
                  const char *expression) {
    (void)function; (void)file;
    failed_expression = expression;
    failed_line = line;
    longjmp(assertion, 1);
}

int main(void) {
    ZydisDecoder decoder;
    ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_ADDRESS_WIDTH_64);
    unsigned long checked = 0;
    unsigned long failures = 0;
    /* Exhaustively probe three-byte prefixes, with a zero-filled tail. */
    for (unsigned value = 0; value < 0x1000000; ++value) {
        unsigned char bytes[15] = {value >> 16, value >> 8, value};
        ZydisDecodedInstruction instruction;
        if (setjmp(assertion)) {
            ++failures;
            if (failures <= 12)
                printf("assertion: %02x %02x %02x (zero tail): line %d %s\n",
                       bytes[0], bytes[1], bytes[2], failed_line, failed_expression);
        } else {
            (void)ZydisDecoderDecodeBuffer(&decoder, bytes, sizeof(bytes), 0,
                                          &instruction);
        }
        ++checked;
    }
    printf("checked=%lu assertions=%lu\n", checked, failures);
    return failures ? EXIT_FAILURE : EXIT_SUCCESS;
}
