# M3 Build XCTest root cause — 2026-09-05

## Classification before repair

**B. TEST_DEFECT.** At starting HEAD `180155bedc7d421e3c5ffc391e943a32bffec604`, the failing test calls the older `MathActivitySessionFactory`, which owns `MathContentProvider`. Its Build prompt is always `Representation.mathExpression`. Gate #6 commit `27ccca2ac575628cdde429c0b6f8a655cac48f9e` incorrectly substituted an assertion about the separate production `MathM3ContentProvider` contract. No random draw can make the asserted enum case match.

The supplied Mac evidence is all four apps BUILD SUCCEEDED under Xcode 26.6 / Swift 6.3.3; ProductConfigurationTests compiled and ran 797 tests, with 796 passes and exactly this one failure at `MathActivitySessionFactoryTests.swift:231`. The repository's starting HEAD matches the user's expected HEAD. The brief supplies no numeric challenge dump, so the failed Mac run's individual random numbers cannot be recovered or honestly reported as observed values.

This investigation classified the failure before changing the tests. No production implementation or canonical Math contract is changed by the repair. There is no evidence for A (production defect), C (nondeterministic defect), or D (combination) in this failure.

## Exact failing path and all six challenges

1. `MathActivitySessionFactoryTests.mathFactory` constructs `MathActivitySessionFactory` for `.minikMath`.
2. `MathActivitySessionFactory.makeBuildSession(for: .m3)` obtains the `.build` curriculum request and calls its private `makeBuildChallenges(count:build:)` with count 6 and a closure capturing that request.
3. The M3 request selects `.orderedTokens`, `MathSkillIDs.missingAddend`, stage `M3`, difficulty `0.5`, and no quantity requirement. Math level determines the content; Build determines the ordered interaction.
4. All six iterations call the same `MathContentProvider.buildChallenge(for:)`. `generationBound(for:)` selects the M3 medium bound **15**. `generateBuildEquation(for:bound:)` enters only the `.missingAddend` branch.
5. `randomMissingAddendComponents(bound:)` draws `t = Int.random(in: 0...15)`, then `k = Int.random(in: 0...t)`, and computes `m = t - k`.
6. `GeneratedBuildEquation` contains numeric operands/result and the prompt string `k + □ = t`, with structure ID `math.equation.missingAddend.k.t`.
7. `buildChallenge(for:)` unconditionally constructs `Prompt(representations: [mathExpression(equation.promptExpression, structureID: ...)])`. That helper returns `.mathExpression(MathExpressionRepresentation(...))`, not the `.math` enum case.
8. The expected five tokens are `[k, +, m, =, t]`, each represented by `.mathExpression`. Their physical IDs contain a UUID and token index; their representation structure IDs are `math.number.k`, `math.operator.add`, `math.number.m`, `math.operator.equals`, and `math.number.t`.
9. `BuildChallenge` stores the prompt, available tokens, expected ID sequence, stage/skills/difficulty, `.submitSequence` validation and nil language content. It has no hidden `MathMissingValueRepresentation` field.
10. `BuildSession.init` stores the challenges unchanged. Its token-presentation shuffle cannot change the prompt or expected solution. `submit()` resolves the selected and expected token representations and compares their sequence.

| Challenge index | Draws | `prompt.representations.first` | Expected ordered tokens |
| --- | --- | --- | --- |
| 1 | `0 <= k1 <= t1 <= 15`, `m1=t1-k1` | `.mathExpression("k1 + □ = t1")` | `k1,+,m1,=,t1` |
| 2 | `0 <= k2 <= t2 <= 15`, `m2=t2-k2` | `.mathExpression("k2 + □ = t2")` | `k2,+,m2,=,t2` |
| 3 | `0 <= k3 <= t3 <= 15`, `m3=t3-k3` | `.mathExpression("k3 + □ = t3")` | `k3,+,m3,=,t3` |
| 4 | `0 <= k4 <= t4 <= 15`, `m4=t4-k4` | `.mathExpression("k4 + □ = t4")` | `k4,+,m4,=,t4` |
| 5 | `0 <= k5 <= t5 <= 15`, `m5=t5-k5` | `.mathExpression("k5 + □ = t5")` | `k5,+,m5,=,t5` |
| 6 | `0 <= k6 <= t6 <= 15`, `m6=t6-k6` | `.mathExpression("k6 + □ = t6")` | `k6,+,m6,=,t6` |

