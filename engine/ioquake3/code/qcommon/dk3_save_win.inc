/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Windows implementation of the portable save stream's local file operations. */
#include <windows.h>

#define DK3_SAVE_MAX (256 * 1024 * 1024)

static qboolean DK3_SaveName(const char *slot) {
    const char *p;
    if (!slot || !*slot || strlen(slot) > 48) return qfalse;
    for (p = slot; *p; ++p) if (!((*p >= 'a' && *p <= 'z') || (*p >= '0' && *p <= '9') || *p == '_' || *p == '-')) return qfalse;
    return qtrue;
}

static qboolean DK3_SavePath(char *out, size_t capacity, const char *name) {
    char directory[MAX_OSPATH];
    Q_strncpyz(directory, FS_BuildOSPath(fs_homestatepath->string, fs_gamedir, "saves/"), sizeof(directory));
    if (FS_CreatePath(directory)) return qfalse;
    if (strlen(directory) + strlen(name) + 1 > capacity) return qfalse;
    Com_sprintf(out, (int)capacity, "%s%s", directory, name);
    return qtrue;
}

static qboolean DK3_SaveRegular(const char *path) {
    DWORD attributes = GetFileAttributesA(path);
    return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT));
}

static qboolean DK3_SaveMove(const char *from, const char *to) {
    return MoveFileExA(from, to, MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

static qboolean DK3_SaveRotate(const char *current, const char *temporary, const char *previous, const char *backup) {
    DeleteFileA(backup);
    if (DK3_SaveRegular(current)) {
        if (!CreateHardLinkA(backup, current, NULL)) return qfalse;
        if (!DK3_SaveMove(backup, previous)) return qfalse;
    } else if (GetFileAttributesA(current) != INVALID_FILE_ATTRIBUTES) return qfalse;
    return DK3_SaveMove(temporary, current);
}

int FS_DK3SaveWrite(int version, const char *slot, const void *data, int length) {
    char name[64], current[MAX_OSPATH], temporary[MAX_OSPATH], previous[MAX_OSPATH], backup[MAX_OSPATH];
    HANDLE file;
    int offset = 0;
    if ((version != 1 && version != 2) || !DK3_SaveName(slot) || length < 1 || length > DK3_SAVE_MAX || !data) return -1;
    Com_sprintf(name, sizeof(name), "%s.%s", slot, version == 2 ? "info" : "sav");
    if (!DK3_SavePath(current, sizeof(current), name)) return -1;
    Com_sprintf(name, sizeof(name), "%s.%s.pending", slot, version == 2 ? "info" : "sav");
    if (!DK3_SavePath(temporary, sizeof(temporary), name)) return -1;
    Com_sprintf(name, sizeof(name), "%s.%s.previous", slot, version == 2 ? "info" : "sav");
    if (!DK3_SavePath(previous, sizeof(previous), name)) return -1;
    Com_sprintf(name, sizeof(name), "%s.%s.previous.pending", slot, version == 2 ? "info" : "sav");
    if (!DK3_SavePath(backup, sizeof(backup), name)) return -1;
    file = CreateFileA(temporary, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (file == INVALID_HANDLE_VALUE) return -1;
    while (offset < length) {
        DWORD written = 0;
        if (!WriteFile(file, (const byte *)data + offset, (DWORD)(length - offset), &written, NULL) || written == 0) break;
        offset += (int)written;
    }
    if (offset != length || !FlushFileBuffers(file)) offset = -1;
    CloseHandle(file);
    if (offset == length && DK3_SaveRotate(current, temporary, previous, backup)) return length;
    DeleteFileA(temporary);
    Com_Printf("dk3 save %s: write failed (Windows error %lu)\n", slot, GetLastError());
    return -1;
}

int FS_DK3SaveLink(const char *from, const char *to) {
    char name[80], source[MAX_OSPATH], current[MAX_OSPATH], temporary[MAX_OSPATH], previous[MAX_OSPATH], backup[MAX_OSPATH];
    if (!DK3_SaveName(from) || !DK3_SaveName(to) || !strcmp(from, to)) return -1;
    Com_sprintf(name, sizeof(name), "%s.sav", from);
    if (!DK3_SavePath(source, sizeof(source), name) || !DK3_SaveRegular(source)) return -1;
    Com_sprintf(name, sizeof(name), "%s.sav", to);
    if (!DK3_SavePath(current, sizeof(current), name)) return -1;
    Com_sprintf(name, sizeof(name), "%s.sav.pending", to);
    if (!DK3_SavePath(temporary, sizeof(temporary), name)) return -1;
    Com_sprintf(name, sizeof(name), "%s.sav.previous", to);
    if (!DK3_SavePath(previous, sizeof(previous), name)) return -1;
    Com_sprintf(name, sizeof(name), "%s.sav.previous.pending", to);
    if (!DK3_SavePath(backup, sizeof(backup), name)) return -1;
    DeleteFileA(temporary);
    if (CreateHardLinkA(temporary, source, NULL) && DK3_SaveRotate(current, temporary, previous, backup)) return 0;
    DeleteFileA(temporary);
    Com_Printf("dk3 save %s: link from %s failed (Windows error %lu)\n", to, from, GetLastError());
    return -1;
}

int FS_DK3SaveRead(int version, const char *slot, void *data, int capacity, qboolean previous) {
    char name[80], path[MAX_OSPATH];
    HANDLE file;
    LARGE_INTEGER size;
    int offset = 0;
    if ((version != 1 && version != 2) || !DK3_SaveName(slot) || capacity < 1 || capacity > DK3_SAVE_MAX || !data) return -1;
    Com_sprintf(name, sizeof(name), "%s.%s%s", slot, version == 2 ? "info" : "sav", previous ? ".previous" : "");
    if (!DK3_SavePath(path, sizeof(path), name) || !DK3_SaveRegular(path)) return -1;
    file = CreateFileA(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (file == INVALID_HANDLE_VALUE) return -1;
    if (!GetFileSizeEx(file, &size) || size.QuadPart < 1 || size.QuadPart > capacity) offset = -1;
    else while (offset < size.QuadPart) {
        DWORD readBytes = 0;
        if (!ReadFile(file, (byte *)data + offset, (DWORD)(size.QuadPart - offset), &readBytes, NULL) || readBytes == 0) { offset = -1; break; }
        offset += (int)readBytes;
    }
    CloseHandle(file);
    return offset;
}
