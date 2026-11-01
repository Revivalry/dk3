/* SPDX-License-Identifier: GPL-2.0-or-later */
#include "tr_common.h"
#include <pthread.h>
#include <time.h>

/* Owners bound their active batches. Each batch runs one decoder at a time;
 * completed pixels live only until the owner compiles that material/model. */
#define DK3_MATERIAL_PIXEL_BUDGET (128u * 1024u * 1024u)
#define DK3_PREPARATION_EXCLUSION_NAMES 4096
typedef struct {
    char name[MAX_QPATH];
    byte *pixels;
    int width, height;
} dkPreparedImage_t;
struct dkImageBatch_s {
    int count, capacity, next, done, decodeMilliseconds;
    size_t bytes;
    struct fsReadJob_s *read;
    const void *input;
    int length;
    pthread_t thread;
    qboolean decoding, failed, useCache;
    int excludedCount, excludedRequests;
    char (*excluded)[MAX_QPATH];
    dkPreparedImage_t images[];
};
static dkImageBatch_t *selectedBatch;

dkImageBatch_t *R_CreateImageBatch(int capacity) {
    dkImageBatch_t *batch;
    if (capacity <= 0 || capacity > 1024) return NULL;
    batch = calloc(1, sizeof(*batch) + capacity * sizeof(batch->images[0]));
    if (batch) batch->capacity = capacity;
    return batch;
}
dkImageBatch_t *R_CreateCachedImageBatch(int capacity) {
    dkImageBatch_t *batch = R_CreateImageBatch(capacity);
    if (batch) batch->useCache = qtrue;
    return batch;
}
qboolean R_ExcludePreparedImages(dkImageBatch_t *batch, const dkImageBatch_t *earlier) {
    int i, total;
    char (*names)[MAX_QPATH];
    if (!batch || batch->read || batch->decoding || batch == earlier) return qfalse;
    if (!earlier) {
        free(batch->excluded);
        batch->excluded = NULL;
        batch->excludedCount = 0;
        batch->excludedRequests = 0;
        return qtrue;
    }
    if (earlier->failed || !earlier->count) return qtrue;
    if (earlier->count > DK3_PREPARATION_EXCLUSION_NAMES - batch->excludedCount) return qfalse;
    total = batch->excludedCount + earlier->count;
    names = realloc(batch->excluded, (size_t)total * sizeof(*names));
    if (!names) return qfalse;
    batch->excluded = names;
    for (i = 0; i < earlier->count; ++i)
        memcpy(batch->excluded[batch->excludedCount + i], earlier->images[i].name, MAX_QPATH);
    batch->excludedCount = total;
    return qtrue;
}
qboolean R_QueuePNG(dkImageBatch_t *batch, const char *name) {
    int i;
    if (!batch || !name || !name[0] || strlen(name) >= MAX_QPATH) return qfalse;
    for (i = 0; i < batch->excludedCount; ++i) if (!strcmp(batch->excluded[i], name)) {
        ++batch->excludedRequests;
        return qtrue;
    }
    for (i = 0; i < batch->count; ++i)
        if (!strcmp(batch->images[i].name, name)) return qtrue;
    if (batch->count == batch->capacity || batch->read || batch->decoding) return qfalse;
    Q_strncpyz(batch->images[batch->count++].name, name, MAX_QPATH);
    return qtrue;
}
static void *R_DecodePreparedPNG(void *argument) {
    dkImageBatch_t *batch = argument;
    dkPreparedImage_t *image = &batch->images[batch->next];
    struct timespec start, end;
    clock_gettime(CLOCK_MONOTONIC, &start);
    R_DecodePNG(batch->input, batch->length, &image->pixels, &image->width, &image->height,
                DK3_MATERIAL_PIXEL_BUDGET - batch->bytes);
    clock_gettime(CLOCK_MONOTONIC, &end);
    batch->decodeMilliseconds = (int)((end.tv_sec - start.tv_sec) * 1000 + (end.tv_nsec - start.tv_nsec) / 1000000);
    __atomic_store_n(&batch->done, 1, __ATOMIC_RELEASE);
    return NULL;
}
static int R_PreparedPNGFailed(dkImageBatch_t *batch) {
    batch->failed = qtrue;
    ri.Printf(PRINT_WARNING, "Resident PNG preparation failed: %s (material pixel budget %u bytes)\n",
              batch->images[batch->next].name, DK3_MATERIAL_PIXEL_BUDGET);
    return -1;
}
static int R_CompletePreparedPNG(dkImageBatch_t *batch, qboolean cached) {
    dkPreparedImage_t *image = &batch->images[batch->next];
    /* Retention copies on the owner before releasing its immutable read input.
     * The batch keeps independent pixels, including across a cache resize. */
    if (batch->useCache && image->pixels && !cached)
        R_RetainPreparedPNG(batch->input, batch->length, image->pixels, image->width, image->height);
    ri.EndBackgroundRead(batch->read);
    batch->read = NULL;
    batch->input = NULL;
    if (!image->pixels) return R_PreparedPNGFailed(batch);
    ri.Printf(PRINT_DEVELOPER, "dk3 prepared PNG: name=%s size=%dx%d worker_decode_ms=%d cache_hit=%d\n",
              image->name, image->width, image->height, batch->decodeMilliseconds, cached);
    batch->bytes += (size_t)image->width * image->height * 4;
    ++batch->next;
    return batch->next == batch->count ? 1 : 0;
}
int R_PollImageBatch(dkImageBatch_t *batch) {
    int result;
    if (!batch || batch->failed) return -1;
    /* Queue construction is complete; no source batch or copied names need
     * survive dispatch, cancellation, or later slot reuse. */
    if (batch->excluded) {
        if (batch->excludedRequests)
            ri.Printf(PRINT_DEVELOPER, "dk3 prepared PNG exclusions: requests=%d queued=%d\n",
                      batch->excludedRequests, batch->count);
        free(batch->excluded);
        batch->excluded = NULL;
        batch->excludedCount = 0;
        batch->excludedRequests = 0;
    }
    if (batch->next == batch->count) return 1;
    if (batch->decoding) {
        if (!__atomic_load_n(&batch->done, __ATOMIC_ACQUIRE)) return 0;
        pthread_join(batch->thread, NULL);
        batch->decoding = qfalse;
        return R_CompletePreparedPNG(batch, qfalse);
    }
    if (!batch->read) {
        batch->read = ri.BeginBackgroundRead(batch->images[batch->next].name, 128 * 1024 * 1024);
        if (!batch->read) goto failed;
        return 0;
    }
    result = ri.PollBackgroundRead(batch->read, &batch->input, &batch->length);
    if (result < 0) goto failed;
    if (!result) return 0;
    if (batch->useCache) {
        dkPreparedImage_t *image = &batch->images[batch->next];
        if (R_CopyCachedPNG(batch->input, batch->length, &image->pixels, &image->width, &image->height,
                            DK3_MATERIAL_PIXEL_BUDGET - batch->bytes)) {
            batch->decodeMilliseconds = 0;
            return R_CompletePreparedPNG(batch, qtrue);
        }
    }
    __atomic_store_n(&batch->done, 0, __ATOMIC_RELAXED);
    if (pthread_create(&batch->thread, NULL, R_DecodePreparedPNG, batch)) goto failed;
    batch->decoding = qtrue;
    return 0;
failed:
    return R_PreparedPNGFailed(batch);
}
void R_SelectImageBatch(dkImageBatch_t *batch) { selectedBatch = batch; }
static dkPreparedImage_t *R_FindPreparedPNG(const char *name) {
    int i;
    if (!name || !selectedBatch || selectedBatch->next != selectedBatch->count || selectedBatch->failed) return NULL;
    for (i = 0; i < selectedBatch->count; ++i) {
        dkPreparedImage_t *image = &selectedBatch->images[i];
        if (!strcmp(image->name, name) && image->pixels) return image;
    }
    return NULL;
}
qboolean R_BorrowPreparedPNG(const char *name, const byte **pic, int *width, int *height) {
    dkPreparedImage_t *image;
    if (width) *width = 0;
    if (height) *height = 0;
    if (!pic) return qfalse;
    *pic = NULL;
    image = R_FindPreparedPNG(name);
    if (!image) return qfalse;
    *pic = image->pixels;
    if (width) *width = image->width;
    if (height) *height = image->height;
    return qtrue;
}
qboolean R_TakePreparedPNG(const char *name, byte **pic, int *width, int *height) {
    dkPreparedImage_t *image = R_FindPreparedPNG(name);
    if (image) {
        size_t size = (size_t)image->width * image->height * 4;
        *pic = ri.Malloc(size);
        memcpy(*pic, image->pixels, size);
        if (width) *width = image->width;
        if (height) *height = image->height;
        /* Keep this batch's pixels for aliases resolving to the same PNG. */
        return qtrue;
    }
    return qfalse;
}
void R_FreeImageBatch(dkImageBatch_t *batch) {
    int i;
    if (!batch) return;
    if (selectedBatch == batch) selectedBatch = NULL;
    /* On cancellation, join before releasing immutable input or worker output. */
    if (batch->decoding) pthread_join(batch->thread, NULL);
    if (batch->read) ri.EndBackgroundRead(batch->read);
    for (i = 0; i < batch->count; ++i) free(batch->images[i].pixels);
    free(batch->excluded);
    free(batch);
}
