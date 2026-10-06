# Challenge and Activity Contract v0.1

This document records the conceptual boundary between educational content and reusable activity mechanics. It is intentionally not a complete Swift type design. Concrete protocols, payloads, and persistence schemas should be introduced only as implementation requires them.

## System flow

The conceptual flow is:

```text
ChallengeRequest -> ContentProvider -> Challenge ---------------------------\
                                    -> StudyCard / EquivalenceSet /           -> Activity Engine
                                       ComparableSet / SoccerRound / ...    /

Activity Engine -> collected response -> ValidationRule -> AttemptResult
                -> GameOutcome (when applicable, independent of AttemptResult)
```

A content provider may supply a `Challenge` or suitable activity-specific educational content. This does not imply a giant universal `ActivityContent` payload: each contract should carry only what its educational purpose and activity require. The activity engine presents the supplied content and gathers any required response. Validation produces the educational result. A game activity may additionally produce an independent `GameOutcome`; Learn/Study requires neither a response nor validation.

Language content is primarily catalog-driven. Math content is primarily generator-driven. Both providers should produce compatible semantic contracts for shared activity engines.

The central boundaries are:

- Activity engines do not know whether content came from Language or Math.
- Content providers create educational content and pedagogically suitable options; they do not own game mechanics.
- Validation evaluates semantic or structural data, never rendered UI strings.
- Learn is study/reference content, not a fake challenge with a null validator.
- Mixed is an adaptive orchestrator that selects suitable challenges and activity forms, not a separate educational content type.
- Educational correctness and game outcome are separate results.

Not every product must expose every activity. Product-specific activities and activity-specific payloads are allowed.

## Core concepts

### SemanticValue and Representation

A `SemanticValue` identifies the concept or value being taught. A `Representation` is one way to present it. Rendering and validation must preserve that distinction.

For language, the semantic concept `animals_horse` might have representations such as learned-language text, a horse image, spoken audio, or a letter/token sequence.

For Math, the semantic numeric value `1/2` might have representations such as `1/2`, `0.5`, `50%`, `2/4`, or a fraction circle/bar.

Numeric equivalence alone is not always sufficient. `3 × 4` and `2 × 6` both evaluate to 12, but they encode different structures. For “Which expression equals 12?”, `2 × 6` may be correct. For “Which picture shows 3 groups of 4?”, a 2-by-6 array must not be accepted merely because it also contains 12 objects.

Validation must explicitly state the intended relationship, such as:

- exact identity;
- numeric equivalence;
- structural match;
- ordered sequence;
- unordered selection; or
- pair matching.

Textual learning representations must carry enough locale and direction metadata for correct display and ordering. Images and other non-directional representations should not receive unnecessary direction metadata.

### Prompt, Choice, Interaction, and ValidationRule

A `Prompt` contains the educational stimulus or content presented to the child and may reference one or more `Representation` values. For example, a prompt may be `8 + 5` or a horse image. Localized instructions such as “Choose the answer” belong to the Activity/UI layer, not the educational prompt. Keeping UI instructions out of `Prompt` preserves the separation between interface locale and learned-content locale.

A `Choice` is a selectable semantic or structural answer, not merely a rendered label.

`Interaction` describes how a response is collected: for example single choice, numeric entry, ordered construction, unordered selection, or pair selection. `ValidationRule` defines how the submitted semantic/structural response is evaluated. Rendering the same challenge differently must not change its correctness.

Distractors belong to educational/content generation logic rather than arbitrary UI generation. Math distractors may intentionally represent common errors; language distractors should be pedagogically sensible.

### Challenge

A `Challenge` should conceptually contain enough information for:

- a stable challenge ID;
- its prompt;
- interaction requirements;
- a validation rule;
- one primary skill;
- optional secondary skills;
- curriculum stage; and
- difficulty.

One primary skill is preferred so adaptive progress receives a clear signal. This list defines responsibilities, not a finalized universal Swift payload.

Some activities legitimately need specialized content such as `BuildChallenge`, `EquivalenceSet`, `ComparableSet`, or `SoccerRound`. These should compose shared concepts where useful without forcing every activity into one giant payload or enum.

### Skill, CurriculumStage, and Difficulty

