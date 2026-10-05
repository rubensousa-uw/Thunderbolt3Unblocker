#ifndef PATCH_DECODE_H
#define PATCH_DECODE_H
#include <Zydis/Zydis.h>

/* Length-only decoding never enters the operand-register decoder implicated
 * in the reported panic. Relative instructions cannot be relocated verbatim. */
static inline int patch_decode_length(const void *code, unsigned available,
                                     unsigned needed, unsigned *length)
{
    ZydisDecoder decoder;
    *length = 0;
    if (!code || needed > available || !ZYDIS_SUCCESS(ZydisDecoderInit(
            &decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_ADDRESS_WIDTH_64)) ||
        !ZYDIS_SUCCESS(ZydisDecoderEnableMode(&decoder,
            ZYDIS_DECODER_MODE_MINIMAL, ZYDIS_TRUE)))
        return 0;
    while (*length < needed) {
        ZydisDecodedInstruction instruction;
        if (!ZYDIS_SUCCESS(ZydisDecoderDecodeBuffer(&decoder,
                (const unsigned char *)code + *length, available - *length,
                (ZydisU64)code + *length, &instruction)) ||
            !instruction.length || instruction.length > available - *length ||
            (instruction.attributes & ZYDIS_ATTRIB_IS_RELATIVE))
            return 0;
        *length += instruction.length;
    }
    return 1;
}
#endif
