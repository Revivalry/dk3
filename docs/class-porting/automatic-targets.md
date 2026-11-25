# Automatic weapon targets — review and repair

Sequence587 reviews the acquisition rules for `weapon_wyndrax` (19) and
`weapon_zeus` (14). Reference provenance: Gold `WYNDRAX.CPP`
`wyndraxWispPrethink`, `zeus.cpp` acquisition/branching, and
`weapon_funcs.cpp` `validateTarget`. Reference material remains private;
no implementation or assets are imported.

Both weapons admit living monsters, reject their owner and ordinary objects,
and admit clients/bots only in deathmatch. A story companion also has an Actor
component natively; that generic component must not override its party role.
This correction changes automatic seeking/branching, not direct-hit damage or
the requested retaliation policy.

The shared `weapon_targets` mechanism resolves persistent world/entity pairs,
checks life/ownership, then applies the class-supplied `Spec.automatic_targets`
policy. The ordinary defaults live once in `AutomaticTargets`. Party identity
comes through the checked session registry hook; weapons do not read companion
state. Existing retained wisp enemies, zap lists and lightning bolts are also
revalidated, including those loaded from saves.

| Class | Retained behavior | Repair |
|---|---|---|
| Wyndrax's wisp | Existing oscillator, acquisition rolls, ranges, half-damage zaps, fading, audio and projectile presentation | Exclude story allies when acquiring, retaining and zapping targets |
| Eye of Zeus | Existing release timing, branching, damage attenuation, sounds and lightning presentation | Apply the same role policy to acquisition, branch selection and retained bolts |

No animation clips, frame inventories, timing, skill tuning or persistent
component layouts change. Existing class animation/presentation inventories
remain applicable. No new compatibility adapter is introduced.

Evidence: Crypt diagnostic380 preserves a real wisp attack receipt against
Superfly: source455 (Hiro), weapon19, repeated two-point contacts, anger100.
This establishes the unwanted seeking and retaliation trigger. Policy tests
cover story/deathmatch roles and a real Actor+party entity taking precedence
over its generic actor role. Integrated315 is cancelled after a fixture error;
corrected316 and Debug194 pass. Integrated317 and Debug195 also pass, retaining
the existing fade presentation of a Zeus bolt after its target dies. Frozen317
qagame SHA256 is `f1dcf19e3d6a536195f757c0248ba436e0dcfebce3fe9b2b7117fa5cbf8b7712`.
Live Crypt continuation388 now passes both pillars, Nharre, the Throne and
Episode4 arrival with zero deaths. This accepts that affected saved progression;
the frozen380 damage receipt remains the baseline failure. Fresh Episode3 and
current Medusa/Zeus continuation acceptance remain pending.
