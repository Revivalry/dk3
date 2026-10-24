"""Register a private Linux installation with XDG application menus."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


APPLICATION_ID = 'io.github.Revivalry.dk3'


def value(text):
    return str(text).replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t')


def argument(text):
    # Exec has both desktop-string escaping and argument quoting. It is not a
    # shell command: keep dollars/backticks literal and escape field-code '%'.
    quoted = ''.join('\\' + char if char in '\\"`$' else char for char in str(text))
    return value('"' + quoted.replace('%', '%%') + '"')


def register(destination, icon_source=None):
    if not sys.platform.startswith('linux'):
        return None
    destination = destination.resolve(strict=True)
    launcher = destination / 'play.sh'
    if not launcher.is_file() or not (destination / 'play/current/installation.json').is_file():
        raise ValueError(f'no completed dk3 installation at {destination}')
    icon = destination / 'share/dk3/dk3.svg'
    if icon_source is not None:
        icon.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(icon_source, icon)
    if not icon.is_file():
        raise ValueError(f'installation icon is missing: {icon}')
    configured = Path(os.environ.get('XDG_DATA_HOME') or '')
    data = configured if configured.is_absolute() else Path.home() / '.local/share'
    applications = data / 'applications'
    applications.mkdir(parents=True, exist_ok=True)
    entry = applications / (APPLICATION_ID + '.desktop')
    content = ('[Desktop Entry]\nType=Application\nName=dk3\n'
               'Comment=Play the independent Daikatana port\n'
               f'Exec=/bin/sh {argument(launcher)}\nTryExec=/bin/sh\n'
               f'Path={value(destination)}\nIcon={value(icon)}\n'
               'Terminal=false\nCategories=Game;ActionGame;\n'
               'Keywords=Daikatana;FPS;Shooter;\nStartupNotify=false\n')
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', prefix='.dk3-',
                                     dir=applications, delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(content)
    try:
        temporary.chmod(0o644)
        temporary.replace(entry)
    finally:
        temporary.unlink(missing_ok=True)
    updater = shutil.which('update-desktop-database')
    if updater:
        subprocess.run([updater, str(applications)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, check=False)
    return entry
