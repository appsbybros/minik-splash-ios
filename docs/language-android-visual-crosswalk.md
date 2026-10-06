# Complete Language Android visual crosswalk

All 16 canonical screenshots were visually inspected. This is a live reconstruction record, not a post-fix rendering claim. Paths for Android source/layouts are under ../android/app/src/main/; every phone layout also has its sw600dp counterpart where listed. Exact imported image hashes/pixels are recorded in the provenance TSVs. OPEN entries require implementation before the complete source gate can pass.

## 01-language-word-to-picture-pea.png

REFERENCE
- Screenshot: reference/android-ui/01-language-word-to-picture-pea.png
- Android source/layout: WriteScreen.kt; fragment_host.xml -> fragment_choose_right_image.xml (phone/sw600dp)
- Android assets: minik_background, minik_close_button, bg_minik_gradient_rounded, star, trophy; original Pea/Corn/Bean/Lemon catalog pictures
- Landmarks and approximate proportions: Inset white panel about 90% width/85% height; X inside, centered replay; blue instruction and large Pea; four pictures in 2x2; three small footer statistics.

IOS
- Production route/view: MinikActivityHubView.wordToImage -> MultipleChoiceView(.wordToPicture) -> LanguageChoicePage
- Before: Outer X/fraction, large generic prompt and adaptive raised cards.
- Source changes: LanguageChoicePage fixes 2x2 images, bounded prompt, asymmetric original border, three real statistics; LanguageActivityScreen supplies inset panel; original reaction overlays.
- Remaining/status: IMPLEMENTED_SOURCE; check exact native text fit and artwork sizes.

## 02-language-picture-to-word-pig.png

REFERENCE
- Screenshot: reference/android-ui/02-language-picture-to-word-pig.png
- Android source/layout: WriteScreen.kt; fragment_host.xml -> fragment_choose_right_image.xml (phone/sw600dp)
- Android assets: Pig catalog picture; minik_plus_success/success2/success3, minik_plus_try_again, minik_star1..7, star, trophy, bg_minik_gradient_rounded
- Landmarks and approximate proportions: Small Pig around 30% panel width; four vertical word rows; teal correct row; large transparent mascot crosses lower rows/footer.

IOS
- Production route/view: Hub.imageToWord -> MultipleChoiceView(.pictureToWord) -> LanguageChoicePage
- Before: 2x2 text grid, oversized picture, small capsule feedback.
- Source changes: Four vertical 68-point rows, 132-point padded prompt, large 200x265 original jump and 165x220 retry; exact sound/encouragement queue; typed once-only choice rewards.
- Remaining/status: IMPLEMENTED_SOURCE; final animation/speech overlap and all locales pending.

## 03-language-first-letter-picture-to-letter.png

REFERENCE
- Screenshot: reference/android-ui/03-language-first-letter-picture-to-letter.png
- Android source/layout: WriteScreen.kt; fragment_choose_right_image.xml (phone/sw600dp)
- Android assets: Runner catalog picture; original frame/X/reaction/star/trophy artwork
- Landmarks and approximate proportions: Runner about one quarter panel width; four shallow vertical letters; spacious white panel and three footer statistics.

IOS
- Production route/view: Hub.firstLetterChoices -> MultipleChoiceView(.firstLetterPictureToLetter)
- Before: QA01 giant lemon, generic 2x2 boxes, outer X and 1/6.
- Source changes: Four vertical 48-point letter rows and small image; inset X; fraction removed from Language; real rewards and retry/skip preserved.
- Remaining/status: IMPLEMENTED_SOURCE; iPhone14Pro/default and long UI strings need rendering.

## 04-language-first-letter-letter-to-picture.png

REFERENCE
- Screenshot: reference/android-ui/04-language-first-letter-letter-to-picture.png
- Android source/layout: WriteScreen.kt; fragment_choose_right_image.xml (phone/sw600dp)
- Android assets: Seven/Five/Eight/Two catalog pictures; minik_plus_try_again and shared frame/stat assets
- Landmarks and approximate proportions: Large purple T above 2x2 pictures; selected wrong Seven pink; transparent Try Again artwork covers lower board.

