# Scenery decorations

Scope: the existing `deco_e1` through `deco_e4` class and its missing-definition
admission rule. Sequence 431 repairs the retail intro failure; it does not claim
complete prop, debris, or campaign parity.

| Section | Reviewed behavior and implementation |
| --- | --- |
| Identity | Episode decoration classes select the named row from the owner's episode `decoinfo` table; that row supplies the model path. All behavior stays in `classes/entities/scenery/` |
| Spawn | `dlls/world/MISC.CPP`, `SpawnDeco` / `deco_info::ReadInfo`, are private behavioral references only. When a named row is absent, the original emits a diagnostic and returns without configuring that decoration. Native admission now omits the scenery component and logs class, name, and table; it preserves the map-object identity. It does not guess a model, fabricate collision, or abort the whole map |
| Goals and tasks | None; configured props use the existing shared physical-prop mechanism |
| Animation inventory | Table `animseq` and `seq0`–`seq4` select supplied frame ranges; `~` loops. A missing definition admits no model or animation. The synthetic policy regression checks range selection without embedding retail assets |
| Timing | Existing physical-prop and authored sequence timing are unchanged |
| Skill | None for missing-definition admission; table values and map overrides remain unchanged |
| Perception | None |
| Combat | Existing breakage, damage and debris behavior is unchanged; an omitted decoration has no fabricated body or damage state |
| Audio and events | Existing defined-decoration events are unchanged; omission emits one diagnostic per map object |
| Persistence | No schema change. Omitted decorations retain map-object identity but receive no scenery component or resource registration |
| Open questions | Full decoration, debris, sound and animation parity remains unverified. Missing table files, malformed matched rows, invalid bounds and invalid table syntax remain errors |

Local retail inventory: 83 converted maps have one unresolved decoration name,
`dojolamp`, used by `intro` and `credits`. Its model files exist, but the owner's
episode table omits the row; a model alone does not supply decoration behavior.
Original archives, tables and saves are never modified or shipped.
