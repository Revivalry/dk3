# HD weapon reconstruction

Sequence **hd-weapons-part-pipeline-374** implements the local weapon inventory,
source capture, generated-mesh candidate conversion, and isolated package path.
The 28 registered weapon classes are covered by the inventory. The first Glock
world-model candidate is **implemented; unverified**; no HD weapon is selected by
the normal launcher yet. First-person articulated models, the other 27 classes,
and in-game visual acceptance remain open.

The runtime reads `dk3/hd-weapon-models.cfg` from a validated cosmetic PK3.
The mapping replaces a source DKM path with a namespaced IQM and leaves its
authoritative `.anim` sidecar in place. An IQM must therefore provide the same
number of frame slots as the converted source. First-person models also retain
the source `hr_muzzle` or `fire` attachment joint when present. The replacement
does not change weapon events, save data, or gameplay compatibility.

## Asset workflow

1. Inventory the class-owned view/world paths and frame counts:

   ```sh
   python3 -B dkq3/tools/hd_weapons.py inventory \
     --base-models zig-out/assets/current/packages/dk3-models.pk3
   ```

2. Capture a complete source representation or selected moving part. This
   writes textured front/side views, the source motion arrays, and metadata
   under a new local `zig-out/hd-weapons/<class>/` directory. Review the source
   silhouette and make a transparent, high-detail concept for each rigid part.
   `capture --class-name glock --surface 1glock_1` created the pilot gun views;
   `--representation world` captured its pickup model.

3. Generate candidate geometry with the pinned local TRELLIS.2 tool and retain
   the concept, GLB, weight hashes, and `trellis.json`. The pilot's isolated gun
   concept produced a 96,626-triangle GLB. A generated whole-gun mesh is a
   **shape candidate**, not an animation rig: define slide, frame, trigger,
   magazine, attachments and their pivots as separate authored parts before a
   first-person export.

4. The Blender converter can decimate and UV-preserve a static world candidate,
   fit its principal axes to a captured reference, and split its IQM surfaces
   below the bundled renderer limits. Inspect its image and choose explicit
   `--signs` when automatic PCA flips an asymmetric weapon. The Glock pilot uses
   `--signs 1,-1,1`; its current review image and IQM live in
   `zig-out/hd-weapons/pilot/glock/candidate-v7/`.

5. After building an articulated view model, record each accepted source/target
   pair and its local review image in an admission JSON. The package tool admits
   only `review: accepted` to the default package. `--preview` also permits
   `review: unverified` for a separately selected guarded engine review. Both
   modes verify source hashes, frame counts, muzzle joints, material textures,
   IQM surface limits, and a ZIP32 package. Source art and review captures stay
   local; the game package contains only runtime assets and provenance hashes.

The current pilot preview can be rebuilt with:

```sh
python3 -B dkq3/tools/hd_weapons.py package \
  --art zig-out/hd-weapons/pilot/glock/candidate-v7 \
  --admission zig-out/hd-weapons/pilot/glock/candidate-v7/admission.json \
  --base-models zig-out/assets/current/packages/dk3-models.pk3 \
  --out zig-out/hd-weapons/pilot/glock/preview-v1.pk3 --preview
zig build play-install --prefix zig-out/hd-weapons/pilot/install \
  -Dhd-weapons-preview=zig-out/hd-weapons/pilot/glock/preview-v1.pk3
```

An accepted package at `zig-out/hd-weapons/dk3-hd-weapons.pk3` is selected
automatically by `play-install`; `-Dhd-weapons=...` selects a different accepted
package. The preview option is explicit and separate. Installation still writes
immutable generations under the chosen independent prefix and preserves saves.

## Acceptance status

| Item | Implemented | Verified |
| --- | --- | --- |
| 28-class source and animation inventory | Yes | Local converted package read |
| Dedicated model mapping and validated package install | Yes | Automated package checks; native playback open |
| Glock isolated concept and TRELLIS mesh | Yes | Fixed-angle preview inspected; moving-part decomposition open |
| Glock world IQM candidate | Yes | Static 16,000-triangle export; native view open |
| Glock first-person view and other weapons | No | Unrun |

The generated meshes and supplied Gold references remain local. TRELLIS.2 and
dependency terms are recorded by the existing deployment in
[neural monsters](neural-monsters.md); no generator runtime enters the game.
