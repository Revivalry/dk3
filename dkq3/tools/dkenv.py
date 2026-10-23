# SPDX-License-Identifier: GPL-2.0-or-later
"""Import this before diffusers.

The webui venv ships an xformers built for a different torch; its top-level
package imports fine but `xformers.ops` fails on a missing CUDA symbol, and
diffusers imports that unconditionally when it sees the package. Replace both
with stubs so the optional fast-attention path is simply never taken.
"""
import sys, types
from importlib.machinery import ModuleSpec

try:
    import xformers.ops  # noqa: F401
except Exception:
    m = types.ModuleType('xformers'); m.__version__ = '0.0.0'
    m.__spec__ = ModuleSpec('xformers', None)
    ops = types.ModuleType('xformers.ops')
    ops.__spec__ = ModuleSpec('xformers.ops', None)
    ops.memory_efficient_attention = None
    ops.MemoryEfficientAttentionFlashAttentionOp = None
    m.ops = ops
    sys.modules['xformers'] = m
    sys.modules['xformers.ops'] = ops
