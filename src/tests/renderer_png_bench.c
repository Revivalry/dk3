/* SPDX-License-Identifier: GPL-2.0-or-later
 * Profile the actual decoder with fixed local PNG bytes, outside renderer/FS
 * setup. One warmup precedes measured decodes; every output must match its CRC. */
#include "../../engine/ioquake3/code/renderercommon/tr_image_png.c"
#include <time.h>
#include <sys/resource.h>

refimport_t ri;
qboolean R_TakePreparedPNG(const char *name, byte **pic, int *width, int *height) { return qfalse; }
void QDECL Com_Error(int code, const char *format, ...) { abort(); }

static double seconds(void) {
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return now.tv_sec + now.tv_nsec / 1000000000.0;
}

/* Borrow the already-read fixture to isolate the real synchronous loader's
 * allocation/copy work from filesystem latency and archive decompression. */
static byte *owner_bytes;
static int owner_length;
static long owner_read(const char *name, void **bytes) { *bytes = owner_bytes; return owner_length; }
static void owner_free_file(void *bytes) {}
static void *owner_alloc(int size) { return malloc(size); }
static void QDECL owner_print(int level, const char *format, ...) {}

int main(int argc, char **argv) {
    FILE *input;
    byte *bytes, *pixels;
    long size;
    int width, height, i, repeats, owner_mode;
    unsigned long expected = 0;
    double started, elapsed, cpu;
    struct rusage before, after;
#ifdef DK3_INCLUDED_SOURCE_INPUTS
    fprintf(stderr, "included_source_sha256=%s\n", DK3_INCLUDED_SOURCE_INPUTS);
#endif
#ifdef DK3_HEADER_INPUTS
    fprintf(stderr, "header_sha256=%s\n", DK3_HEADER_INPUTS);
#endif
#ifdef DK3_BENCH_CPU_MODE
    fprintf(stderr, "benchmark_cpu=%s\n", DK3_BENCH_CPU_MODE);
#endif
    owner_mode = argc == 4 && !strcmp(argv[3], "owner");
    if ((argc != 3 && !owner_mode) || (repeats = atoi(argv[2])) < 1 || repeats > 10000) {
        fprintf(stderr, "usage: %s local.png repeats [owner]\n", argv[0]);
        return 2;
    }
    input = fopen(argv[1], "rb");
    if (!input || fseek(input, 0, SEEK_END) || (size = ftell(input)) <= 0 || size > INT_MAX || fseek(input, 0, SEEK_SET)) return 2;
    bytes = malloc(size);
    if (!bytes || fread(bytes, 1, size, input) != (size_t)size) return 2;
    fclose(input);
    if (owner_mode) {
        owner_bytes = bytes; owner_length = size;
        ri.FS_ReadFile = owner_read; ri.FS_FreeFile = owner_free_file;
        ri.Malloc = owner_alloc; ri.Free = free; ri.Printf = owner_print;
    }
    for (i = -1; i < repeats; ++i) {
        unsigned long checksum;
        double inflate_ms = 0, unfilter_ms = 0, adler_ms = 0;
        unsigned long filtered_adler = 0;
        if (i == 0) getrusage(RUSAGE_SELF, &before);
        started = seconds();
        pixels = NULL;
        if (owner_mode) R_LoadPNG("fixture.png", &pixels, &width, &height);
        else R_DecodePNG(bytes, size, &pixels, &width, &height, 256u << 20);
        elapsed = seconds() - started;
        if (!pixels) { fprintf(stderr, "decode failed\n"); free(bytes); return 1; }
        checksum = crc32(0, pixels, (size_t)width * height * 4);
        free(pixels);
        if (i == -1) expected = checksum;
        if (checksum != expected) { fprintf(stderr, "pixel mismatch\n"); free(bytes); return 1; }
        /* Separately time the real helpers on the fixed 8-bit RGB/RGBA
         * profiling inputs when sampling counters are unavailable. */
        if (i >= 0 && bytes[24] == 8 && !bytes[28] && (bytes[25] == 2 || bytes[25] == 6)) {
            struct BufferedFile file = { bytes, size, bytes + 8, size - 8 };
            struct PNG_Chunk_IHDR *header = (struct PNG_Chunk_IHDR *)(bytes + 16);
            byte *filtered = NULL;
            unsigned bpp = bytes[25] == 6 ? 4 : 3;
            uint32_t count;
            double phase = seconds();
            count = DecompressIDATs(&file, &filtered, PNG_FilteredSize(header));
            inflate_ms = (seconds() - phase) * 1000;
            if (!count || !filtered) abort();
            /* Time the actual checksum separately on these filtered bytes.
             * This diagnostic pass is outside the measured decode/inflate. */
            phase = seconds();
            filtered_adler = adler32(1, filtered, count);
            adler_ms = (seconds() - phase) * 1000;
            phase = seconds();
            if (!UnfilterImage(filtered, height, width * bpp, bpp)) abort();
            unfilter_ms = (seconds() - phase) * 1000;
            free(filtered);
        }
        if (i >= 0) printf("{\"sample\":%d,\"decode_ms\":%.6f,\"inflate_ms\":%.6f,\"adler_ms\":%.6f,\"filtered_adler32\":%lu,\"unfilter_ms\":%.6f,\"width\":%d,\"height\":%d,\"crc32\":%lu}\n", i, elapsed * 1000, inflate_ms, adler_ms, filtered_adler, unfilter_ms, width, height, checksum);
    }
    getrusage(RUSAGE_SELF, &after);
    cpu = (after.ru_utime.tv_sec - before.ru_utime.tv_sec) + (after.ru_utime.tv_usec - before.ru_utime.tv_usec) / 1000000.0;
    fprintf(stderr, "cpu_user_seconds=%.6f max_rss_kib=%ld minor_faults=%ld major_faults=%ld voluntary_switches=%ld involuntary_switches=%ld\n",
            cpu, after.ru_maxrss, after.ru_minflt - before.ru_minflt, after.ru_majflt - before.ru_majflt,
            after.ru_nvcsw - before.ru_nvcsw, after.ru_nivcsw - before.ru_nivcsw);
    free(bytes);
    return 0;
}
