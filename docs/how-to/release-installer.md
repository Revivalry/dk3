# Release installer

The terminal installer reads the owner's Daikatana archives. It does not ship
original or converted game assets, and it keeps the original installation and
saves untouched. A completed dk3 installation keeps its own settings and saves.

## Install the latest release on Linux

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Revivalry/dk3/main/install.sh)"
```

The bootstrap downloads the latest Linux x86-64 bundle and `SHA256SUMS`, checks
the archive digest, then starts the interactive wizard. If GitHub CLI is
installed, it also verifies the signed GitHub build attestation. The command
keeps the terminal connected to the wizard so it can ask for your asset source
and installation directory. It does not need root privileges.

## Install a downloaded bundle

Extract a platform bundle and run `install.sh` on Linux or `install.cmd` on
Windows. Choose a Steam installation or enter the directory containing
`pak1.pak` through `pak3.pak`, as supplied by Steam. Retail `pak4.pak` is optional.
The wizard detects the retail or 1.3 asset profile,
asks for a separate destination, and converts assets locally. After installation,
the completion screen prints the exact command to run `play.sh` or `play.cmd` in
that destination. Linux installations also register **dk3** in the applications
menu, so GNOME and other XDG desktop environments can find it by name. The menu
entry is stored in `$XDG_DATA_HOME/applications` (normally
`~/.local/share/applications`) and uses the bundled dk3 icon. No root privileges
or terminal window are required to launch from the menu.

To add or repair the application entry for an existing Linux installation without
converting assets again, run the downloaded bundle with:

```sh
./install.sh --desktop-only --destination "$HOME/Games/dk3"
```

The public bootstrap forwards these same arguments. If you move an installation,
rerun this command with its new destination to update the menu entry.

The wizard shows numbered setup steps, an installation summary, and live progress
for each conversion stage. Maps, models, images, audio, navigation variants, and
optional HD texture production report completed work. Stages without a known total
show activity and elapsed time. The asset-stage count measures finished stages,
not a predicted fraction of installation time.

Detailed output is saved to `.installer/install.log` in the destination. Failures
show the last diagnostic lines and the log path. Ctrl+C cancels the active process;
rerun with the same destination to reuse completed conversions. Progress uses plain
text when output is redirected; `--plain` disables terminal animation explicitly.
The Rich UI and its pinned pure-Python dependencies are included in both bundles,
with their original wheel license metadata, and load before pip/NumPy setup.

Original textures are the default. The HD choice first builds a 4× RealESRGAN
overlay. The SDXL and FLUX choices add the corresponding local model stages.
These choices download Python packages and model weights, require a CUDA-capable
GPU, considerable disk space and GPU memory, and can run for many hours. The wizard asks before
downloading. Intermediate images stay in the installation so interrupted work
can resume. Model licenses and access terms are the owner's responsibility.

Vulkan starts with remaster lighting and ray tracing off. Resident worlds are
also off by default; enable them in Options for the next map load.

## Build a bundle

On every push to `main`, the [release workflow](https://github.com/Revivalry/dk3/blob/main/.github/workflows/release.yml)
builds Linux and Windows x86-64 bundles, generates SHA-256 checksums, signs
build provenance through GitHub artifact attestations, and publishes both ZIPs
in a commit-tagged release. Before signing and publication, it extracts the Linux
bundle and checks its manifest, multiplayer appearance catalog, and navigation
hull configuration using the bundled interpreter outside the source checkout.
The wizard also checks these conversion inputs before asking for the game data.
Conversion and final installation use the dependency-bearing private Python
environment; system NumPy is not required. Rerunning from a new temporary bundle
location preserves validated completed conversion stages.
No original game data or NVIDIA DLLs are included.
To verify a downloaded archive and its provenance:

```sh
sha256sum -c SHA256SUMS
gh attestation verify dk3-installer-linux-x64.zip -R Revivalry/dk3
```

When you download only one archive, compare its line in `SHA256SUMS` instead
of running the full `sha256sum -c` command. Use the Windows archive name in
the `gh` command for a Windows download.

For a local bundle, first build the selected target with Zig 0.16:

```sh
zig build -Doptimize=ReleaseSafe
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseSafe
```

The workflow obtains a digest-checked Python 3.12 standalone runtime, a
platform-matched NumPy wheel, pinned Rich terminal UI wheels, and FFmpeg 7 from the imageio-ffmpeg wheel for
each target. For manual packaging, supply a redistributable, relocatable Python runtime with
`venv` and `pip`, a static FFmpeg 7 binary and its license text, and a wheelhouse with
the pinned NumPy wheel matching that Python and target plus all universal wheels
listed in `dkq3/tools/requirements-tui.txt`. The packager checks
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
