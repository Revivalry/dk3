/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Save bytes/checksums remain compatible with the original bitwise writer. */
#ifdef NDEBUG
#error Save CRC contracts require assertions
#endif
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "../../engine/ioquake3/code/qcommon/q_shared.h"
#include "../../engine/ioquake3/code/qcommon/dk_save_format.h"

void QDECL Com_Error(int level, const char *format, ...) {
    (void)level; (void)format; abort();
}
static unsigned int reference(const byte *data, int count) {
    unsigned int crc = ~0u;
    int i, bit;
    for (i = 0; i < count; ++i) {
        crc ^= data[i];
        for (bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ (0xedb88320u & (0u - (crc & 1u)));
    }
    return ~crc;
}
static unsigned int read32(const byte *data) {
    return (unsigned int)data[0] | ((unsigned int)data[1] << 8) |
           ((unsigned int)data[2] << 16) | ((unsigned int)data[3] << 24);
}
int main(void) {
    byte *buffer = malloc(131072 + 16), *payload = malloc(65536);
    const int counts[] = {0, 1, 7, 8, 15, 16, 31, 32, 63, 64, 255, 256, 1023, 1024, 65535, 65536};
    int i, j, alignment, length;
    dkSaveWriter_t writer;
    char error[160];
    assert(buffer && payload);
    assert(reference((const byte *)"123456789", 9) == 0xcbf43926u);
    for (i = 0; i < 65536; ++i) payload[i] = (byte)(i * 17 + i / 251);
    for (alignment = 0; alignment < 16; ++alignment) {
        byte *data = buffer + alignment;
        for (j = 0; j < (int)(sizeof(counts) / sizeof(counts[0])); ++j) {
            assert(DK_SaveBegin(&writer, data, 131072));
            assert(DK_SaveRecord(&writer, "fixture", 42));
            assert(DK_SaveBytes(&writer, "payload", payload, counts[j]));
            length = DK_SaveFinish(&writer);
            assert(length > 24);
            assert(read32(data + 20) == reference(data + 24, length - 24));
            assert(DK_SaveValidate(data, length, error, sizeof(error)));
            data[length - 1] ^= 1;
            assert(!DK_SaveValidate(data, length, error, sizeof(error)));
            assert(!strcmp(error, "save checksum mismatch"));
            data[length - 1] ^= 1;
            assert(!DK_SaveValidate(data, length - 1, error, sizeof(error)));
        }
        /* A valid empty stream retains the original zero CRC. */
        assert(DK_SaveBegin(&writer, data, 131072));
        assert(DK_SaveFinish(&writer) == 24);
        assert(read32(data + 20) == 0);
        assert(DK_SaveValidate(data, 24, error, sizeof(error)));
    }
    free(payload); free(buffer);
    puts("save CRC compatibility: 256 payload/alignment cases plus empty streams passed");
    return 0;
}
