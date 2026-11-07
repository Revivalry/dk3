# Light: flame contact fields (sequence 579)

Reference review: Gold `dlls/world/LIGHT.CPP`, `light_flame_burn` and
`light_flame_setup`, lines 454–541. Episode flame sprites are trigger entities
that deal two points of contact damage. Runtime and reference assets remain
independent; no reference implementation is imported.

The existing class owns flame spawning, sprite publication, contact damage,
enabled state and saves. Existing sprite animation remains unchanged; this
repair adds no clips, models, audio or saved fields. The class now declares its
enabled flames as persistent bot avoidance fields through the hazard registry.
Ordinary lights and disabled flames produce no forecast. A focused unit case
covers that admission and passes in sequence579's consolidated native checks
(`runtime-checks-02.log`).

Observed failure: `medusa-submerged-to-ending-63/` approaches the brazier at
`2512,880,-792`, remains in its touch volume and burns to death. The class-owned
forecast is implemented. `medusa-poison-hook-64/` preserves an unrelated bank
approach failure from a supply-detour checkpoint. `medusa-flame-fields-65/`
replays that C checkpoint through the courtyard, D, Medusa, the awakened waves
and both ending films to Episode 3 with zero deaths and no flame burns. Shared
evasion compares actual exposure, including vertical separation and the current
motion, before choosing a dodge. Full rendered light and complete campaign
acceptance remain open.
