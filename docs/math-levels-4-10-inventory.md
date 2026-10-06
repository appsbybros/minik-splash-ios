# Math Levels 4–10 implementation inventory

## Reference audit result

The supplied Android snapshot does not contain a Minik Math product. Its app
module declares Minik language, English-only, games, Plus, and Plus
English-only flavors; it has no Math flavor. Searches across `android/`,
`appupdatelib/`, `sharedmoduleslib/`, `subscriptionlib/`, and
`userengagementlib/` found no Math curriculum source, numeric content table, or
Level 4–10 activity mapping. Android therefore cannot currently supply the
behavioral/content evidence required to implement these levels faithfully.

The iOS source of truth recognizes all ten stable Math level identities. Levels
1–3 are implemented. Levels 4–10 have approved conceptual descriptors only;
they intentionally expose no activities and create no sessions.

## Exact remaining inventory

| Level | Approved concept boundary | Existing reusable iOS capability | Missing production evidence and implementation |
| --- | --- | --- | --- |
| Level 4 | Place value, numbers to 100, richer addition and subtraction | Exact integer semantics and existing shared activity engines | Approved number bounds and difficulty tiers; tens/ones representations; regrouping policy; operation mix; per-activity content mapping |
| Level 5 | Meaning of multiplication and division | Exact integer semantics; generic choice, build, matching, ordering, and soccer contracts | Approved group/array/sharing representations; fact ranges; remainder policy; multiplication/division progression; per-activity mapping |
| Level 6 | Fluency, factors, multiples, initial fraction relationships | Exact integer and reduced-rational semantics | Approved fluency ranges; factor/multiple task families; fraction representation and denominator policy; relationship rules; per-activity mapping |
| Level 7 | Fractions and decimals as numbers | Exact reduced-rational semantics and typed comparison values | Approved fraction/decimal notation and visual models; conversion rules; magnitude ranges; number-line behavior; per-activity mapping |
| Level 8 | Fraction, decimal, percent, and ratio relationships | Exact reduced-rational semantics | Approved percent and ratio models; equivalence/conversion task families; value ranges; rounding policy, if any; per-activity mapping |
| Level 9 | Pre-algebra | Generic representation and exact-answer contracts | Approved negative-number, order-of-operations, power, ratio, and equation subset; typed expression model; ranges; per-activity mapping |
| Level 10 | Algebraic relationships | Generic representation and validation contracts | Approved variable/equation model; linear/proportional task families; any probability/geometry boundary; ranges; equivalence rules; per-activity mapping |

## Safe implementation boundary

No Level 4–10 production code can be added from the current evidence without
making product decisions. In particular, a conceptual subtitle is not enough
to choose numeric ranges, difficulty progression, representations, generators,
answer semantics, or which activity interactions remain educationally
meaningful.

The current architecture is ready for the missing curriculum evidence:

- stable level identity is independent of array position and user-facing copy;
- one curriculum policy owns availability and activity capability;
- catalog, hub routing, factory requests, and shared sessions accept a level ID;
- planned levels cannot fall back to Level 1–3 content;
- exact rational and integer semantics are already reusable where appropriate;
- adding a level does not require duplicating routes or views.

When authoritative content is available, implementation should proceed in
order from Level 4 through Level 10. Each level needs an approved content matrix
before its descriptor becomes runnable: activity kind, primary skill,
interaction, representations, numeric domain, difficulty tiers, generation
rules, and semantic correctness invariants.
