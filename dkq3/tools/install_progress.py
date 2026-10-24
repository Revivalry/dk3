"""Optional installer telemetry; converters remain usable without a terminal UI."""
import json
import os


STAGES = {'base': 'Game resources', 'images': 'Extracting images', 'textures': 'Packing textures',
          'maps': 'Converting maps', 'shaders': 'Building materials', 'models': 'Converting models',
          'sprites': 'Converting effects', 'hud': 'Building the interface', 'sound': 'Converting sounds',
          'music': 'Converting music and voices', 'game-data': 'Packing scripts and tables',
          'navigation': 'Building navigation'}


def emit(completed=None, total=None, detail='', *, stage=None, state='running', cached=False):
    path = os.environ.get('DK3_INSTALL_PROGRESS')
    if not path:
        return
    event = dict(stage=stage or os.environ.get('DK3_INSTALL_STAGE', ''), state=state,
                 completed=completed, total=total, detail=str(detail), cached=cached)
    # A single append per event also works with spawned workers. Telemetry must
    # never invalidate otherwise successful asset conversion.
    try:
        with open(path, 'a', encoding='utf-8') as stream:
            stream.write(json.dumps(event, ensure_ascii=True) + '\n')
    except OSError:
        pass


def tracked(iterable, total, detail=lambda item: ''):
    emit(0, total)
    for index, item in enumerate(iterable, 1):
        emit(index, total, detail(item))
        yield item
