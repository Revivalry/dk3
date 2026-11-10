/* SPDX-License-Identifier: GPL-2.0-or-later
 * Exercise the actual engine collision loader, not a second implementation. */
#include "q_shared.h"
#include "qcommon.h"
#include "owned_memory.h"
#include "../../engine/ioquake3/code/renderercommon/dk3_inline_handles.h"
#include "../../engine/ioquake3/code/server/sv_world.c"

static sharedEntity_t collisionEntity;
sharedEntity_t *SV_GentityNum(int num) {
    if (num != 1) abort();
    return &collisionEntity;
}

#define CHECK(condition) do { if (!(condition)) { fprintf(stderr, "collision worlds: line %d: %s\n", __LINE__, #condition); exit(1); } } while (0)

static void inlineIdentities(void) {
    unsigned int owner, model, generation, decodedOwner, decodedModel, handle, previous = 0;
    for (owner = 0; owner < 128; ++owner) for (model = 0; model < 512; ++model) {
        handle = DK3_InlineHandle(17, owner, model);
        CHECK(handle > previous && handle <= 0x7fffffffu);
        CHECK(DK3_InlineParts(handle, &generation, &decodedOwner, &decodedModel));
        CHECK(generation == 17 && decodedOwner == owner && decodedModel == model);
        CHECK(handle != DK3_InlineHandle(18, owner, model));
        previous = handle;
    }
    CHECK(DK3_InlineHandle(DK3_RENDER_GENERATION_MAX, 127, 511) == 0x7fffffffu);
    CHECK(!DK3_InlineHandle(0, 0, 0) && !DK3_InlineHandle(DK3_RENDER_GENERATION_MAX + 1, 0, 0));
    CHECK(!DK3_InlineHandle(1, 128, 0) && !DK3_InlineHandle(1, 0, 512));
    CHECK(!DK3_InlineParts(1023, &generation, &decodedOwner, &decodedModel));
    CHECK(!DK3_InlineParts(DK3_INLINE_TAG, &generation, &decodedOwner, &decodedModel));
    CHECK(!DK3_InlineParts(0xffffffffu, &generation, &decodedOwner, &decodedModel));
    puts("resident inline identities: all 65536 owner/model pairs, generations and malformed handles passed");
}

static void ownedMemory(void) {
    ownedHeap_t renderer = {0}, navigation = {0};
    byte *images[16], *routes;
    int i;
    for (i = 0; i < 16; ++i) {
        images[i] = Owned_Alloc(&renderer, 4 * 1024 * 1024);
        CHECK(images[i]);
        CHECK((uintptr_t)images[i] % __alignof__(long double) == 0);
        images[i][0] = i;
        images[i][4 * 1024 * 1024 - 1] = i;
    }
    routes = Owned_Alloc(&navigation, 1123584);
    CHECK(routes && renderer.bytes == 64 * 1024 * 1024);
    routes[0] = 77;
    /* Free a middle block and the list head, then cancel all remaining work.
     * Navigation survives renderer shutdown and can be freed independently. */
    Owned_Free(images[7]);
    Owned_Free(images[15]);
    CHECK(images[6][0] == 6 && images[8][4 * 1024 * 1024 - 1] == 8);
    Owned_Clear(&renderer);
    CHECK(renderer.bytes == 0 && renderer.first == NULL && routes[0] == 77);
    Owned_Clear(&renderer);
    Owned_Free(routes);
    CHECK(navigation.bytes == 0 && navigation.first == NULL);
    CHECK(Owned_Alloc(&renderer, -1) == NULL);
    puts("resident memory: allocations beyond single-map zone, alignment, interleaved release and independent cancellation passed");
}

