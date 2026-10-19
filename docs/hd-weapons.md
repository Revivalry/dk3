# HD weapon reconstruction

Sequence **hd-weapons-part-pipeline-374** implements the local weapon inventory,
source capture, generated-mesh candidate conversion, rigid-part assembly, and
isolated package path. The inventory covers all 28 registered weapon classes.
Glock world and three-part first-person candidates are **implemented;
unverified**. No HD weapon is selected by the normal launcher. An accepted
articulated Glock and assets for the other 27 classes remain open.

The runtime reads `dk3/hd-weapon-models.cfg` from a validated cosmetic PK3.
The mapping replaces a source DKM path with a namespaced IQM and leaves its
authoritative `.anim` sidecar in place. An IQM must therefore provide the same
number of frame slots as the converted source. First-person models also retain
the source `hr_muzzle` or `fire` attachment joint when present. The replacement
does not change weapon events, save data, or gameplay compatibility.

## Asset workflow

1. Inventory the class-owned view/world paths and frame counts, then measure
   the original draw surfaces and their rigid-motion residuals:

   ```sh
   python3 -B dkq3/tools/hd_weapons.py inventory \
     --base-models zig-out/assets/current/packages/dk3-models.pk3
   python3 -B dkq3/tools/hd_weapons.py parts-inventory \
     --base-models zig-out/assets/current/packages/dk3-models.pk3 \
     --out zig-out/hd-weapons/source-parts-v2.json
   ```

   The measured roster has 53 unique source representations and 80 visible
   surfaces. Across their full source timelines, 61 surfaces exceed 0.5 source
   units of rigid-fit RMS. A source surface therefore often needs smaller
   authored moving parts or a deforming hand rig; surface names alone are not
   reliable part boundaries.

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

4. The Blender converter can decimate and UV-preserve a static part candidate,
   fit its principal axes to a captured reference, and split its IQM surfaces
   below the bundled renderer limits. Inspect its image and choose explicit
   `--signs` when automatic PCA flips an asymmetric weapon. The Glock pilot uses
   `--signs 1,-1,1`; its current review image and IQM live in
   `zig-out/hd-weapons/pilot/glock/candidate-world-v10/` for the world pickup and
   `zig-out/hd-weapons/pilot/glock/candidate-view-v3/` for the assembled gun,
   glove, and forearm view.

5. Author each rigid moving part separately and fit it to the same captured
   reference pose. `hd_weapon_assemble.py` reads an assembly manifest with each
   static part IQM, its source point capture, selected source vertex indices,
   and maximum permitted rigid-fit RMS. It skins each part to its own joint
   over the authoritative source frame timeline, rejects a nonrigid vertex
   selection above its limit, and carries source `hr_muzzle`/`fire` hardpoints
   as animated joints. Explicit `authored_motion` keys add translation or pivot
   rotation inside a named Gold clip; they start and end at the source pose
   and declare maximum motion. A reviewed source-pose plane splits the generated
   arm at the glove cuff; the assembler can anchor the forearm to the hand at that
   shared point. The current Glock view has gun, glove, and forearm joints.
   Their maximum unanchored rigid-fit residuals are 0.504, 0.165, and 0.186
   source units. The cuff anchor shifts the forearm by up to 0.712 units and
   raises its maximum source residual to 0.728. The slide, magazine, trigger,
   and hand articulation still need separate art and motion review. Its
   assembly manifest is local at
   `zig-out/hd-weapons/pilot/glock/candidate-view-v3/assembly-manifest.json`.
   A local slide experiment at `candidate-view-v4/` exports on the `shoota`
   interval but exposes a diagonal grip seam in frame 133, so it is excluded
   from the preview package.

6. After building an articulated view model, record each accepted source/target
   pair and its local review image in an admission JSON. The package tool admits
   only `review: accepted` to the default package. `--preview` also permits
   `review: unverified` for a separately selected guarded engine review. Both
   modes verify source hashes, frame counts, muzzle joints, material textures,
   IQM surface limits, and a ZIP32 package. Source art and review captures stay
   local; the game package contains only runtime assets and provenance hashes.

The combined Glock preview can be rebuilt with:

```sh
python3 -B dkq3/tools/hd_weapons.py package \
  --art zig-out/hd-weapons/pilot/glock/candidate-pair-v2 \
  --admission zig-out/hd-weapons/pilot/glock/candidate-pair-v2/admission.json \
  --base-models zig-out/assets/current/packages/dk3-models.pk3 \
  --out zig-out/hd-weapons/pilot/glock/pair-preview-v2.pk3 --preview
zig build play-install --prefix zig-out/hd-weapons/pilot/pair-install \
  -Dhd-weapons-preview=zig-out/hd-weapons/pilot/glock/pair-preview-v2.pk3
```

The combined preview installs only with `-Dhd-weapons-preview=...` to an
independent prefix. Guarded OpenGL2 [idle](../zig-out/reports/hd-weapons-374/glock-pair-v2-view/opengl2-glock-view.jpg),
[firing](../zig-out/reports/hd-weapons-374/glock-pair-v2-fire/opengl2-glock-view-fire.jpg),
and [pickup](../zig-out/reports/hd-weapons-374/glock-pair-v2-world/opengl2-glock-pickup.jpg)
captures show both replacements. The log confirms both IQMs registered and
firing consumed one round. Local [ready](../zig-out/hd-weapons/pilot/glock/candidate-view-v3/reviews/glock/frame-095.png),
[reload](../zig-out/hd-weapons/pilot/glock/candidate-view-v3/reviews/glock/frame-113.png),
and [shooting](../zig-out/hd-weapons/pilot/glock/candidate-view-v3/reviews/glock/frame-135.png)
renders sample its actual IQM frames. Full clip, seam, and attachment quality
is still unverified.

An accepted package at `zig-out/hd-weapons/dk3-hd-weapons.pk3` is selected
automatically by `play-install`; `-Dhd-weapons=...` selects a different accepted
package. The preview option is explicit and separate. Installation still writes
immutable generations under the chosen independent prefix and preserves saves.

## Acceptance status

| Item | Implemented | Verified |
| --- | --- | --- |
| 28-class source and animation inventory | Yes | Local converted package read |
| Dedicated model mapping and validated package install | Yes | Automated package checks; isolated native registration verified |
| Rigid-part assembly and source-timeline export | Yes | Synthetic two-part motion and cuff-anchor test; three-part Glock loaded natively |
| Glock isolated concept and TRELLIS mesh | Yes | Fixed-angle preview inspected; moving-part decomposition open |
| Glock world IQM candidate | Yes | Static 16,000-triangle export; guarded OpenGL2 pickup capture |
| Glock first-person gun, glove, forearm candidate | Yes | Guarded OpenGL2 idle and firing captures; slide and magazine still fused |
| Accepted first-person Glock and other weapons | No | Unrun |

The generated meshes and supplied Gold references remain local. TRELLIS.2 and
dependency terms are recorded by the existing deployment in
[neural monsters](neural-monsters.md); no generator runtime enters the game.
