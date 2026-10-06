# Minik Android UI Reference Screenshots

Reference date: 2026-08-30

**Owner gate, 2026-09-06:** All 16 screenshots are binding Language/shared Minik visual references,
together with actual Android layouts, dimensions, assets and source. Reconstruct the complete
Language product screen by screen, including unannotated discrepancies and meaningful states.
Preserve hierarchy, proportions, artwork, controls, typography, board density, feedback and navigation.
Native safe areas and accessibility may adapt rendering; they do not authorize generic replacement
compositions. Source parity and real post-fix runtime visual verification are separate gates.

Important interpretation rules:

- Android is the behavioral/content reference for the Language product and shared product systems.
- Android does **not** define the Minik Math curriculum. Math reuses/adapts the activity families and shared product shell, while the user defines the Math curriculum and representations.
- The screenshots show important product systems beyond activity engines: Minik mascot/reactions, success feedback, points/streak/record cards, top navigation, Parent Area, RTL/LTR presentation, speech buttons, and child-friendly illustration-heavy UI.
- Compare every screenshot with its Android source/layout/assets and current iOS production route. Record every reference in the crosswalk. Exact rendered spacing/crop needs post-fix iPhone/iPad review.

## Screenshot index

1. `01-language-word-to-picture-pea.png` — learned word shown as text; child chooses the matching picture from four image choices.
2. `02-language-picture-to-word-pig.png` — picture prompt; child chooses the matching learned word from text choices; also shows Minik success feedback.
3. `03-language-first-letter-picture-to-letter.png` — picture prompt; child chooses the starting letter.
4. `04-language-first-letter-letter-to-picture.png` — starting-letter prompt; child chooses a matching pictured word.
5. `05-language-word-cards-corn.png` — sequential word/flash-card learning presentation.
6. `06-language-build-word-hebrew.png` — ordered English-letter construction with a Hebrew host-language word prompt and speech.
7. `07-language-letter-pairs.png` — pair-matching activity using pictured words/initial-letter semantics.
8. `08-soccer-instructions.png` — Soccer instructions/tutorial overlay and visual identity.
9. `09-soccer-gameplay.png` — Soccer field, score, answer balls, Minik goalkeeper, and result feedback.
10. `10-language-picture-memory.png` — picture-memory board and matched-card presentation.
11. `11-language-alphabet-blocks.png` — Alphabet Blocks/Tower word-construction presentation.
12. `12-tic-tac-toe.png` — Tic-Tac-Toe board, X/O selection, Minik mascot, and just-for-fun game presentation.
13. `13-language-learn-letter-b-banana.png` — Learn activity: large letter forms, example picture/word, next navigation.
14. `14-main-menu-language-activities.png` — upper portion of production activity menu, home/trophy/Minik navigation and sectioned cards.
15. `15-main-menu-games.png` — lower menu area including Games and additional activity cards.
16. `16-parent-area.png` — compact Parent Area modal over Intro; Intro points/record header remains visible behind it; learned language, app language, encouragement, progress and levels actions.

## Math interpretation examples established by the user

These screenshots define activity families; Minik Math should adapt those families instead of copying language content literally.

- Word -> picture family can become a number/expression prompt with four visual/math representations.
- Picture -> word family can become a visual quantity/expression prompt with four numeric/text answers.
- The two first-letter activities become two simple Math construction activities: Build Number and Build Quantity.
- Tower becomes a quantity/expression target with a child-built block count; available blocks may exceed the correct answer and completion may be delayed to detect over-building.
- Soccer keeps the Android score/outcome mechanic while questions and answer values change by Math level.
- Memory/Pairs match semantically equivalent Math representations.
- Cards becomes a learning/facts-table presentation such as addition or multiplication facts depending on level.
- Learn remains instructional rather than a practice game.

For the full product contract, architecture, current status, and sprint roadmap, read `../../MINIK_MASTER_PLAN.md`.