void QDECL Com_Printf(const char *format, ...) { (void)format; }
void QDECL Com_DPrintf(const char *format, ...) { (void)format; }
void QDECL Com_Error(int code, const char *format, ...) {
    va_list args;
    (void)code;
    va_start(args, format); vfprintf(stderr, format, args); va_end(args);
    exit(2);
}
#undef Z_Malloc
void *Z_Malloc(int size) { void *p = calloc(1, size ? size : 1); CHECK(p); return p; }
void *Z_MallocDebug(int size, char *label, char *file, int line) {
    (void)label; (void)file; (void)line; return Z_Malloc(size);
}
void Z_Free(void *p) { free(p); }
void BotDrawDebugPolygons(void (*drawPoly)(int, int, float *), int value) { (void)drawPoly; (void)value; }
cvar_t *Cvar_Get(const char *name, const char *value, int flags) {
    static cvar_t disabled, enabled = { .integer = 1, .value = 1 };
    (void)name; (void)flags;
    return atoi(value) ? &enabled : &disabled;
}
long FS_ReadFile(const char *name, void **bytes) { (void)name; *bytes = NULL; return -1; }
void FS_FreeFile(void *bytes) { free(bytes); }
fsReadJob_t *FS_BeginBackgroundRead(const char *path, int maximum) { (void)path; (void)maximum; return NULL; }
int FS_PollBackgroundRead(fsReadJob_t *job, const void **bytes, int *length) { (void)job; *bytes = NULL; *length = 0; return -1; }
void FS_EndBackgroundRead(fsReadJob_t *job) { CHECK(!job); }

static int append(byte *bytes, int *at, int lump, const void *data, int length) {
    dheader_t *header = (dheader_t *)bytes;
    header->lumps[lump].fileofs = *at;
    header->lumps[lump].filelen = length;
    if (length) memcpy(bytes + *at, data, length);
    *at += (length + 3) & ~3;
    return *at;
}

static int fixture(byte *bytes, float height, const char *message) {
    int i, at = sizeof(dheader_t), leafBrush = 0;
    dheader_t *header = (dheader_t *)bytes;
    dshader_t shader = { .contentFlags = CONTENTS_SOLID };
    dplane_t planes[6] = {0};
    dnode_t node = { .children = {-1, -1} };
    dleaf_t leaf = { .numLeafBrushes = 1 };
    dbrush_t brush = { .numSides = 6 };
    dbrushside_t sides[6] = {0};
    dmodel_t models[2] = {0};
    dsurface_t surface = { .surfaceType = MST_PLANAR };
    memset(bytes, 0, 4096);
    header->ident = BSP_IDENT;
    header->version = BSP_VERSION;
    for (i = 0; i < 6; ++i) {
        planes[i].normal[i / 2] = i & 1 ? 1 : -1;
        planes[i].dist = i < 4 ? 32 : (i == 4 ? 32 - height : height);
        sides[i].planeNum = i;
    }
    for (i = 0; i < 2; ++i) {
        VectorSet(models[i].mins, -32, -32, height - 32);
        VectorSet(models[i].maxs, 32, 32, height);
        models[i].numBrushes = 1;
        models[i].numSurfaces = 1;
    }
    append(bytes, &at, LUMP_ENTITIES, message, strlen(message) + 1);
    append(bytes, &at, LUMP_SHADERS, &shader, sizeof(shader));
    append(bytes, &at, LUMP_PLANES, planes, sizeof(planes));
    append(bytes, &at, LUMP_NODES, &node, sizeof(node));
    append(bytes, &at, LUMP_LEAFS, &leaf, sizeof(leaf));
    append(bytes, &at, LUMP_LEAFBRUSHES, &leafBrush, sizeof(leafBrush));
    append(bytes, &at, LUMP_MODELS, models, sizeof(models));
    append(bytes, &at, LUMP_BRUSHES, &brush, sizeof(brush));
    append(bytes, &at, LUMP_BRUSHSIDES, sides, sizeof(sides));
    /* Rendered planar faces are not collision patches and must not disable
     * the exact rectangular-brush path (real door models have such faces). */
    append(bytes, &at, LUMP_SURFACES, &surface, sizeof(surface));
    return at;
}

