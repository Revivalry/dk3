# Keys

Sequence587 reviews Gold `dlls/world/artifacts.cpp` (`item_key_touch`) and
`dlls/world/common.cpp` (`com_DoKeyFunctions`) as read-only behavioral references.
The official GameSpot guide supplies the laboratories' card acquisition order.
No reference implementation or assets are imported.

| Section | Native contract |
|---|---|
| Identity | Registry key items, control cards, quest ingredients and assembled keys. Existing inventory bit positions remain stable. |
| Spawn | Pickup flag1 marks a key for one use; flag2 permanently unlocks its control and linked doors. Flags belong to the collected item. |
| Goals and tasks | Possession admits a keyed activation. A successful activation consumes a one-use key and retains an unlocked control. Merely querying a lock has no inventory effect. |
| Animation | Existing pickup presentation; no new clips or decorative inserted-key model. |
| Timing | Consumption occurs when the control fires, before its targets or pickup killtargets run. |
| Skill | None. |
| Perception | None. |
| Combat | None. |
| Audio and events | Existing pickup and control events. No new media. |
| Persistence | Save pickup metadata, current possession and unlocked controls. Preserve assembled bomb ingredient evidence independently of possession. Reset the complete inventory at episode boundaries. |
| Co-op | Remove consumed copies from cooperative players. Companions do not supply key inventories. Linked double-door leaves share the durable unlock. |
| Open questions | Old saves lack pickup metadata and acquisition order. Preserve their inventories and grandfather already-used controls; never infer that an old card inventory proves a new pickup happened. Inserted-key decorative presentation remains unimplemented. |

The class owns pickup flags, lock admission, consumption and save admission in
`src/classes/items/keys/`; shared interaction and item mechanisms dispatch through
registries. Ordinary key ownership means current possession. Historical evidence
is used only for consumed assembled ingredients, so the second green card cannot
be skipped because the first was previously collected.

Focused native checks38 and ReleaseSafe40 pass542/542, including one-use
consumption, co-op copies, reusable keys, linked double-leaf unlocking and
older-save admission. Check39's test fixture omitted required mover fields;
it is corrected in40. Debug41 also passes542 after linked target-name detachment
and the separate landing-area propagation change. `labs-key-consumption-02` replays from
before Labs A's first card, consumes green at634 and blue at476, shoots all five
targets and obtains the second green card, with zero deaths. It fails afterward
on the firing-range return door; it is not complete Labs acceptance. Run01 used
the preceding binary while the build was finishing and is excluded from key-fix
acceptance.

Control-card pickup volumes are independent of their thin rendered models.
Gold `artifacts.cpp`, `item_control_card_red/blue/yellow/green`, specifies a
20-by20 horizontal volume extending16 above the origin. The native class supplies
those bounds through spawn and old-save admission hooks. Other quest items retain
their own bounds. `labs-yellow-card-bounds-01` now collects the yellow card,
returns through the barracks transport and Labs A, spends it at the yellow door
and enters Labs C, with zero deaths. Its later transport dismount failure is
retained and does not invalidate that card result. Debug47 passes545/545 for
the card-bound regression and the initial authored-flight guard change.
