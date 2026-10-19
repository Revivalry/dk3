# Update an installation

Code updates and asset conversion are separate operations. Use this guide after
you have built dk3 and converted your game data once.

## Update code without reconverting assets

After updating your checkout, run:

```sh
zig build play -Dpython=.venv/bin/python
```

The build compiles changed code, creates an installation from the completed asset
cache and launches it. Settings and saves remain in the play profile.

To prepare the installation without launching it, use:

```sh
zig build play-install -Dpython=.venv/bin/python
```

## Update converted data

Rerun conversion when converter changes affect your maps, navigation or other
packages. Use the same input directory and profile you used originally:

```sh
zig build assets -Dpython=.venv/bin/python -DDK_DATA=/path/to/daikatana/data -Dasset-profile=retail
zig build play-install -Dpython=.venv/bin/python
```

Substitute `1.3` if you use that profile. Completed unchanged stages are reused.
The completed generation becomes `zig-out/assets/current`.

## Keep your profile

Before deleting build output or switching installations, back up:

```text
zig-out/native-dev/play/home/
zig-out/native-dev/play/state/
```

Changing converted map geometry can invalidate saves for those maps. Keep the
previous installation and saves together if you need to return to them.

See [Files and directories](../reference/paths.md) for the asset-cache and profile layout.