static void hit(unsigned int world, int model, float height) {
    trace_t trace;
    vec3_t start = {0, 0, 100}, end = {0, 0, -100}, zero = {0};
    CHECK(CM_SelectWorld(world));
    CM_BoxTrace(&trace, start, end, zero, zero, model, CONTENTS_SOLID, qfalse);
    CHECK(!trace.startsolid && trace.fraction > 0 && trace.fraction < 1);
    CHECK(fabs(trace.endpos[2] - height - 0.125f) < 0.001f);
}

static void rotatingHatch(void) {
    byte bytes[4096];
    int length = fixture(bytes, 48, "rotating rectangular hatch"), i;
    dheader_t *header = (dheader_t *)bytes;
    dplane_t *planes = (dplane_t *)(bytes + header->lumps[LUMP_PLANES].fileofs);
    dmodel_t *models = (dmodel_t *)(bytes + header->lumps[LUMP_MODELS].fileofs);
    vec3_t low = {-24, 0, 0}, high = {24, 4, 48};
    vec3_t origin = {1520, 848, 344}, angles = {0, 0, 120};
    vec3_t mins = {-15, -15, -24}, maxs = {15, 15, 4};
    vec3_t start = {1520, 896, 376}, end = {1520, 800, 376};
    trace_t trace;
    unsigned int world;
    for (i = 0; i < 6; ++i) planes[i].dist = i & 1 ? high[i / 2] : -low[i / 2];
    for (i = 0; i < 2; ++i) { VectorCopy(low, models[i].mins); VectorCopy(high, models[i].maxs); }
    world = CM_LoadWorldBytes("maps/hatch.bsp", bytes, length);
    CHECK(world && CM_SelectWorld(world));
    /* The open hatch folds below z=344; the crawling feet stay above z=352.
     * Endpoint-only rotation incorrectly reports a collision with this sweep. */
    CM_TransformedBoxTrace(&trace, start, end, mins, maxs, 1, CONTENTS_SOLID, origin, angles, qfalse);
    CHECK(trace.fraction == 1 && !trace.startsolid && !trace.allsolid);
    angles[2] = 0;
    CM_TransformedBoxTrace(&trace, start, end, mins, maxs, 1, CONTENTS_SOLID, origin, angles, qfalse);
    CHECK(trace.fraction > 0 && trace.fraction < 1 && !trace.startsolid);
    angles[2] = 120;
    VectorSet(start, 1520, 826, 334); VectorCopy(start, end);
    CM_TransformedBoxTrace(&trace, start, end, mins, maxs, 1, CONTENTS_SOLID, origin, angles, qfalse);
    CHECK(trace.startsolid && trace.allsolid && trace.fraction == 0);
    end[1] = 720;
    CM_TransformedBoxTrace(&trace, start, end, mins, maxs, 1, CONTENTS_SOLID, origin, angles, qfalse);
    CHECK(trace.startsolid && !trace.allsolid && trace.fraction == 1);
    /* Crossing the folded panel must still block, with a normalized normal. */
    VectorSet(start, 1520, 896, 334); VectorSet(end, 1520, 760, 334);
    CM_TransformedBoxTrace(&trace, start, end, mins, maxs, 1, CONTENTS_SOLID, origin, angles, qfalse);
    CHECK(!trace.startsolid && trace.fraction > 0 && trace.fraction < 1);
    CHECK(fabs(VectorLengthSquared(trace.plane.normal) - 1) < 0.0001);
    CM_TransformedBoxTrace(&trace, start, end, mins, maxs, 1, CONTENTS_WATER, origin, angles, qfalse);
    CHECK(trace.fraction == 1 && !trace.startsolid);
    puts("rotated rectangular brushes: open clearance, closed blocking, overlap, escape, folded-panel sweep and content mask passed");
}

