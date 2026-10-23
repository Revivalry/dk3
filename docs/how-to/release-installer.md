# Release installer

The terminal installer reads the owner's Daikatana archives. It does not ship
original or converted game assets, and it keeps the original installation and
saves untouched. A completed dk3 installation keeps its own settings and saves.

## Install a release bundle

Extract a platform bundle and run `install.sh` on Linux or `install.cmd` on
Windows. Choose a Steam installation or enter the directory containing
`pak1.pak` through `pak4.pak`. The wizard detects the retail or 1.3 asset profile,
asks for a separate destination, and converts assets locally. After installation,
run `play.sh` or `play.cmd` in that destination.

Original textures are the default. The HD choice first builds a 4× RealESRGAN
overlay. The SDXL and FLUX choices add the corresponding local model stages.
These choices download Python packages and model weights, require a CUDA-capable
GPU, considerable disk space and GPU memory, and can run for many hours. The wizard asks before
downloading. Intermediate images stay in the installation so interrupted work
can resume. Model licenses and access terms are the owner's responsibility.

Vulkan starts with remaster lighting and ray tracing off. Resident worlds are
also off by default; enable them in Options for the next map load.

## Build a bundle

First build the selected target with Zig 0.16:

```sh
zig build -Doptimize=ReleaseSafe
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe
```

For each target, supply a redistributable, relocatable Python runtime with
`venv` and `pip`, a static FFmpeg 7 binary and its license text, and a wheelhouse with
the pinned NumPy wheel matching that Python and target. The packager checks
required products and creates a ZIP without retail assets:

```sh
python3 dkq3/tools/release_bundle.py --platform windows-x64 \
  --prefix zig-out/windows-x64 --python-runtime /path/to/windows-python \
  --ffmpeg /path/to/ffmpeg.exe --ffmpeg-license /path/to/ffmpeg-license.txt \
  --wheelhouse /path/to/windows-wheels --out /path/to/dk3-windows-x64.zip
```

Use `--platform linux-x64`, `--prefix zig-out/native-dev`, and matching Linux
redistributables for the Linux archive. The launcher and installed private
Python environment use only the supplied runtime. The optional HD stage needs
network access for its Python packages and models. A successful cross build
checks compilation; Windows installation and gameplay still need a Windows run.
