/* SPDX-License-Identifier: GPL-2.0-or-later
 * Execute the actual botlib allocators and variable registry on LP64 and LLP64. */
#include "../../engine/ioquake3/code/qcommon/q_shared.h"
#include "../../engine/ioquake3/code/botlib/botlib.h"
#include "../../engine/ioquake3/code/botlib/l_memory.h"
#include "../../engine/ioquake3/code/botlib/l_libvar.h"
#include <assert.h>
#include <stdint.h>

botlib_import_t botimport;
static int allocations, releases;
static void *hunk;

static void *allocate(int size) {
    void *pointer = malloc(size);
    assert(pointer);
    memset(pointer, 0xa5, size);
    allocations++;
    return pointer;
}
static void release(void *pointer) { releases++; free(pointer); }
static void *allocate_hunk(int size) {
    assert(!hunk);
    hunk = allocate(size);
    return hunk;
}
int Q_stricmp(const char *left, const char *right) {
    while (*left && tolower((unsigned char)*left) == tolower((unsigned char)*right)) {
        left++;
        right++;
    }
    return tolower((unsigned char)*left) - tolower((unsigned char)*right);
}

int main(void) {
    struct payload { void *pointer; double value; };
    botimport.GetMemory = allocate;
    botimport.FreeMemory = release;
    botimport.HunkAlloc = allocate_hunk;
    for (int cleared = 0; cleared < 2; cleared++) {
        struct payload *value = cleared ? GetClearedMemory(sizeof(*value)) : GetMemory(sizeof(*value));
        assert((uintptr_t)value % _Alignof(struct payload) == 0);
        if (cleared) for (size_t i = 0; i < sizeof(*value); i++) assert(((byte *)value)[i] == 0);
        value->pointer = value;
        value->value = 42.5;
        assert(value->pointer == value && value->value == 42.5);
        FreeMemory(value);

        value = cleared ? GetClearedHunkMemory(sizeof(*value)) : GetHunkMemory(sizeof(*value));
        assert((uintptr_t)value % _Alignof(struct payload) == 0);
        if (cleared) for (size_t i = 0; i < sizeof(*value); i++) assert(((byte *)value)[i] == 0);
        value->pointer = value;
        value->value = 17.25;
        assert(value->pointer == value && value->value == 17.25);
        int before = releases;
        FreeMemory(value);
        assert(releases == before); /* Hunk tags must not free owner storage. */
        release(hunk);
        hunk = NULL;
    }
    LibVarSet("maxclients", "64");
    LibVarSet("maxentities", "4096");
    assert(LibVarGetValue("maxclients") == 64);
    assert(!strcmp(LibVarGetString("maxentities"), "4096"));
    LibVarSet("maxclients", "32");
    assert(LibVarGetValue("maxclients") == 32);
    LibVarDeAllocAll();
    assert(allocations == releases);
    puts("botlib memory: aligned heap/hunk payloads, clearing, tags and variable registry passed");
    return 0;
}
