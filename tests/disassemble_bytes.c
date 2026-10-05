/* User-space diagnostic only; never opens IOKit or touches live kernel memory. */
#include <stdio.h>
#include <Zydis/Zydis.h>
int main(void) {
    unsigned long long address;
    unsigned value, count = 0, offset = 0;
    unsigned char bytes[8192];
    if (scanf("%llx", &address) != 1) return 1;
    while (count < sizeof bytes && scanf("%x", &value) == 1) {
        if (value > 255) return 1;
        bytes[count++] = value;
    }
    ZydisDecoder decoder;
    ZydisFormatter formatter;
    ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_ADDRESS_WIDTH_64);
    ZydisFormatterInit(&formatter, ZYDIS_FORMATTER_STYLE_INTEL);
    while (offset < count) {
        ZydisDecodedInstruction instruction;
        char text[256];
        if (!ZYDIS_SUCCESS(ZydisDecoderDecodeBuffer(&decoder, bytes + offset,
                count - offset, address + offset, &instruction))) return 2;
        if (!ZYDIS_SUCCESS(ZydisFormatterFormatInstruction(&formatter,
                &instruction, text, sizeof text))) return 3;
        printf("%016llx: %s\n", address + offset, text);
        offset += instruction.length;
    }
    return 0;
}