IOS
- Production route/view: Hub.firstLetterPictures -> MultipleChoiceView(.firstLetterLetterToPicture)
- Before: Same generic grid/prompt shell and tiny reaction.
- Source changes: Typed direction preserves learned-letter prompt; fixed 2x2 picture board, pink/teal states, original full retry overlay and delayed reset.
- Remaining/status: IMPLEMENTED_SOURCE; retry touch lock, VoiceOver and layout pending.

## 05-language-word-cards-corn.png

REFERENCE
- Screenshot: reference/android-ui/05-language-word-cards-corn.png
- Android source/layout: RandomWordCardsFragment.kt; fragment_random_word_cards.xml (phone/sw600dp)
- Android assets: cards_background.jpeg, minik_plus_logo.webp, minik_close_button.webp, pairs_image.webp, bg_minik_gradient_rounded
- Landmarks and approximate proportions: Full meadow/sky; inside header with visible localized Cards title; Corn gradient word in short card around one quarter screen height; instruction below; recognizable mascot raised from bottom.

IOS
- Production route/view: Hub.cards -> CardsView
- Before: QA07 tiny pencil logo, corner X, speaker graphic, tall short-word card, tiny low mascot and small hint.
- Source changes: CardsView uses the verified Cards title and full wordmark/shared inset Play/X; short card 154/231, larger 76/119-point word, doubled horizontal inset; 200/300 mascot raised 35/45; original blue/teal/green text; viewport page, accessibility fallback; active-scene presentation timer.
- Remaining/status: IMPLEMENTED_SOURCE; native card sizing/gradient, long phrases, tap/timer and audio pending.

## 06-language-build-word-hebrew.png

REFERENCE
- Screenshot: reference/android-ui/06-language-build-word-hebrew.png
- Android source/layout: WriteScreen.kt; fragment_host.xml -> fragment_drag.xml; WordItem.kt hostingWord; IntroScreen.kt Plus reading index 2
- Android assets: bg_letter_chip.xml, builtword_border.xml, original reaction/star/trophy artwork; Arrow catalog identity (image suppressed in this host/learned-language combination)
- Landmarks and approximate proportions: Hebrew host clue above EN partial Ar inside yellow outline; three small remaining circles in fixed positions; large white breathing space; footer statistics.

IOS
- Production route/view: Hub.wordBuild -> BuildView(.word) -> LanguageBuildPage / LanguageWordBuildClue
- Before: QA04-06 image-only giant prompt, token jargon/truncation, consumed letters reflowed and small/clipped reactions; reference state absent.
- Source changes: Typed clue projects host Hebrew Arrow text while speech/answer stay English; same-language uses audio, other hosts original image+English fallback; single outlined word and 48-point circles keep holes; large feedback; completion scores once independently from per-letter attempts.
- Remaining/status: IMPLEMENTED_SOURCE; deterministic Arrow/Ar test authored; drag, long words and native speech pending.

## 07-language-letter-pairs.png

REFERENCE
- Screenshot: reference/android-ui/07-language-letter-pairs.png
- Android source/layout: LetterPairsFragment.kt; fragment_letter_pairs.xml phone/sw600dp; item_letter_pair_image.xml
- Android assets: pairs_image.webp, minik_plus_logo.webp, minik_close_button.webp, bg_minik_gradient_rounded; eight original catalog images
- Landmarks and approximate proportions: 2x4 eight shallow pictures, yellow selected border, fixed empty matched positions; logo/X inside panel; bottom mascot and points.

IOS
- Production route/view: Hub.pairs -> PairsView Language branch
- Before: QA03 tall scrolling grid, generic selected caption, outer X and 0/4.
- Source changes: Height-budgeted 2x4 fixed board; yellow selection and correct fade/wrong shake; all eight physical positions retained; real points; original feedback audio and queued host encouragement.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; native final fit/timing pending.

