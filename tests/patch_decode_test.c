#include <assert.h>
#include <stdio.h>
#include "../xnu_override/patch_decode.h"
int main(void) {
    const unsigned char tahoe[] = {0x55,0x48,0x89,0xe5,0x41,0x57,0x41,0x56,
        0x41,0x55,0x41,0x54,0x53,0x48,0x81,0xec,0x28,0x01,0x00,0x00};
    const unsigned char rip[] = {0x48,0x8b,0x05,0,0,0,0};
    const unsigned char call[] = {0xe8,0,0,0,0};
    const unsigned char jump[] = {0xeb,0};
    const unsigned char truncated[] = {0x48};
    unsigned n;
    assert(patch_decode_length(tahoe,sizeof tahoe,12,&n) && n == 12);
    assert(!patch_decode_length(rip,sizeof rip,1,&n));
    assert(!patch_decode_length(call,sizeof call,1,&n));
    assert(!patch_decode_length(jump,sizeof jump,1,&n));
    assert(!patch_decode_length(truncated,sizeof truncated,1,&n));
    assert(!patch_decode_length(tahoe,4,12,&n));
    assert(!patch_decode_length(NULL,32,12,&n));
    puts("7 prologue safety tests passed");
}
