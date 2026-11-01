/* SPDX-License-Identifier: GPL-2.0-or-later
 * CPU/I/O profiler of the actual bundled ZIP reader, without an engine/window.
 * Allocation hooks isolate ZIP work from the engine's zone allocator. */
#include "../../engine/ioquake3/code/qcommon/q_shared.h"
#include "../../engine/ioquake3/code/qcommon/qcommon.h"
#include "../../engine/ioquake3/code/qcommon/unzip.h"
#include <time.h>
#include <sys/resource.h>

#undef Z_Malloc
static int allocations;
void *Z_Malloc(int size) {
    void *p = calloc(1, size);
    if (!p) abort();
    ++allocations;
    return p;
}
void *Z_MallocDebug(int size, char *label, char *file, int line) { return Z_Malloc(size); }
void Z_Free(void *p) { if (p) { --allocations; free(p); } }

static double seconds(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

int main(int argc, char **argv) {
    unzFile archive;
    unz_file_info info;
    unz_file_pos position;
    byte *bytes;
    int repeats, sample;
    struct rusage before, after;
    if (argc != 4 || (repeats = atoi(argv[3])) < 1 || repeats > 10000) return 2;
    archive = unzOpen(argv[1]);
    if (!archive || unzLocateFile(archive, argv[2], 1) != UNZ_OK ||
        unzGetCurrentFileInfo(archive, &info, NULL, 0, NULL, 0, NULL, 0) != UNZ_OK ||
        unzGetFilePos(archive, &position) != UNZ_OK || !info.uncompressed_size ||
        info.uncompressed_size > 256u << 20) return 2;
    bytes = malloc(info.uncompressed_size);
    if (!bytes) return 2;
    for (sample = -1; sample < repeats; ++sample) {
        unsigned read = 0;
        double started;
        uLong checksum;
        if (sample == 0) getrusage(RUSAGE_SELF, &before);
        started = seconds();
        if (unzGoToFilePos(archive, &position) != UNZ_OK || unzOpenCurrentFile(archive) != UNZ_OK) return 1;
        while (read < info.uncompressed_size) {
            int count = unzReadCurrentFile(archive, bytes + read, info.uncompressed_size - read);
            if (count <= 0) return 1;
            read += count;
        }
        /* Closing validates the entry CRC; no incomplete or damaged sample passes. */
        if (unzCloseCurrentFile(archive) != UNZ_OK) return 1;
        started = (seconds() - started) * 1000;
        checksum = crc32(0, bytes, read);
        if (checksum != info.crc) return 1;
        if (sample >= 0) printf("{\"sample\":%d,\"read_ms\":%.6f,\"bytes\":%u,\"compressed_bytes\":%lu,\"method\":%lu,\"crc32\":%lu}\n",
                                sample, started, read, info.compressed_size, info.compression_method, checksum);
    }
    getrusage(RUSAGE_SELF, &after);
    fprintf(stderr, "cpu_user_seconds=%.6f cpu_system_seconds=%.6f max_rss_kib=%ld major_faults=%ld\n",
            after.ru_utime.tv_sec-before.ru_utime.tv_sec+(after.ru_utime.tv_usec-before.ru_utime.tv_usec)/1e6,
            after.ru_stime.tv_sec-before.ru_stime.tv_sec+(after.ru_stime.tv_usec-before.ru_stime.tv_usec)/1e6,
            after.ru_maxrss, after.ru_majflt-before.ru_majflt);
    free(bytes);
    if (unzClose(archive) != UNZ_OK || allocations != 0) return 1;
    return 0;
}