## 08-soccer-instructions.png

REFERENCE
- Screenshot: reference/android-ui/08-soccer-instructions.png
- Android source/layout: SoccerIntroDialog.kt; fragment_letters_soccer_game_tour_dialog.xml phone/sw600dp; LettersSoccerGame.kt
- Android assets: `minik_splash`; Plus `plus_background`; `mimik_star`; `minik_goalie_new_right` / Plus `minik_plus_goalie`; `minik_soccer_ball`; yellow Material Start action
- Landmarks and approximate proportions: Dim scene, gradient instruction title/body explaining DRAG; large football mascot low in panel; yellow Start and countdown.

IOS
- Production route/view: Hub.soccer -> LanguageSoccerView introduction
- Before: Generic white card and tap-only rewritten instructions.
- Source changes: Complete live source/layout/asset path inspected. Dedicated first-three-launch branded overlay uses the same localized drag-up copy for visible/interface speech, original keeper/football art, and yellow Start action over the live scene.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; native layout/audio/linguistic review pending.

## 09-soccer-gameplay.png

REFERENCE
- Screenshot: reference/android-ui/09-soccer-gameplay.png
- Android source/layout: LettersSoccerGame.kt; fragment_letters_soccer.xml phone/sw600dp
- Android assets: `minik_soccer_field_new.png`, `mink_gate_new.webp`; runtime chooses `minik_goalie_new`/right or Plus `minik_plus_goalie`/right (with the existing 1-in-8 creature alternative) and converts the released letter to live `soccer_ball`; `minik_kick`, `minik_kick2`, crowd applause/disappointment and claps are the active audio path
- Landmarks and approximate proportions: Field about 90% width and 65% height; net above, small keeper, text target Sorry, compact score edges, one row of small colored letter balls, X inside.

IOS
- Production route/view: Hub.soccer -> LanguageSoccerView / LanguageSoccerPracticeSession
- Before: QA08-10 giant image and score cards, multirow white discs, clipped field/retry; tap chooses simulated outcome.
- Source changes: Dedicated Language-only no-scroll field; compact edge scores/target/built word/one-row colored letters; upward drag release; vector-driven football flight; shared-coordinate keeper/posts/crossbar/goal collision and rebound; shot-ID exact-once finalization; original scene art. Parent A/B/C now controls exact Android-derived keeper scale, first stationary/moving attempts, sweep timing, range and post-ten-shot performance adjustment. Math Soccer remains isolated.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; Mac/device physics, fit, reaction prominence and audio validation pending.

## 10-language-picture-memory.png

REFERENCE
- Screenshot: reference/android-ui/10-language-picture-memory.png
- Android source/layout: MemoryGameFragment.kt; fragment_memory_game.xml phone/sw600dp
- Android assets: bg_kids_gradient outer frame, plus_background pastel panel scene, bg_card_front_kids3/4/5 blank diagonal backs, bg_minik_gradient_rounded revealed fronts, Baby/Book/Radio catalog pictures, minik_boy
- Landmarks and approximate proportions: Pastel clouds/stars inside panel; twelve small squares in 3x4, blank gradient backs; two matching Baby reveals; compact title/count.

IOS
- Production route/view: Hub.wordMemory -> MemoryView(.languagePicture)
- Before: Generic adaptive board/chrome, oversized tiles/mascot.
- Source changes: Dedicated Language-only pastel panel; fixed 3-column x 4-row square board with all 12 physical cards; three Android-derived blank-back palettes; direct fitted vocabulary images; inside close/title/instruction; Android-scale minik_boy; no generic fraction, feedback capsule, Continue control, or normal-phone board scrolling. One-second automatic evaluation, mismatch flip-back safety, continuous clean rounds, and presentation-scoped stale-callback rejection preserve speech, attempts, lifecycle cancellation, accessibility, and fixed LTR board positions. Generic Math Memory remains on the prior shared presentation.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; RUNTIME_VISUAL_VERIFICATION_PENDING (iPhone/iPad sizing, Dynamic Type fallback, RTL, VoiceOver/Switch Control, Reduce Motion, speech/audio, transition timing, completion/re-entry).

