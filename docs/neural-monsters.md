# Local neural monsters and characters

Six realistic separate-head replacements are reviewed and admitted in sequence
330: Toshiro, Hiro, Superfly, Usagi, Garroth and Charon. Separate 4096-pixel atlases,
closed geometry and mesh-conditioned painting replace the failed whole-body
portrait-fitting results. Hiro's head is enlarged by 15%. The reviewed package is
installed through the normal guarded native development launcher; affected head
filtering samples pass. All 102 cinematic models receive paired sample inspection
and 2,081 clips receive numeric triage. Sequence 332 repairs bounded cinematic
resource publication, performer boat riding, ninja standing scale/torso motion and
the female guard's two short blades. The opening's 115 shots, destination arrival
and Superfly's 13 shots now complete in guarded software GL2 diagnostics. Charon
still needs visual timing/framing repair; Osaka, Casseti and Mikiko still need
visual repair. Complete visual playback of every story scene remains open. See
[current native acceptance](native-acceptance.md) for exact evidence and limits.

Sequence 333 repairs connected arm/elbow fitting and bounds wrist bend separately
from forearm roll. A fresh capture of the owner's rear gate walk shows Hiro's
repaired left wrist. Human gameplay retains moving arms for each weapon grip;
running has opposed arm swing and a flight phase. Native players distinguish
walking from running by relative speed, and extra multiplayer appearances use
their own serialized clip ranges. The five human NPCs and three humanoid creatures play
their own original clips (sequences 418 and 420). All geometry, heads and atlases stay
exact; the human NPCs are re-rigged with medial joints and bone-heat weights.
The full opening, five UDP walk/run appearances, three held-weapon grips,
Superfly movement and controlled human NPC rendering/restoration pass. Paired
sample inspection covers all 102 cinematic variants and five human NPCs; complete
visual playback and the remaining character repairs are still open.

The episode pipeline reads the monster roster from this checkout's converted
`dk3/tables/aidata.cfg`, photographs each original animated model, admits a reviewed
detailed image, runs local TRELLIS.2, converts its textured GLB to skeletal IQM,
authors anatomical biped motion or fits other creature performances, then packages
the cosmetic replacements. The current roster has 37 masters: 22 episode-one
monsters, Hiro, Mikiko, Superfly, Mishima and Usagi, and ten additional story
identities. Protopod is an egg launcher; its mechanical
Slaughterskeet is a separate actor. Mishima Guard is a living helmeted soldier.
The concept pass must preserve those identities, silhouettes and equipment.

Everything generated stays in `zig-out/neural-monsters/episode1/`. The existing
original converted model package remains an immutable input. Character masters
are rebuilt here, including the existing gameplay/cinematic variants, carried
Mikiko/Superfly body, weapons, hardpoints, team skins and multiplayer appearances.
Source captures, prompts, rejected concept revisions, GLBs, 4096-pixel atlases,
IQMs, stage logs and SHA-256 receipts are retained locally.

## Local TRELLIS.2 deployment

The qualified host is an RTX 5090 **Laptop** GPU with 24 GB VRAM. Generation uses
an isolated Python 3.12 environment, PyTorch 2.8 CUDA 12.8 wheels, CUDA 12.9 for
extension compilation, GCC 14 and native `sm_120` extension kernels. Blender
capture/conversion/preview uses CPU rendering. None of these generation libraries
is a deployed game dependency.

`neural_trellis_sources.json` records admitted source archive hashes; no Git command
is used. TRELLIS.2 is pinned to `75fbf0183001ed9876c8dbb35de6b68552ee08bd`.
Archives fetched from branch URLs are admitted only if their bytes still match:
keep the local `zig-out/neural-tools/downloads/` snapshots for reproduction.
System prerequisites are Python 3.12, `uv`, GCC/G++ 14, CUDA 12.9 and Eigen headers.

```sh
python3 -B dkq3/tools/neural_trellis_setup.py bootstrap
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_trellis_setup.py build
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_trellis_setup.py weights
```