Each has exactly one prompt representation, five available tokens, five expected tokens, primary skill `missingAddend`, M3 stage, difficulty 0.5 and `.submitSequence`. Duplicate numerical values do not collapse physical tokens. There are 136 possible `(k,t)` pairs for each challenge, including zero. The six iterations need not choose distinct pairs. These are exact source-derived formulas, not invented observations of the Mac run.

The missing-value task in this older factory is carried by the visible expression and the complete ordered solution. Its representation is a typed Swift wrapper around expression text, but **not** the structured `MathMissingValueRepresentation`. No conversion takes place in `DomainFoundations`, `BuildChallenge` or `BuildSession`.

## Actual production M3 boundary and canonical contract

`MathProductionActivityID.buildMath.launchRoute(for: .m3)` returns `.m3Production`. `MinikActivityHubView.mathDestination` calls `MathM3ActivitySessionFactory.makeSession(for: .buildMath)`, and `MathM3SessionView` presents that `.buildMath` session. The older factory is in the separate `.curriculumEngine` fallback; M3 Build does not select that route.

The production factory's `buildEquationSession()` calls `balancedRelationships(count: 6)` and `relationships.compactMap(provider.buildEquationChallenge)`. `MathM3ContentProvider.buildEquationChallenge` calls `missingRepresentation`, which unconditionally produces `.math(.missingValueExpression(MathMissingValueRepresentation(...)))`. The prompt itself therefore carries the typed operation, missing position and known integer values. Its five-token expected solution completes the entire equation; the six-token tray includes one distractor.

The category order is missing addend, missing subtrahend, operation result, equivalent expressions. Weights 3/2/3/2 are interleaved deterministically, with independent per-category offsets. The current production session is:

| Index | Relationship ID | Typed prompt | Missing field | Expected equation | Primary skill |
| --- | --- | --- | --- | --- | --- |
| 1 | `missing-add.2-5` | `2 + □ = 7` | right operand | `2 + 5 = 7` | missingAddend |
| 2 | `missing-subtract.12-7` | `12 − □ = 5` | right operand | `12 − 7 = 5` | missingAddend |
| 3 | `result.add.7-5` | `7 + 5 = □` | result | `7 + 5 = 12` | addition |
| 4 | `equivalent.6-4` | `6 + 4 = □` | result | `6 + 4 = 10` | equivalentValues |
| 5 | `missing-add.7-5` | `7 + □ = 12` | right operand | `7 + 5 = 12` | missingAddend |
| 6 | `missing-subtract.18-9` | `18 − □ = 9` | right operand | `18 − 9 = 9` | missingAddend |

All six have exactly one typed missing-value prompt, five expected tokens, six available tokens, M3 stage, difficulty 0.65, and `.submitSequence`. These values follow the default production fit gate: every selected prompt fits at the preferred font, so no alternative is selected. The fit gate allows up to 12 same-category candidates and can reject a session under a rejecting gate; every candidate still has the same typed representation family.

The full static pool has 16 relationships, all of which produce typed missing-value Build prompts. It includes all four categories and all three missing positions, including `□ + 6 = 14` and `8 − 8 = □`. UUIDs and shuffled token trays do not select the educational relationship. Random selection in Mixed and shuffled Cards are separate activities and are not reached by `.buildMath`.

The approved authority is `MINIK_MASTER_PLAN.md` §§1.3, 7.7, 8 and matrix cell **M3-07** in `math-production-matrix.md`: M3 teaches addition/subtraction relationships within 20; Build Math requires assembling the full ordered equation from a missing-value expression, with bounded token grammar and distractors. Math Level = WHAT, Activity = HOW. The existing dedicated production factory satisfies that typed prompt boundary. Changing production to accommodate the older-factory test, or replacing production's typed assertions with text-only assertions, would be unjustified. No new product decision is needed.

## Why Gate #6 was wrong or incomplete

The original pre-`27ccca2` test parsed `missingAddendRelationship(from:)`, which expects four structure-ID components beginning `math.missingAddend`. That is the form emitted by older Learn/choice/Soccer content. Older Build emits five components beginning `math.equation.missingAddend`, so the original test was also defective.

Gate #6 removed that wrong parser but replaced it with another wrong boundary. Its analysis said production already carried a typed missing-value prompt and runtime UUID-based token IDs. Those observations fit the dedicated M3 provider, not the factory instantiated by this test. Older Build token *representation* IDs remain `math.number.*`; only physical IDs are UUID-based. `27ccca2` did not change the factory call or production provider.

Thus the earlier STALE_TEST label identified test ownership but failed to trace the concrete producer. The proposed correction was deterministically incapable of reaching its numeric assertions. Claims that all reported failures were corrected/resolved exceeded the available Windows evidence. The latest Mac run disproves that resolution claim; this document corrects it without rewriting historical exports or redefining the product.