## 11-language-alphabet-blocks.png

REFERENCE
- Screenshot: reference/android-ui/11-language-alphabet-blocks.png
- Android source/layout: LettersTowerFragment.kt; fragment_letters_tower.xml phone/sw600dp
- Android assets: minik_plus_tower_sitting.webp, sand2.webp, send_pile.webp; sand_bucket/sand_ball/minik_plus_tower_standing/sand_castle visibility to trace; original pastel scene
- Landmarks and approximate proportions: Purple target/instruction; loose colored blocks near sand; locked base and vertical tower; large seated mascot lower left; replay and X inside.

IOS
- Production route/view: Hub.tower -> TowerView / LanguageTowerPracticeSession
- Before: Generic stack/pool composition, static visual-lock claims do not prove scene parity.
- Source changes: Dedicated Language-only pastel scene with inside speaker replay/X, Android block-letter title, exact instruction and target/built-word hierarchy; loose physical blocks keep stable scattered positions rather than an adaptive grid; accepted blocks and automatic whitespace spacers grow bottom-up from the locked base. Exact sitting gift-block mascot, sand2 footer and send_pile foreground reproduce canonical reference 11, using Android's seven solid block colors. Wrong blocks remain loose and play the original failure sound; presentation-scoped transitions, final letter→word speech, continuous clean words, semantic telemetry and fixed +2 completion reward are guarded independently from Math Tower.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; RUNTIME_VISUAL_VERIFICATION_PENDING (iPhone/iPad sizing, drag/drop target feel, Dynamic Type fallback, English/Hebrew and interface RTL/LTR, VoiceOver/Switch Control, Reduce Motion, speech/audio order, transition timing, completion/re-entry).

## 12-tic-tac-toe.png

REFERENCE
- Screenshot: reference/android-ui/12-tic-tac-toe.png
- Android source/layout: TicTacToeFragment.kt; phone and sw600dp fragment_tic_tac_toe.xml plus fragment_tic_tac_toe_plus.xml variants
- Android assets: minik_plus_with_tic_tac_toe (not minik_dab); plus_background; bg_minik_gradient_rounded; minik_close_button; minik_kick/minik_kick2
- Landmarks and approximate proportions: Pastel panel, gradient title, teal X/O choice, 3x3 white cells; large mascot holding actual Tic-Tac-Toe board at bottom.

IOS
- Production route/view: Hub.ticTacToe -> TicTacToeView
- Before: Wrong dab mascot inside a generic scrolling practice surface; teal-only board edges did not reproduce the Android purple/pink/teal treatment.
- Source changes: Dedicated fixed Language composition uses the exact pastel panel and board-holding mascot, inside branded close, gradient localized title, pre-first-move X/O choice, status and a complete white-cell 3x3 board together. Ordinary phones do not scroll; only short-height/accessibility layouts use a deliberate fallback. The existing child-first session, selected-mark lock/reset, A-E/Random/Adaptive mappings, synchronous AI resolution, hidden match totals, speech/sounds and result timing remain intact.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; RUNTIME_VISUAL_VERIFICATION_PENDING (iPhone/iPad fit, Dynamic Type fallback, RTL/LTR, VoiceOver/Switch Control, Reduce Motion, speech/audio/timing, background/re-entry).

## 13-language-learn-letter-b-banana.png

REFERENCE
- Screenshot: reference/android-ui/13-language-learn-letter-b-banana.png
- Android source/layout: LearnScreen.kt; fragment_learn.xml phone/sw600dp
- Android assets: Exact English B/b letter forms, Banana image and divider from language-learn-artwork-provenance.tsv; go_back_home.png
- Landmarks and approximate proportions: Full white; large Home high; original capital/small forms above divider around 42%; Banana and separate word below; Next near bottom.

