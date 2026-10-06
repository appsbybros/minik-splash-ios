# Vocabulary Curriculum Normalization Audit

## Source Inventory

- Android `words.xml` contains **835** active entries across **90** active arrays and **22** source categories.
- Active source level counts: A **184**, B **189**, C **250**, D **136**, E **76**.
- Unicode roundtrip validation passed for all **835** source rows, including exact English/Hebrew preservation for the generated audit inputs.

## Lexical Summary

- Retained source lexical items: A **181**, B **192**, C **233**, D **118**, E **47**.
- New lexical additions: A **0**, B **0**, C **8**, D **44**, E **132**.
- Final lexical totals: A **181**, B **192**, C **241**, D **162**, E **179**.
- Expert/archive exclusions: **34** source items.
- Duplicate additions removed against retained source: **4**.
- Geography corrections remain: **America merged into United States** and **Africa moved from countries to geography**.

## Semantic Sampling Integrity

- Internal sampling categories were normalized to **46** categories including `sentences`.
- Required semantic moves were applied without changing stable keys, asset keys, or sprite-sheet coordinates.
- `mixed_other` has **0** standard curriculum arrays after redistribution.
- `sports_future` has **0** standard curriculum arrays after redistribution.
- Representative approved moves now include:
  - `transport_toy -> toys_games`
  - `home_boat`, `home_truck`, `home_taxi`, `home_motorcycle`, `tech_rocket`, `other_parachute -> transport`
  - `sports_future_soccer` and the sports-ball lexical items -> `sports`
  - `other_king -> fantasy_adventure`
  - `other_drum -> music`
  - `school_microscope -> science_objects`
  - `school_supplies_project -> school_work`
  - `tech_sign -> symbols`
  - `expressions_friend -> family_people`
  - `expressions_in`, `expressions_on`, `expressions_under -> directions`

## Hebrew Repairs

- `verbs_help`: source Hebrew preserved in the audit, repaired output now uses **`לעזור`**.
- `verbs_clean`: source Hebrew preserved in the audit, repaired output now uses **`לנקות`**.
- `time_century`: source Hebrew preserved in the audit, repaired output now uses **`מאה שנה`**.
- `time_millennium`: source Hebrew preserved in the audit, repaired output now uses **`אלף שנה`**.

## Sentence Summary

- B sentences: existing **6** = final **6**.
- C sentences: existing **9** = final **9**.
- D sentences: existing **5** + new **95** = final **100**.
- E sentences: existing **0** + new **200** = final **200**.
- D new-theme distribution: daily_routine 8, family_friends 8, feelings_opinions 8, food_shopping 8, health_safety 8, personal_info 8, planning 8, school 8, science_environment 7, social_communication 8, technology_media 8, travel 8.
- E new-theme distribution: civics_world 20, comparison_preferences 20, environment 20, health_safety 20, opinions_reasons 20, planning_problem_solving 20, school_projects 20, social_situations 20, technology_media 20, travel 20.

## Collision Invariant

- Same-level lexical surface collisions after trimming and locale-aware case normalization: **0** in English and **0** in Hebrew across levels A-E.
- Sentences remain excluded from Cards lexical deduplication.
- Word Cards foundation behavior remains lexical-only and stable-ID preserving across A-E for both supported learned languages.

## Image State

- Total image-capable curriculum items: **543**.
- Existing/reusable iOS images: **543**.
- Completed Android migrations: **397** (**395 WebP**, **2 PNG**).
- Android migrations still pending: **0**.
- Trusted/non-generative assets needed: **0**.
- Reviewed generated images completed: **93**.
- Actual sprite sheets remain **7** with a maximum of **16** objects on any sheet.

## Integrity Notes

- Historical IDs remain unchanged for all `fruits_*` items, `vegetables_garlic`, and `other_king`.
- Current ready assets total **543**: the original 12 unchanged assets, 397 validated Android migrations recorded in `vocabulary-android-asset-migration.tsv`, 8 validated deterministic masters recorded in `vocabulary-deterministic-master-import.tsv`, 33 licensed/public-domain trusted assets recorded in `vocabulary-trusted-asset-provenance.tsv`, and 93 individually generated/reviewed masters recorded in `vocabulary-generated-asset-provenance.tsv`.
- Every generated master is at least 1024 by 1024, has a real transparent-to-opaque alpha range, a unique generation output ID, unique SHA-256 content, and byte-identical source/output provenance.
- Two semantically incorrect Android-source images, dehumidifier and helix, are replaced by individually reviewed generated masters recorded in `vocabulary-known-fix-provenance.tsv`; their stable keys and ready-asset count are unchanged.
- Canonical/runtime parity is required for:
  - `docs/words-normalized.xml == Resources/Vocabulary/words-normalized.xml`
  - `docs/vocabulary-image-manifest.tsv == Resources/Vocabulary/vocabulary-image-manifest.tsv`