All other test changes in `git show 27ccca2 -- Tests/ProductConfigurationTests` were reviewed against their current sources:

| Gate #6 correction group | Actual evidence and disposition |
| --- | --- |
| Activity catalog casing | Catalog/interface title is `Just for Fun`; no Math factory assumption. |
| Progress persistence/reducer fixtures | Repository deduplicates by event UUID; unique fixture event identities are appropriate. |
| Soccer whitespace fixture | Item IDs are namespaced; exact `stableKey == "food_ice_cream"` selects the intended whitespace word. |
| Tower whitespace fixture | Same namespaced-word fixture issue; no Math representation assumption. |
| Word Build fixture | Explicit image-ready fruit category removes a random unsupported-category fixture dependency. |
| Word catalog identity | Nonoptional stable word identity replaces optional Android ID interpolation; historical pre-existing Phase 41 hunk was identified in the prior record. |
| Ping Pong coordinates | Floating-point scene-coordinate round trips require tolerance; no Math factory assumption. |

No other Gate #6 correction uses this erroneous typed-M3-for-generic-factory reasoning. The other 796 passes in the supplied run support that scoped conclusion, but do not prove the absence of every possible flaky test. Neighboring older Learn/Choose/Soccer tests still parse structure IDs that currently match their actual producers; no unrelated refactoring is included.

## Repair and deterministic regression coverage

1. Correct the existing older-factory test to unwrap its actual `.mathExpression` payload. Assert exact `lhs + □ = result` prompt text, five ordered equation pieces, `+`/`=` grammar, numeric bounds and arithmetic equality. Select and submit the full sequence through all six rounds, asserting completion. It no longer parses structure IDs.
2. Add `MathM3ActivitySessionFactoryTests.testBuildMathPreservesTypedMissingValuePromptsAcrossAllSixChallenges`: an independent fixed six-fixture oracle checks the production route, session kind, every typed prompt field, stage/skill, exact ordered equation, distractor/physical-token count, submission and completion. No random seeds or UUID string expectations are needed.
3. Add `MathM3ContentProviderTests.testEveryBuildEquationRetainsItsTypedRelationshipAndOrderedSolution`: cover all 16 canonical relationships and all three missing positions, comparing typed prompt fields and ordered solutions to the requested relationship. This includes forms absent from the first six.
4. Add `Scripts/audit-m3-build-contract.ps1` and invoke it from the existing ProductConfigurationTests Windows audit. Before repairing the test, this guard was run against the original source and rejected it with `WRONG_FACTORY_BOUNDARY`. Five in-memory mutations verify rejection of the original wrong enum case, removal of the exact prompt assertion, provider replacement, loss of the production typed guard, and narrowing full-pool coverage.

The older random test now asserts properties true for every allowed draw. The production regressions have deterministic educational fixtures. The focused Windows script checks source contracts; it is not a Swift interpreter. A separate finite-domain source projection enumerates all 136 older forms and all 16 production relationships, checks the six production fixtures and default-fit bounds, and is labeled as a model, not execution of Swift.

## Validation and preservation

All 22 applicable Windows/static scripts passed, including the new boundary guard, existing ProductConfigurationTests compatibility, localization/catalog, all Language activity/parity/speech/visual checks, English Only policy/parity, asset/provenance, Math asset/visual, manual workflow-definition audit, and the two previous compile-regression guards. The workflow audit only reads definitions; it does not invoke a workflow. Exact outcomes and logs are recorded in the external root-cause export.

Swift/swiftc and Xcode are unavailable in this Windows session. The two new XCTest methods and corrected method require a future authorized Mac run. No claim is made that the repaired XCTest suite has executed or passed here. The supplied 797-test run remains the last real XCTest evidence.

Before edits, the index was empty and the branch/HEAD matched the expected baseline. A preservation manifest captured 805 pre-existing paths (including the already-deleted README marker), all 408 `git status --short` rows, and the root AGENTS.md SHA-256. All task files were initially clean or absent. Only this task's three test files, two audit scripts and two documentation files are eligible for the single local checkpoint. Production Sources, Phase 41 files, workflow definitions and AGENTS.md are excluded.

The external `m3-build-xctest-root-cause.txt` includes the exact checkpoint HEAD, parent, final status, audit results and before/after preservation hashes. The accompanying patch is the complete single-checkpoint diff. No push, fetch, CI, workflow run, destructive Git action or Android modification is part of this task.
