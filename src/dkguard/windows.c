/* SPDX-License-Identifier: GPL-2.0-or-later */
/* Windows process supervisor for release conversion and game launches. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>

static int option(const wchar_t *value, const wchar_t *name) {
    return wcscmp(value, name) == 0;
}

static uint64_t amount(const wchar_t *value) {
    wchar_t *end;
    unsigned long long count = wcstoull(value, &end, 10);
    uint64_t multiplier = 1;
    if (end == value || count == 0) return 0;
    if (*end == L'K') multiplier = 1024ULL;
    else if (*end == L'M') multiplier = 1024ULL * 1024ULL;
    else if (*end == L'G') multiplier = 1024ULL * 1024ULL * 1024ULL;
    else if (*end == L'T') multiplier = 1024ULL * 1024ULL * 1024ULL * 1024ULL;
    else if (*end != L'\0') return 0;
    if (*end && end[1]) return 0;
    if (count > UINT64_MAX / multiplier) return 0;
    return count * multiplier;
}

static DWORD duration(const wchar_t *value) {
    wchar_t *end;
    unsigned long long count = wcstoull(value, &end, 10);
    uint64_t multiplier = 1000;
    if (end == value || count == 0) return 0;
    if (wcscmp(end, L"ms") == 0) multiplier = 1;
    else if (wcscmp(end, L"s") == 0 || *end == L'\0') multiplier = 1000;
    else if (wcscmp(end, L"m") == 0) multiplier = 60 * 1000;
    else if (wcscmp(end, L"h") == 0) multiplier = 60 * 60 * 1000;
    else return 0;
    if (count > (uint64_t)MAXDWORD / multiplier) return 0;
    return (DWORD)(count * multiplier);
}

/* Quote one argv item according to the Windows CRT command-line rules. */
static int append_arg(wchar_t *line, size_t capacity, size_t *used, const wchar_t *arg) {
    size_t slashes = 0;
#define PUT(character) do { if (*used + 1 >= capacity) return 0; line[(*used)++] = (character); } while (0)
    if (*used) PUT(L' ');
    PUT(L'"');
    for (const wchar_t *p = arg; *p; ++p) {
        if (*p == L'\\') { ++slashes; continue; }
        if (*p == L'"') {
            while (slashes--) PUT(L'\\');
            PUT(L'\\');
            PUT(L'"');
            slashes = 0;
            continue;
        }
        while (slashes--) PUT(L'\\');
        slashes = 0;
        PUT(*p);
    }
    while (slashes--) { PUT(L'\\'); PUT(L'\\'); }
    PUT(L'"');
    line[*used] = L'\0';
#undef PUT
    return 1;
}

int main(void) {
    int argc, command = 1, gpu = 0, no_wait = 0, headless = 0;
    uint64_t memory = 0;
    DWORD timeout = INFINITE, result = 125;
    wchar_t **argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    HANDLE mutex = NULL, job = NULL;
    PROCESS_INFORMATION child = {0};
    STARTUPINFOW startup = {0};
    wchar_t *line = NULL;
    if (!argv) return 125;
    while (command < argc) {
        if (option(argv[command], L"--")) { ++command; break; }
        if (option(argv[command], L"--gpu")) gpu = 1;
        else if (option(argv[command], L"--no-wait")) no_wait = 1;
        else if (option(argv[command], L"--headless")) headless = 1;
        else if (option(argv[command], L"--lock-file") || option(argv[command], L"--screen")) {
            if (++command >= argc) goto usage;
        } else if (option(argv[command], L"--mem")) {
            if (++command >= argc || !(memory = amount(argv[command]))) goto usage;
        } else if (option(argv[command], L"--timeout")) {
            if (++command >= argc || !(timeout = duration(argv[command]))) goto usage;
        } else if (argv[command][0] == L'-') goto usage;
        else break;
        ++command;
    }
    if (command == argc || (headless && gpu)) goto usage;
    if (gpu) {
        mutex = CreateMutexW(NULL, FALSE, L"Local\\dk3_gpu_lock");
        if (!mutex) goto cleanup;
        if (WaitForSingleObject(mutex, no_wait ? 0 : INFINITE) != WAIT_OBJECT_0) {
            result = 75;
            goto cleanup;
        }
    }
    if (headless) {
        SetEnvironmentVariableW(L"SDL_AUDIODRIVER", L"dummy");
        SetEnvironmentVariableW(L"LIBGL_ALWAYS_SOFTWARE", L"1");
    }
    line = (wchar_t *)calloc(32768, sizeof(wchar_t));
    if (!line) goto cleanup;
    size_t used = 0;
    for (int i = command; i < argc; ++i) {
        if (!append_arg(line, 32768, &used, argv[i])) goto cleanup;
    }
    job = CreateJobObjectW(NULL, NULL);
    if (!job) goto cleanup;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits = {0};
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if (memory) {
        limits.BasicLimitInformation.LimitFlags |= JOB_OBJECT_LIMIT_JOB_MEMORY;
        limits.JobMemoryLimit = (SIZE_T)memory;
    }
    if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &limits, sizeof(limits))) goto cleanup;
    startup.cb = sizeof(startup);
    if (!CreateProcessW(NULL, line, NULL, NULL, TRUE, CREATE_SUSPENDED | CREATE_NEW_PROCESS_GROUP,
                        NULL, NULL, &startup, &child)) goto cleanup;
    if (!AssignProcessToJobObject(job, child.hProcess)) goto cleanup;
    ResumeThread(child.hThread);
    if (WaitForSingleObject(child.hProcess, timeout) == WAIT_TIMEOUT) {
        TerminateJobObject(job, 124);
        result = 124;
    } else if (!GetExitCodeProcess(child.hProcess, &result)) result = 125;
    goto cleanup;
usage:
    fwprintf(stderr, L"usage: dkguard [--gpu [--no-wait]] [--mem CAP] [--timeout DURATION] [--headless] -- COMMAND [ARG...]\n");
    result = 64;
cleanup:
    if (child.hThread) CloseHandle(child.hThread);
    if (child.hProcess) CloseHandle(child.hProcess);
    if (job) CloseHandle(job);
    if (mutex) { ReleaseMutex(mutex); CloseHandle(mutex); }
    free(line);
    LocalFree(argv);
    return (int)result;
}