static void entityContents(void) {
    trace_t trace;
    vec3_t start = {980, 0, 0}, end = {1020, 0, 0}, point = {1000, 0, 0};
    memset(&collisionEntity, 0, sizeof(collisionEntity));
    /* Broadphase slots identify geometry independently of snapshot metadata. */
    collisionEntity.s.number = 17;
    VectorSet(collisionEntity.r.mins, -8, -8, -16);
    VectorSet(collisionEntity.r.maxs, 8, 8, 16);
    VectorCopy(point, collisionEntity.r.currentOrigin);
    collisionEntity.r.contents = CONTENTS_SOLID;
    SV_ClipToEntity(&trace, start, vec3_origin, vec3_origin, end, 1, CONTENTS_SOLID, qfalse);
    CHECK(trace.fraction < 1 && trace.contents == CONTENTS_SOLID && trace.entityNum == 1);
    SV_ClipToEntity(&trace, start, vec3_origin, vec3_origin, end, 1, CONTENTS_BODY, qfalse);
    CHECK(trace.fraction == 1 && !trace.startsolid);
    SV_ClipToEntity(&trace, point, vec3_origin, vec3_origin, point, 1, CONTENTS_SOLID, qfalse);
    CHECK(trace.startsolid && trace.contents == CONTENTS_SOLID);
    collisionEntity.r.contents = CONTENTS_TRIGGER;
    SV_ClipToEntity(&trace, start, vec3_origin, vec3_origin, end, 1, CONTENTS_SOLID, qfalse);
    CHECK(trace.fraction == 1 && !trace.startsolid);
    SV_ClipToEntity(&trace, start, vec3_origin, vec3_origin, end, 1, CONTENTS_TRIGGER, qfalse);
    CHECK(trace.fraction < 1 && trace.contents == CONTENTS_TRIGGER);
    collisionEntity.r.svFlags = SVF_CAPSULE;
    collisionEntity.r.contents = CONTENTS_PLAYERCLIP;
    SV_ClipToEntity(&trace, start, vec3_origin, vec3_origin, end, 1, CONTENTS_PLAYERCLIP, qfalse);
    CHECK(trace.fraction < 1 && trace.contents == CONTENTS_PLAYERCLIP);
    puts("entity collision: solid props, body filtering, overlap, triggers and capsule contents passed");
}

int main(void) {
    byte bytes[4096];
    unsigned int base = CM_CurrentWorld(), a, b, replacement;
    int length = fixture(bytes, 0, "world a");
    a = CM_LoadWorldBytes("maps/a.bsp", bytes, length);
    CHECK(a && CM_CurrentWorld() == base);
    CHECK(CM_WorldBytes(a) > 0);
    length = fixture(bytes, 50, "world b");
    b = CM_LoadWorldBytes("maps/b.bsp", bytes, length);
    CHECK(b && b != a && CM_CurrentWorld() == base);
    hit(a, 0, 0); hit(b, 0, 50); hit(a, 1, 0); hit(b, 1, 50);
    entityContents();
    CHECK(!strcmp(CM_EntityString(), "world b"));
    CHECK(!CM_ReleaseWorld(b)); /* selected world is pinned */
    CHECK(CM_SelectWorld(base));
    CHECK(CM_ReleaseWorld(a));
    CHECK(!CM_SelectWorld(a) && CM_PollWorld(a) == -1 && !CM_WorldBytes(a));
    replacement = CM_LoadWorldBytes("maps/a.bsp", bytes, length);
    CHECK(replacement && replacement != a && !CM_SelectWorld(a));
    ((dheader_t *)bytes)->lumps[LUMP_PLANES].filelen = 100000;
    CHECK(!CM_LoadWorldBytes("maps/bad.bsp", bytes, length));
    hit(b, 0, 50);
    CM_ClearMap();
    CHECK(!CM_SelectWorld(b) && !CM_SelectWorld(replacement) && !CM_SelectWorld(base));
    CHECK(CM_CurrentWorld() != base);
    CM_ClearMap();
    rotatingHatch();
    CM_ClearMap();
    ownedMemory();
    inlineIdentities();
    puts("collision worlds: isolated geometry, inline models, pinned ownership, stale handles and malformed-header rejection passed");
    return 0;
}