IOS
- Production route/view: Hub.learn -> LearnView(.language) -> LanguageLearnPage
- Before: QA02 combined B b Banana line, bunched controls, small Home and Listen pill.
- Source changes: 53 typed cards/106 original forms plus divider; separate word and image; height-aware upper/lower regions; 64/96 Home, owner-required triangular Play-style replay, low yellow Next; shrink image first.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE; native rendering/audio pending.

## 14-main-menu-language-activities.png

REFERENCE
- Screenshot: reference/android-ui/14-main-menu-language-activities.png
- Android source/layout: ButtonsMenuFragment.kt; fragment_select_screen_plus.xml phone/sw600dp
- Android assets: minik_plus_logo.webp, trophy.webp, go_back_home.png and exact 13 menu assets in minik-visual-asset-provenance.tsv
- Landmarks and approximate proportions: Inset white panel; fixed inside header, centered Home/Trophy, semantic-leading wordmark; two shallow art frames per row, captions outside.

IOS
- Production route/view: MinikActivityHubView -> LanguageMenuView
- Before: Generic tile chrome, header outside panel, wrong visible logo.
- Source changes: Dedicated menu panel/header, canonical section order, two-column shallow borders/captions, original full wordmark and native safe-area insets.
- Remaining/status: IMPLEMENTED_SOURCE; final source system review/translated captions pending.

## 15-main-menu-games.png

REFERENCE
- Screenshot: reference/android-ui/15-main-menu-games.png
- Android source/layout: ButtonsMenuFragment.kt; fragment_select_screen_plus.xml phone/sw600dp
- Android assets: minik_plus_cards, plus_letters_tower, minik_plus_soccer, minik_plus_tic_tac_toe, minik_plus_memory; learned-language-specific variants
- Landmarks and approximate proportions: Scrolling continuation; final Word Cards centered; Games Tower/Soccer then Tic-Tac-Toe/Memory; commercial footer outside authorized implementation.

IOS
- Production route/view: LanguageMenuView lower content
- Before: Final odd cell off center; inconsistent art hierarchy.
- Source changes: Centered last Cards tile, Games order and shallow original art frames; Android-authorized menu scroll retained.
- Remaining/status: IMPLEMENTED_SOURCE; final scroll, tap targets and iPad/RTL pending.

## 16-parent-area.png

REFERENCE
- Screenshot: reference/android-ui/16-parent-area.png
- Android source/layout: IntroScreen.kt; fragment_intro_plus.xml; LanguagesAndLevelsDialogFragment.kt / dialog_languages_and_levels.xml; LevelsDifficultyDialogFragment.kt
- Android assets: minik_plus_logo, minik_plus_welcome, close; actual persisted points/streak labels
- Landmarks and approximate proportions: Intro behind compact white Parent panel around half screen height; blue title, two language pickers, encouragement, Progress and Levels; X inside.

IOS
- Production route/view: LanguageIntroView -> ParentAreaView
- Before: Menu instead of Intro underneath; oversized modal; selected interface locale could leave text English; Levels missing.
- Source changes: Intro layering/compact panel/live locale repaired and existing local Records/Streaks preserved. Levels opens the Android-derived modal with persisted Auto/manual word A-E, Soccer A-C and Tic-Tac-Toe A-E/Random/Adaptive controls. Manual word A-E drives production vocabulary filtering; Soccer A/B/C now drives its production keeper contract; Tic-Tac-Toe already consumes its setting. Plus and fixed-English English Only share it without a Home selector or Math coupling.
- Remaining/status: ANDROID_PARITY_IMPLEMENTED_SOURCE. Global Language Auto uses durable per-content Write/Tower/Soccer evidence, exact complete-pool thresholds, the shared two-pass A-E promotion value, and the persisted previous/current ramp. Mixed is excluded from Write Auto evidence. Native phone/iPad, Arabic RTL, VoiceOver and restart/background persistence review remain pending.
