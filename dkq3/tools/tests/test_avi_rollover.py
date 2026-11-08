# SPDX-License-Identifier: GPL-2.0-or-later
"""Execute the engine's actual AVI rollover function at signed-size boundaries."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]


class AviRollover(unittest.TestCase):
    def test_rollover_before_signed_addition_or_index_multiplication_overflows(self):
        source = (ROOT / 'engine/ioquake3/code/client/cl_avi.c').read_text()
        start = source.index('static qboolean CL_CheckFileSize( int bytesToAdd )')
        function = source[start:source.index('\n}', start) + 2]
        harness = r'''
#include <stdint.h>
#include <limits.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>
typedef int qboolean;
enum {qfalse, qtrue};
static struct {int fileSize, numIndices; char fileName[64];} afd;
static int closed, opened;
static qboolean CL_CloseAVI(void) {closed++; return qtrue;}
static const char *va(const char *format, ...) {
    static char text[128];
    va_list args;
    va_start(args, format);
    vsnprintf(text, sizeof(text), format, args);
    va_end(args);
    return text;
}
static qboolean CL_OpenAVIForWriting(const char *name) {
    assert(!strcmp(name, "capture.avi_"));
    opened++;
    return qtrue;
}
''' + function + r'''
int main(void) {
    strcpy(afd.fileName, "capture.avi");
    afd.fileSize = INT_MAX - 36;
    afd.numIndices = 1;
    assert(!CL_CheckFileSize(16)); /* Exactly the limit, including the index. */
    assert(closed == 0 && opened == 0);
    afd.fileSize++;
    assert(CL_CheckFileSize(16));
    afd.fileSize = INT_MAX - 100;
    assert(CL_CheckFileSize(200)); /* Previously overflowed before the check. */
    afd.fileSize = 0;
    afd.numIndices = INT_MAX;
    assert(CL_CheckFileSize(0));  /* Index arithmetic must widen as well. */
    assert(closed == 3 && opened == 3);
    return 0;
}
'''
        compiler = [shutil.which('cc')] if shutil.which('cc') else [shutil.which('zig'), 'cc']
        self.assertIsNotNone(compiler[0], 'The engine build requires a C compiler')
        with tempfile.TemporaryDirectory(prefix='dk3-avi-rollover-') as temporary:
            path = Path(temporary)
            (path / 'test.c').write_text(harness)
            subprocess.run(compiler + ['-std=c99', '-O1', '-fsanitize=undefined',
                '-fno-sanitize-recover=all', str(path / 'test.c'), '-o', str(path / 'test')], check=True)
            subprocess.run([str(path / 'test')], check=True)