The three weight repositories have fixed revisions in the setup tool. The original
DINOv3 repository required gated access on this host. The public publisher's
[timm DINOv3 ViT-L/16 LVD1689M conversion](https://huggingface.co/timm/vit_large_patch16_dinov3.lvd1689m)
provides the same encoder weights. The adapter strictly loads them, uses the
original normalization and nonaffine output layer normalization, and reproduces
the bfloat16 RoPE period quantization. Transparent input bypasses background
removal rather than substituting another image encoder.

The xformers automatic dispatcher selected a Hopper FlashAttention 3 kernel that
failed on this Blackwell GPU. Dense attention uses PyTorch SDPA; sparse attention
explicitly selects xformers CUTLASS. Inference uses `1024_cascade`, low-VRAM model
offloading, deterministic per-class seeds, the original 12-step samplers and
32,768 token target for cascade sizing. The upstream 1024 path retains that
resolution even if it needs more tokens. There is no automatic 512 fallback.

CuMesh allocations require releasing inactive PyTorch decoder blocks before hole
filling. Its original vectorized remesh topology could also exhaust this host's
VRAM with a 16-million-face decoded mesh. `neural_trellis_memory.py` builds the same
topology in bounded batches; its CUDA comparison retained identical vertices and
triangles. Decoded meshes are checkpointed before export. Export remains at the
inferred voxel resolution, closes/remeshes geometry, reduces to 100,000 triangles
and bakes a 4096-pixel PBR atlas. The game converter then uses 36,000 triangles.

Upstream license files stay with the admitted source archives. `deployment.json`
records archive and license hashes, and `environment.txt` records installed
packages. `python-packages.json` records dependency metadata and license/notice
hashes. The encoder's [DINOv3 license](https://github.com/facebookresearch/dinov3/blob/main/LICENSE.md)
is retained separately; it is not the TRELLIS MIT license. TRELLIS.2 is
[Microsoft's upstream implementation](https://github.com/microsoft/TRELLIS.2).
Generated assets and supplied game assets remain local; this workflow establishes
no publication rights for them.

## Capture, concept and conversion

Run from the checkout root. `--assets` accepts another converted asset generation;
the default is `zig-out/assets/current`. `--out`, `--episode` and `--models` select
an output directory, episode and subset. The episode package always requires its
entire prepared roster.

```sh
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py prepare \
  --include-characters --include-story
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py capture
```

Each monster has a transparent 1024-pixel `photo.png`, a `side.png`, extracted
visible geometry/textures and authored frame/tag metadata. Reference poses use
the original idle pose, the raised pose for Rockgat, or Toshiro's standing walk
frame instead of his initial coffin pose. The source photograph is
a design reference, not the required final sculpt quality.

Use the built-in image-generation tool once per class with its `prompt.txt` and
`photo.png`. Also supply `side.png` when a costume or body part needs clarification.
For Mishima Guard, the second image is explicitly the original side view. A
separate existing neural character reference may demonstrate sculpt/render quality.
For the five established characters it also supplies their recognizable face;
their original capture remains authoritative for costume and proportions. Story
characters use their original front and side captures. Request
real transparency and retain the output alpha. The revised outputs are 1280 pixels
per edge; the prompt's requested 2048 size is not an achieved size claim.

Review species/body plan, helmet and costume, palette, proportions, pose, margin
and actual modeled depth. Rounded flesh, filleted machinery and modeled seams must
replace the coarse source facets. Texture sharpening or added scratches alone
are insufficient. Suitable bipeds require an upright symmetric A-pose with separated
relaxed hands and feet. Charon, Osaka and the priest keep their original closed
robes; their covered legs do not require a visible gap. Character body masters
have empty hands: cinematic props are attached separately during construction.
The prisoners are protected: keep their original chained poses, concepts and
converted performances. Concept re-admission is rejected for them.

Admit the selected built-in output from its saved path:

```sh
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py concept \
  --model mishimaguard --image /absolute/path/to/generated.png
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py trellis
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py convert
```

Image generation is an explicit reviewed intake. The script does not invent an
unconfigured image service or require an API key. `prompts --models NAME` updates
the saved specification after an identity correction and invalidates its concept
and downstream receipts. Re-admission backs up the prior concept by digest.

Stages retain passing products when input/tool hashes match. A changed input,
corrupt product or missing prerequisite causes a rebuild or a recorded failure.
Failures preserve their log when retried. Actor receipts are locked and updated
independently so CPU conversion can run while another actor uses the GPU. Run
only one TRELLIS producer on this GPU. A saved decoded mesh can resume export
without repeating inference if its concept, weights, resolution and seed match.

Blender imports the atlas, scales geometry, welds coincident glTF UV-seam
vertices before reduction, orients connected faces, and splits UV/surface data below the renderer's 1,000-vertex/2,000-triangle
surface limits. The isolated Python fitter avoids the observed Blender/OpenBLAS
DGESDD crash. Biped alignment measures the neutral arm axis, centers the actual
torso and preserves frontal polarity for visual review. Matching an A-pose against
an asymmetric gameplay pose can turn a soldier backwards. Source offsets are
restored for monsters; character masters use the normalized 56-unit body contract.

Suitable bipeds use the shared Hiro/Mikiko anatomical skeleton, localized welded
joint weights, fixed-length IK, foot planting and independent motion clips. The
monster conversion retains original sequence intervals and event frame numbers;
character construction preserves source gameplay timing, stance-specific moving
attacks, cinematic frame ordering, original props and named hardpoints. Robes and
long panels have pelvis-owned cloth bones so they do not stretch between legs.
New UV masks protect the new head and neck surfaces from team-color tinting.

## Face refinement after reconstruction

TRELLIS can lose eyes and facial albedo even when the concept is detailed. The
run therefore reviews 19 exposed-face identities on their actual new meshes.
Psyclaw's two eye stalks receive a separate registered eye-texture repair using
the same bounded projection stage, with a wider camera centered on its head.
Closed helmets and mechanical heads need no facial repaint; the protected
prisoners retain their existing textures. Generate registered face views after
conversion:

```sh
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py face-preview
```

The first views live in each actor's `face-source/`. Use its `front.png` as the
first built-in image-edit reference and `concept.png` as the identity reference.
Save the exact request as `face-prompt.txt`. Preserve the square canvas, fixed
orthographic camera, head outline and facial landmark positions. Restore detailed
diffuse color without moving features, changing masks, helmets, cheek markings,
glasses, hair or clothes. Charon remains a skull and the ninja remains masked.
Admission requires a square projection of at least 768 pixels:

```sh
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py face \
  --model hiro --image /absolute/path/to/registered-face.png
zig-out/neural-tools/runtime/bin/python -B dkq3/tools/neural_monsters.py face-preview
```

`face-plan.json` records the character, mesh, projection, concept, prompt and
original front-view hashes, anatomical bounds and source-coordinate camera.
Blender bakes the bounded projection into the existing 4096-pixel atlas; the
unrefined atlas remains `body-before-face.png`. Geometry, skeletal weights and UVs
remain the reviewed master. `body.face.json` records the bake and source hashes.
Later previews go to `face-review/`, preserving the original reference. Review
front, quarter and both sides before accepting the face. A changed reference or
mesh requires a new reviewed projection. Head/neck masks are rebuilt from the
new UV layout before multiplayer tinting.
The plan also hashes vertex positions, UVs, normals and triangles. Weight or
animation repairs can retain the same registered reference only when this
geometry digest is unchanged; the bake records the resulting full IQM hash.

The conversion repair `convert --repair-uv-seams` can explicitly re-register an
existing face edit after welding and reducing the **same** TRELLIS GLB. It checks
the previous completed IQM/atlas/metadata, unchanged image-tool inputs and exact
original registered geometry. Both normalized face point clouds must remain
within 1.5 units maximum and 0.6 units at the 95th percentile. Other changes require
a new projection. The repair preserves a checkpoint and previous plan, renders
the new unrefined mesh into `face-seam-source/`, and records the bounded comparison
and both registrations in `face-seam-registration.json`. Review the resulting
atlas on the new mesh from all four angles. This reuses the existing image-tool
edit; it does not claim that edit was generated from the repaired mesh.

When this bounded comparison rejects the old projection, render the new mesh,
generate a fresh registered image edit and use `neural_seam_face.py --actor DIR
--image IMAGE --prompt PROMPT`. It requires the recorded rejection and a matching
new face-render receipt before admitting the edit. The current run regenerated
Psyclaw's eyes and Garroth's face this way.

## Animation review and packaging

Sequence 330 adds a paired original/replacement cinematic viewer and a bounded
rebuild tool. The fitter preserves semantic source surfaces, measures anatomical
landmarks, constrains connected limb lengths and keeps original props' rotations
and authored visibility. Source-pinned exceptions require matching geometry hashes.
Rebuilding checks existing master/material identities and preserves gameplay IQMs
and admitted textures; it stops publication if the implementation changes during
the run. Every rebuilt cinematic receives four matching skin files.

The optional `neural_cinematic_rebuild.py --human-motion` pass also regenerates
gameplay and extra multiplayer motion on the exact admitted bind rigs. The default
cinematic-only pass retains gameplay IQMs.

### Humanoid enemy motion (sequence 421)

The eight humanoid enemies (Mishima guard, cryotech, surgeon, both workers, inmater, ragemaster,
sludge minion) use motion authored from scratch on their admitted anatomical rigs. Nothing is
fitted to the original vertex animation: the owner rejected both attempts to recreate these
clips from the source (sequences 418–420) and found the earlier authored motion much better.

Three stages produce a model's clips, all on the admitted bind rig, weights and mesh:

1. `neural_monster_skeleton.fit_humanoid` gives every source sequence an independent
   performance from the procedural author (`neural_rig.pose`), chosen by the sequence's
   category (idle, walk, run, crouch, jump, death; attacks and pain as `attack`), with the
   class's stance grip and the source's frame count and event frames.
2. `neural_human_motion.human_clips` (the 5 October tool, restored byte for byte, SHA-256
   `8869bbee…`) appends shared idle, walk, run, crouch and back-step cycles at 30 Hz for the
   five human NPCs and maps their locomotion and ambient sequences onto them in
   `neural-animations.cfg`.
3. `neural_actions` authors the actions the procedural kinds cannot express, as a few key
   poses of semantic controls per sequence. Frames ease between keys; the shared fixed-length
   IK (`neural_assets.connected_motion`) solves the limbs, as for the procedural clips.

| Model | Authored sequences |
|---|---|
| Mishima guard | `ataka` one-handed aim, `atakb` kneeling aim, `atakc` turned aim (each kicks on the shot and settles aimed, for the hold between shots); `hita` doubles over; `reload` brings the pistol to the chest and returns to aim |
| Cryotech | `bambb` spray: sprayer carried level at the hip, swept right to left across clip frames 8–22; `bambc`, `bamba` short and ambient sweeps; `hita` twisting flinch |
| Skinny worker | `gamba` kneeling cower and `gambc` standing cower (hands over the head); `eambd` clipboard; `famba` hands in pockets; `bamba` console work; `camba` floor work on all fours; `samba` seated typing |
| Surgeon | `gamba`, `gambc` cowers; `eambd` clipboard |
| Fat worker | `scared` bent-over cower; `samba`, `tamba`, `camba` on a stool (head scratch, typing, a talk with raised arms); `howmany` standing gestures |
| Inmater | `ataka` cannon shot with recoil; `atakb` stab; `atakc` six-shot sweep (shots on clip frames 10, 14, 18, 22, 26, 36); `hita` |
| Ragemaster | `atake` right then left punch (clip frames 14 and 22); `hita` arms raised |
| Sludge minion | `ataka` left then right glob recoil; `atakb` both; `hita` arms flung up |

Every other sequence keeps stages 1–2. Authored sequences leave the shared-clip mapping and
play their own frames at the authoritative rate.

**Controls.** The authoring space is the normalized 56-unit body (+X forward, Z up, floor at
−24, pelvis over the origin), recovered from the packaged model: scale from the mesh height,
offset from the pelvis. A key sets the pelvis offset and rotation; a torso bend, split 35/65
between spine and chest; the head; hand targets in the upright body, carried by the bent chest
(or fixed in the world, for hands on the floor); elbow pole hints; planted foot offsets and a
toe pitch for kneeling; finger curl; and `aim`, the direction of an item rigidly bound to a
hand joint (the cryotech's sprayer belongs to `fingers_r`). Clavicles ride the chest. The
pelvis drops automatically when a leg cannot reach its foot. Loops ease from their last key
back to the first.

**Older creature hands.** The inmater, ragemaster and sludge minion masters predate the
shared wrist solver of sequence 333, which no longer reproduces their packaged hand roll. Their
actions keep each frame's packaged hand, finger and weapon-tag channels, so weapons built into
a hand point as in that model's other clips. The inmater's packaged wrists are outside the
hand range already; only those joints are exempt from the admission check.

**Admission.** `author` fails if a solved frame leaves an anatomical joint range
(`joint_violations`, swing and twist for every joint). The package keeps mesh, bind,
weights and atlases. Frames outside the authored sequences are unchanged apart from IQM
requantization (at most 1.2×10⁻⁵ units).

**Build.** `neural_monsters.py package` runs all three stages. The installed package was
produced from the sequence 417 package (`dk3-neural-episode.before-gold-motion.pk3`, which the
restored `human_clips` reproduces byte for byte from the masters):

```sh
/usr/bin/python3 -B dkq3/tools/neural_actions.py \
  --package zig-out/neural-monsters/episode1/dk3-neural-episode.before-gold-motion.pk3 \
  --output zig-out/neural-monsters/episode1/dk3-neural-episode.actions.pk3
```

The report's `enemy_actions` records the tool and base package hashes and each model's
authored sequences. Review sheets pair Gold's frame (for meaning only) with the new frame:
`zig-out/reports/runtime-zig-421/review/<model>.png`. The rejected source-fitting tools are
kept outside the tree in `zig-out/reports/runtime-zig-420/rejected-tools/`.

## Native physics and isolated gameplay verification

`dk3/neural-physics.cfg` opts generated creature skeletons into the native client
solver. Anatomical bipeds use the existing humanoid solver; Laser/Rockgat turrets
and Protopod use anchored roots; other creatures use free articulated bodies.
At ordinary death, the solver starts from the last visible pose and velocity. It
runs at 120 Hz with parent-length constraints, approximate bend limits, self
separation, swept world/brush contacts, friction and sleep. Attachment bones
follow their parent and are not extra particles. Live matrices use the existing
renderer path; `cg_ragdolls 0` restores the authored death presentation. Server
health remains authoritative.

Sequence 419 changes three things for humanoids:
- **Collapse.** At death the knees give way forward and the hips drop, so a body
  crumples instead of toppling stiff-legged like a plank.
- **Flexible spine.** The trunk is now two rigid girdles, hips and shoulders. The
  spine between them bends within 60° forward, 25° back and 30° to either side,
  twists at most 35°, and has passive stiffness from soft links. Hip cones are
  measured in the pelvis frame; shoulder and neck cones in the chest frame.
- **Head and spine rendering.** The rendered spine bone takes half the bend
  between the girdles, and the neck turns toward the head point, so the neck
  cone's nod and loll show on the mesh.

Burst thresholds are the `gib_damage` and `gib_overkill` cvars: a killing hit of
that fraction of base health, or health below minus that fraction. The reference
values are 0.3 and 0.5, which burst nearly every rifle and blaster kill. The
remaster defaults to 1 and 1, so bodies remain for the physical deaths and
explosions still burst them. Authored always-gib classes (the fat worker) and
spawnflags are unchanged.

The generic creature solver uses motion-region pivots; anatomical bipeds retain
the character hinge/length and mesh stability approach.
Collision boxes and self separation approximate a skinned mesh. Exact cloth,
triangle collision, body-to-body interaction and saved physical poses are outside
this cosmetic conversion. Keep implemented/unverified results separate from
actual scenario evidence.

Install into a separate development prefix:

```sh
zig build play-install --prefix zig-out/neural-monsters-dev -j8 \
  -Dtarget=x86_64-linux-gnu -Doptimize=ReleaseSafe \
  -Dneural-assets="$PWD/zig-out/neural-monsters/episode1/dk3-neural-episode.pk3"
```

Run engine diagnostics through that installation's `dkguard --headless`, without
`--gpu`, using isolated profiles and fresh report directories. Check all 22 model
loads, skeletal motion, rebuilt character variants, native deaths/contacts and the pod's separately spawned
mosquito. Preserve screenshots and inputs for failed cases, repair them and replay
the affected scenarios. A focused actor fixture does not establish complete
episode or hardware-renderer acceptance.

## Current run evidence

The pipeline has finished all 37 entries: 35 newly reconstructed masters and two
byte-identical protected prisoners. The published package contains 132 IQM variants:
110 character performances/appearances and all 22 episode-one monsters. All-frame
structural audit covers 37 masters and 11,458 frames; the gallery records 217 sampled
poses, 20 registered face/eye edits and 19 separately lit face reviews. A repeated
conversion command retains all 37 completed entries without regeneration.

Sequence 329 closes and repaints the 19 exposed character/monster faces. Measured
registration covers 41 front/side images with no sampled folds; candidate meshes
and atlases exactly reproduce in production while skeleton/bind/frame channels
remain unchanged. Ten independent side portraits and exact built-in imagegen
prompts are saved under
`zig-out/reports/runtime-zig-328/texture-quality-review/closed/` and indexed by
`continuation-side-artwork.json`. The shared bounded baker also refreshes Psyclaw's
atlas without changing its IQM, retaining source texels outside face coverage.

Local output: `zig-out/neural-monsters/episode1/review.html`, `quality-audit.json`,
`pipeline.json` and `dk3-neural-episode.pk3`. The final package SHA-256 is
`a3cce6c208de4e7977798ba2efd7959076ede55a48eb7990b2ff36466fde3ff1`.
The isolated installation is selected by `zig-out/neural-monsters-dev/play/current`.
At the owner's request, `zig-out/native-dev/play/current` now selects the identical
25-file installation, and the normal `dk3` command launches it through dkguard.
The local default package selector uses this episode package for `zig build play`.
Prior immutable installations and the preserved game/online selectors remain
available; all 120 snapshotted save/settings files remain exact. Previous package
and launcher bytes are retained. Promotion evidence is
`zig-out/reports/runtime-zig-328/texture-user-install.json`; owner hardware testing
is pending. Current protection and package
receipts are `zig-out/reports/runtime-zig-328/texture-prisoner-protection.json`
and `texture-package-diff.json`: both prisoners remain exact, 18 runtime IQMs
remain unchanged, and model/physics mappings match the sequence 328 package.
Executable, module, renderer and base-content hashes also match that preceding
qualified installation. The earlier quadruped/package receipts describe its history.

Eleven affected scenario groups pass on the new installation: all 22 monster
loads; guard articulated death/restoration and default gibs; five UDP character
appearances with gait, moving attacks, complete deaths, respawn and settling;
held sword/rifle/pistol; carry; companion death/restoration; intro motion/face
views through shot 35; and all 13 Superfly encounter shots with active/completed
restoration. Guard and UDP character checks include both software renderers.
All runs use dkguard and isolated profiles. Passing captures use 960×540,
with two GL2 workers or eight GL1 workers; the GL1 guard uses e1m1a.
The single broad aggregate passes 52 steps, 442 Zig tests, 130 Python tests and
C contracts. Earlier pod, Crox, robot and Venomvermin results retain their exact
relevant assets and runtime inputs.

Exact scenario receipts, native captures, installation identity, retained failed
setups and limits are in [native acceptance, sequence 329](native-acceptance.md)
and `zig-out/reports/runtime-zig-328/texture-final-evidence.json`. The current native
image gallery is `zig-out/reports/runtime-zig-328/texture-native-review.html`.
The HD software intro and heavier e1m3b GL1 guard profiles overflow reliable
commands; one drop-cleanup failure also reports `StaleEntity`. These failed inputs
and logs remain recorded. `--face-size WIDTH HEIGHT` selects intro face-capture
dimensions; the monster/network probes also expose `--capture-size WIDTH HEIGHT`
for explicit diagnostic profiles. These options retain the full model and atlas
inputs.

Full campaign, every cinematic performance, hardware rendering, higher-load
software behavior and drop cleanup remain unverified. Body collision remains
approximate; a wall/stair-adjacent Mishima fixture did not settle within 8.4 seconds,
while the isolated equal-spawn fixtures settle all five characters.