Skills use stable identifiers. Adaptive progress should be skill-oriented rather than storing only one broad user level.

`CurriculumStage` answers “which concepts, skills, and constraints are appropriate?” It must not be architecturally fixed to exactly ten stages. `Difficulty` varies within a stage and answers “how hard is this particular instance?”

Math currently uses the conceptual M1–M10 progression documented in `product-architecture.md`, but providers and progress systems must permit that curriculum to change.

### ActivityType and ChallengeRequest

`ActivityType` identifies the activity engine or experience, such as Multiple Choice, Build, Memory, Tower, or Soccer. `Interaction` instead describes the response form collected for a particular `Challenge`, such as single choice, numeric input, ordered tokens, or matching. Activity type and interaction are related but distinct concepts; this document does not define implementation enums for either.

A `ChallengeRequest` gives a content provider the educational constraints needed to supply suitable content, such as activity capability, skills, stage, and difficulty. It must not ask the content provider to run animations, physics, scoring, or other mechanics.

Adding a learned language should primarily be a catalog/content operation when existing capabilities are sufficient. It is not guaranteed to require zero code: a language may need new tokenization, script, speech, morphology, or other linguistic capabilities.

### StudyCard

A `StudyCard` is reference/study material for Learn. It may combine text, audio, images, and other rich representations. It has no required answer or validation result.

### AttemptResult

An `AttemptResult` records the educational response independently of any surrounding game result. Useful conceptual learning telemetry includes:

- challenge ID;
- activity type;
- primary skill;
- curriculum stage;
- difficulty;
- correct or incorrect;
- attempt number; and
- response time where useful.

This is not an analytics-vendor or backend schema. Data requirements will be refined before persistence.

## Activity responsibilities

### Learn / Study

Learn presents `StudyCard` reference experiences and can use rich visual assets. It has no required validation and must not be represented as a challenge with a fake or null validator.

### Multiple Choice, Choose Representation, and Missing Part

These engines consume challenges whose prompts, choices, interactions, and validation rules suit their respective mechanics. They render supplied representations but do not invent correctness or arbitrary distractors.

### Build

Build may share an ordered-token engine across Language and Math where appropriate. Ordering follows the learned content or mathematical structure, not the interface layout direction.

### Cards, Pairs, and Memory

Pairs and Memory can consume equivalence or representation groups. One semantic value may have multiple valid representations. Cards may present the same material as study or as input to an activity, depending on its explicit contract.

### Tower

Tower is primarily an ordering/comparison mechanic. It receives comparable items with known semantic or sort meaning. The engine must not need to parse or understand mathematical expressions to order them.

### Soccer

Soccer receives a round containing several answer balls and sequential prompts/challenges. Every active answer must resolve unambiguously to the intended ball. The educational/content layer selects the correct semantic answer; the game layer owns aiming, kicking, keeper behavior, physics, and visual scoring.

Scoring remains:

```text
correct answer + goal       -> child +1
correct answer + miss/save  -> nobody
wrong answer + goal         -> nobody
wrong answer + miss/save    -> keeper/bot +1
```

A wrong-answer goal does not score against or punish the keeper.

Educational correctness and soccer outcome remain independent. A child can answer 10 of 10 math challenges correctly but score only three goals; adaptive Math must treat that as strong mathematical performance, not 30 percent.

### Mixed

Mixed is an adaptive orchestrator. It chooses challenges and compatible activity forms using skills, curriculum constraints, difficulty, and progress. It does not define a separate educational content payload.

### Bonus games

Bonus games may use shared contracts where appropriate or product-specific contracts where their mechanics require them. Shared code must not erase meaningful domain or activity distinctions.

## Directionality responsibility

Activity engines must not infer learning-content direction from the interface locale. A Hebrew interface may display English learned content in LTR order, while an English, Spanish, or other interface may display Hebrew learned content in RTL order. Mathematical expressions such as `8 + 5 = 13` retain their mathematical ordering in an RTL interface.

Normal interface chrome uses semantic leading/trailing layout. Textual learning representations supply their own locale/direction metadata when necessary. Build and letter/token ordering follows the learned representation. A larger bidirectional-text framework is not specified in v0.1.
