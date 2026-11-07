# Sunflare bot hazard admission (sequence 581)

Semantic reference: official GameSpot guide, Sunflare weapon section
(cached guide text lines1904–1924). Burning oil persists and hurts its
owner; the guide recommends throwing from a distance and avoiding the flames.
No private runtime is imported. Existing native animation inventory remains
`ready`, `away`, `shoota`, `amba`, `ambb`; damage, flight, flames, ammunition,
models and sound are unchanged.

Fresh432 dies to its own fire in Catacombs A after exhausting safer ammunition.
The class already supplies damage forecasts but omitted the separate persistent
hazard admission declaration. It now declares `lingering` and its active-flight
predicate through the existing registry hook. The pilot excludes it from
automatic fallback and can still execute deliberately named attacks. Cooling
pots no longer hold movement. Implementation exists; affected replay is pending.
