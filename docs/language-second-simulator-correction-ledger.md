# Language second-Simulator correction ledger

Active reconstruction started at 084ca2a3405700fa65841beadd3685ddcaec5d6c on codex-sprint-8h-20260830.
The owner's 2026-09-06 request supersedes earlier tap-only Soccer and static visual-completion claims.
All 16 Android reference screenshots were inspected. All 10 QA images were inspected by visible content.
This is an evolving source ledger. No post-fix Simulator review has occurred.

Status: IMPLEMENTED_SOURCE / REVIEWED_SOURCE describe code evidence only.
ANDROID_PARITY_IMPLEMENTED_SOURCE requires the complete source comparison for a screen.
RUNTIME_VERIFIED is reserved for an actual post-fix device/Simulator review.

## Intro, menu, Parent Area and interface locale

Android: MainActivity.kt launches IntroFragment (declared in IntroScreen.kt); Intro's Practice action launches
ButtonsMenuFragment. Phone and sw600dp fragment_intro_plus.xml / fragment_select_screen_plus.xml and
dialog_languages_and_levels.xml establish the panel, header, wordmark, dropdowns and close edges.
References: 14-main-menu-language-activities.png, 15-main-menu-games.png, 16-parent-area.png.
Owner QA reference: written sprint brief (these three screens are not pictured in the ten supplied QA files).

| ID | Owner/reference finding | Root cause before correction | Exact source correction | Evidence/status | Remaining runtime check |
|---|---|---|---|---|---|
| SH01 | Real Intro/welcome layer missing | nil hub route always rendered the activity menu | LanguageIntroView and separate menu state in MinikActivityHubView; Home returns Intro, activities return menu, Parent is entered from Intro | IMPLEMENTED_SOURCE; Android navigation traced | Opening, Home, close, re-entry |
| SH02 | Tiny/wrong visible menu logo | minik_logo uses minik_plus_logo_small.png: a pencil mascot with a 261×261 alpha footprint on a 512×554 canvas; Android menu uses the full wordmark | Exact decoded minik_plus_logo.webp imported as minik_language_logo; MinikLanguageLogo used at phone/tablet sizes | REVIEWED_SOURCE; decoded-pixel provenance passed | Visible scale and sharpness |
| SH03 | Home/Trophy group and panel alignment | Header outside the white activity panel; oversized generic sections | LanguageMenuView places centered Home/Trophy inside one bounded panel; full wordmark at Android leading edge; fixed header and scrolling activity content | IMPLEMENTED_SOURCE | RTL, safe area, iPad width |
| SH04 | Canonical artwork and menu density | Generic raised tile containers; captions inside tiles; Cards final cell not centered | Original activity art in shallow outlined frames, captions below, centered final Word Cards tile; all 13 activities retained, Memory remains Games | IMPLEMENTED_SOURCE | Long captions and tablet proportions |
| SH05 | Parent panel too large | Shared 82%-height sheet and nested settings cards | Language-only centered compact Parent dialog, menu pickers, trailing-edge X, existing language/encouragement/progress/records actions preserved; small/accessibility scroll fallback | IMPLEMENTED_SOURCE | Translated text fit, modal focus, dismissal |
| SH06 | Selecting Hebrew leaves Parent/app text English | Catalog Hebrew entries literally contain English; menu/locale names eagerly used process-language Strings | 78 Android-mapped Language keys, authored local-record/replay labels, deferred title/name keys, LocalizedStringResource selected-locale lookup; root and open Parent observe selected locale | REVIEWED_SOURCE; catalog guard rejects seven negative fixtures; XCTest authored | Real locale switch, VoiceOver and persistence |
| SH07 | Original opening state absent | iOS skipped the Android opening clip together with Intro | Original 1,872,051-byte intro_animation_plus.mp4 copied unchanged; LanguageOpeningView uses 20% audio, original 0.84 vertical crop, completion/tap/10-second fallback; once per hub lifetime; Reduce Motion and inactive-scene escape | IMPLEMENTED_SOURCE; source SHA-256 ba3618bb839ac913cbb0a946c089dd11c260b6c76fec36c07d188ffd78abd52b | Clip crop, playback/audio, interruption |
| ME01 | Picture Memory was a generic adaptive grid with oversized card chrome and ordinary scrolling | Dedicated Language route restores the exact plus_background scene, fixed 3x4 square board, Android blank-back palettes and revealed image scale, inside header/close, and original minik_boy proportions; no generic fraction/Continue/feedback capsule | ANDROID_PARITY_IMPLEMENTED_SOURCE | RUNTIME_VISUAL_VERIFICATION_PENDING: phone/tablet/Dynamic Type/RTL/VoiceOver/Reduce Motion |
| ME02 | Manual Continue and unscoped delayed work differed from Android's automatic evaluation | One-second automatic match/mismatch resolution, 220ms mismatch flip safety, locked input, presentation-scoped transition identity, lifecycle cancellation, continuous fresh sessions, exact-once accepted-reveal speech, and existing attempt recording; Math stays generic | ANDROID_PARITY_IMPLEMENTED_SOURCE; deterministic XCTest authored and focused source audit passes | Xcode/XCTest, audible speech/sounds, timing and re-entry |

## Language Tower / Alphabet Blocks

Android authority: `LettersTowerFragment.kt`, phone and `sw600dp` `fragment_letters_tower.xml`,
reference 11, localized strings, dimensions, speech/sound calls, animations and every referenced Tower
asset. The canonical live composition uses `minik_plus_tower_sitting`, `sand2` and `send_pile`;
Android may randomize the standing mascot, bucket/ball and castle alternatives in other rounds.

| ID | Owner/reference finding | Root cause before correction | Exact source correction | Evidence/status | Remaining runtime check |
|---|---|---|---|---|---|
| TO01 | Generic grid and giant answer surface replaced the Android play scene | Language and Math shared the generic `MinikPracticeScreen` composition | Dedicated Language-only scene keeps instruction, learned target, scattered physical blocks, bottom-up stack, speaker and inside close together without a normal-phone board ScrollView; Math keeps the existing value-ordering route | ANDROID_PARITY_IMPLEMENTED_SOURCE; focused negative guard rejects generic Language chrome | iPhone/iPad fit, drag target, accessibility-size fallback |
| TO02 | Original beach/gift presentation was incomplete | Only lower mascot/sand fragments sat inside a generic rounded panel | Exact decoded pastel scene plus canonical sitting gift mascot, `sand2` footer and `send_pile` foreground use Android phone/sw600 proportions; all imported pixels and source hashes are provenance-audited | ANDROID_PARITY_IMPLEMENTED_SOURCE | Visible-alpha framing and device scale |
| TO03 | Completion/retry lifecycle lacked the full Android-integrated contract | Typed token placement existed, but no integrated +2 completion dispatch or presentation-scoped delayed next-word guard | Correct-next-only placement, non-consuming wrong sound, independent duplicates, automatic whitespace spacers, locked base, final letter then word speech, confetti, exactly-once completion, fixed verified +2 reward and identity-guarded continuous rounds are wired through the shared event boundary | ANDROID_PARITY_IMPLEMENTED_SOURCE; deterministic XCTest authored | Xcode/XCTest, real speech/sound order, animation timing, background/re-entry |

## Language Tic-Tac-Toe

Android authority: the complete `TicTacToeFragment.kt`, all phone/sw600dp regular and Plus
`fragment_tic_tac_toe*.xml` layouts, reference 12, strings, dimensions/colors, AI/reset logic,
speech/sounds, animations, lifecycle cleanup and every live mascot/board asset.

| ID | Owner/reference finding | Root cause before correction | Exact source correction | Evidence/status | Remaining runtime check |
|---|---|---|---|---|---|
| TT01 | Generic scrolling practice card and dab mascot did not match the illustrated Android board scene | TicTacToeView used shared practice chrome and `minik_dab` despite the live Plus board-holding asset | Dedicated fixed panel uses exact `plus_background` and `minik_plus_with_tic_tac_toe`, inside close, gradient title, X/O controls, status and complete 3x3 board together; ordinary phones do not scroll | ANDROID_PARITY_IMPLEMENTED_SOURCE; exact source hashes audited | iPhone/iPad fit, Dynamic Type fallback, visual crop/scale |
| TT02 | Board edge treatment was teal-only and prior static claims did not close the full state review | Existing gameplay engine had not been rechecked against the complete current Android source | White cells now retain the Android purple/pink/teal edge; child-first/default-X, pre-move selection lock, retained/unlocked reset, A-E/Random/Adaptive, random/medium/minimax AI and hidden cumulative totals are traced and guarded without changing their semantics | ANDROID_PARITY_IMPLEMENTED_SOURCE; deterministic XCTest authored | Xcode/XCTest and live interaction |
| TT03 | Delayed-work, accessibility and non-mastery boundaries needed explicit proof | Result delay existed near synchronous AI logic and hidden scores could be mistaken for product progress | AI remains atomic with the child move, result transition is a single cancelled task, exit cancels all feedback work, spatial coordinates remain LTR in RTL interfaces, scores are never rendered and the route remains just-for-fun/outside mastery | REVIEWED_SOURCE; focused negative guards pass | VoiceOver/Switch Control, Reduce Motion, speech/audio/timing, background/re-entry |

The String initializer's locale parameter only formats interpolated values; the selected translation
language is supplied through LocalizedStringResource. This boundary was checked against Apple's
[String initializer documentation](https://developer.apple.com/documentation/swift/string/init(localized:table:bundle:locale:comment:))
and [LocalizedStringResource.locale](https://developer.apple.com/documentation/foundation/localizedstringresource/locale).
Both resource APIs used here are available from iOS 16. Native-language review remains pending for authored translations.

## QA image index and outstanding activity findings

The files below were matched to the displayed content, independently of their filenames.
The owner supplied full-size versions in conversation; the stored files were also inspected.
They show the pre-fix iOS result, not the visual target.

| QA ID | File | Visible content and all readable owner observations | Current status |
|---|---|---|---|
| QA01 | first_letter.png | Picture→first-letter, lemon. Entire composition should resemble Android; image too large; buttons look wrong; X must be inside the container; 1/6 does not belong | IMPLEMENTED_SOURCE; final source review/runtime pending |
| QA02 | learn.png | B/b/Banana. Home too small; controls vertically bunched; Home should be higher, Next lower; attractive triangular Play instead of Listen; on smaller screens reduce the picture before compressing control spacing | ANDROID_PARITY_IMPLEMENTED_SOURCE; runtime pending |
| QA03 | pairs.png | Eight-picture pairing board, selected king. Cards too tall; all should fit except genuinely small devices; images need not be enormous; panel needs margins on every side; X inside, no white backing; 0/4 unwanted | ANDROID_PARITY_IMPLEMENTED_SOURCE; runtime pending |
| QA04 | BuildWord.png | Peach construction. 1/6 unwanted; X inside container without white backing; empty Your word text clipped and hard to understand; use letter rather than token | IMPLEMENTED_SOURCE; final source review/runtime pending |
| QA05 | BuildWord_Failure_screen_cut.png | Garlic retry. X and bottom failure reaction clipped; essential empty instruction truncates | IMPLEMENTED_SOURCE; final source review/runtime pending |
| QA06 | BuildWord_Susscess_animation_should_be_big_and_transparent.png | Completed Garlic. Success reaction is a tiny capsule at the bottom; owner requires large transparent artwork | IMPLEMENTED_SOURCE; final source review/runtime pending |
| QA07 | cards_word.png | Ship card on meadow. X too close to corner; replay graphic wrong; top icon too small; short-word box too tall, target about 70% of current height; increase margins and word size unless long sentence; bottom mascot about twice visible size and higher; instruction larger/readable | IMPLEMENTED_SOURCE; final source review/runtime pending |
| QA08 | soccer1.png | Lower field/goal and five oversized white-disc letter buttons over multiple rows; gameplay does not fit | IMPLEMENTED_SOURCE; dedicated no-scroll field and fitted one-row colored letters; runtime pending |
| QA09 | soccer2.png | Upper Soccer state with giant Lemon image, oversized score boxes, 0/5 badge; field and letter controls continue below viewport | IMPLEMENTED_SOURCE; compact edge scores/target/built word and full field share one viewport; runtime pending |
| QA10 | soccer3.png | Shot toward keeper, truncated Shot in progress caption, clipped tiny failure reaction at bottom | IMPLEMENTED_SOURCE; vector flight, physical keeper/frame/goal result and compact overlay; runtime pending |

Additional Android discrepancies explicitly in scope: four vertical text-answer rows versus 2×2 picture
answers; outlined Learn letter art separated from the example word; Build host-language text-prompt
state in reference 06; real points/streak footers; large overlaid feedback; Soccer drag/physical outcome;
Tic-Tac-Toe's illustrated board
scene and mark-lock states; every embedded Mixed child, completion and re-entry state.
The crosswalk records which of these are repaired. Parent Levels and its global Language Auto A-E contract are `ANDROID_PARITY_IMPLEMENTED_SOURCE`: the shared level, durable per-word evidence, exact Write/Tower/Soccer full-pool thresholds, persisted two-pass gate, promotion, and previous/current list-count ramp are wired without coupling learned/interface language or Math. Soccer and the final Mixed/system review are also `ANDROID_PARITY_IMPLEMENTED_SOURCE`; runtime physics, visuals, audio, Auto lifecycle, Mixed transitions, and accessibility validation remain pending.

## Preservation and validation

The pre-sprint index was empty. A snapshot of 805 pre-existing tracked/untracked paths (including the
preserved README deletion) and their SHA-256/MISSING states was recorded outside the repository.
The first preservation comparison reported zero changed pre-existing paths. AGENTS.md, Android,
Phase 41 benchmark/workflow/catalog work, and the M3/Cards/shared-feedback compile fixes are preserved.

Windows checks run for the first shell unit: catalog/localization coverage, English Only production policy,
test-source compatibility, exact visual provenance, visual inventory, and the new selected-locale guard.
The new asset initially failed the strict allowlist; its exact provenance-backed name was added and the
check passed. XCTest, Xcode compilation, video playback and visual verification have not run on Windows.
No push, workflow dispatch, CI execution, or remote Git operation.

The pre-commit review also caught Windows shell transport replacing non-ASCII authored text with question marks. Unicode-safe transport repaired the authored values and XCTest literals before staging. The guard now rejects coupled corruption of both catalog and fixture data, and rejects the formatting-only locale initializer.

## Learn reconstruction

| ID | Owner/reference finding | Root cause before correction | Exact correction | Evidence/status | Remaining runtime check |
|---|---|---|---|---|---|
| LE01 | QA02 / reference 13: B b Banana combined in one line; original letter identity missing | LearnView grouped both leading learningText representations; no original letter-form assets were bundled | LanguageLearnContentProvider.presentation projects typed letter/word/image separately; LanguageLearnPage displays the original uppercase/lowercase or printed/handwritten forms above the original full-width divider, with picture and word below | ANDROID_PARITY_IMPLEMENTED_SOURCE; all 53 cards covered, all 106 forms visually inspected, 107 assets match original bytes/decoded pixels | Final letter scale, baseline and device spacing |
| LE02 | QA02: Home too small/low, Next too high, picture controls vertically bunched | One centered content stack with width-driven spacing | Height-aware upper/lower regions from fragment_learn.xml; 64/96-point Home at top, Next at bottom; image shrinks before the controls; natural-height accessibility scroll and small-device fallback | ANDROID_PARITY_IMPLEMENTED_SOURCE | iPhone 14 Pro / small phone / iPad / maximum Dynamic Type |
| LE03 | QA02: owner requires an attractive triangular Play instead of Listen/speaker treatment | The explicit owner contract governs this iOS replay affordance | LanguageReplayButton renders the triangular `play.fill` glyph without a Listen label or generic white circular chrome, retaining the 56x48 accessible hit area and all existing learned-language speech, stop, replay and loop paths | OWNER_CONTRACT_IMPLEMENTED_SOURCE | VoiceOver, audio and rapid Next/exit |
| SH08 | Preserve distinct Trophy and Parent records actions | First shell checkpoint accidentally pointed Trophy at local Records/Streaks | Follow-up restores existing recordsLeaderboard route and Top 20 records label; Parent local Records/Streaks remains intact | REVIEWED_SOURCE; no service integration or remote action | Both destinations and return paths |

Learn source: Android LearnScreen.kt, layout/fragment_learn.xml and layout-sw600dp/fragment_learn.xml.
All 107 imports and visible alpha bounds are listed in language-learn-artwork-provenance.tsv.
The normal layout uses the Android 42% phone / 45% tablet divider region. English capital/lowercase
and Hebrew handwritten/print order follow Android independently of the interface language.
New XCTest covers Banana's exact boundary, every bundled form, final-kaf pronunciation/artwork,
and independence from card IDs. It has not executed on Windows.
The deterministic Windows Learn guard passes and rejects three negative source mutations.

## Pairs reconstruction

| ID | Finding and source root cause | Exact correction and evidence | Status / runtime check |
|---|---|---|---|
| PA01 | QA03 / reference 07: oversized scrolling tiles, arbitrary 0/4, outer X and edge-touching panel | PairsView Language route uses LanguageActivityScreen, inset white panel, full wordmark/X header, 2x4 height-budgeted board and original pairs_image mascot with real points; ordinary phone needs no board scroll | ANDROID_PARITY_IMPLEMENTED_SOURCE; final phone/tablet rendering pending |
| PA02 | Matched tiles reflowed because activeMixedItems removed them | mixedBoardItems retains all eight positions; matched groups fade to invisible/scale .72 and become accessibility-hidden; deterministic tests cover matching, retry, deselection and a new board | ANDROID_PARITY_IMPLEMENTED_SOURCE; VoiceOver/animation pending |
| PA03 | Generic selected caption, Continue action and feedback capsule replaced Android interaction | Original yellow 3-point selection edge / 1.045 scale; 220ms evaluation, 330ms correct fade, final-pair 1300ms pause; wrong 430ms shake then retry; no extra Continue | ANDROID_PARITY_IMPLEMENTED_SOURCE; gesture/timing judgment pending |
| PA04 | Original success/failure audio and encouragement absent | Exact original MP3s copied with SHA provenance; host-language encouragement queued behind learned-word speech on one synthesizer; task identity/cancellation protects exit/background/re-entry and avoids duplicate feedback audio | IMPLEMENTED_SOURCE; audio and interruption pending |
| SH09 | White Language panels could inherit white text in system dark mode | Language-only preferred light color scheme matches the Android source palette; Learn and shared panels use natural-height scroll fallback above default Dynamic Type | REVIEWED_SOURCE; dark-mode launch and larger text pending |

Android evidence: LetterPairsFragment.kt and both fragment_letter_pairs.xml layouts plus item_letter_pair_image.xml / bg_minik_gradient_rounded.xml. The original physical horizontal purple/pink/teal border is retained independent of interface direction. The Pairs title and eight encouragement phrases use original Android locale values. The Pairs Windows guard checks the actual production route and rejects eight negative mutations; original audio hashes match. Existing localization, test-source, Language speech and visual source checks pass. Native XCTest and post-fix visual/audio review remain pending.

## Choice and Build reconstruction

| ID | Finding / exact Android root cause | Source correction and deterministic evidence | Status / remaining check |
|---|---|---|---|
| CH01 | QA01 and references 01-04: one adaptive grid used for four different Android compositions | LanguageChoicePage uses four vertical text rows (48-point letters/68-point words) or 2x2 pictures, small padded prompt, original shallow asymmetric gradient frames, inside X/Play and three real statistics | IMPLEMENTED_SOURCE; default phone/tablet and long-text rendering pending |
| CH02 | Generic feedback capsule, selected labels and missing original sounds | Original 200x265 success jump / 165x220 retry over the board, teal/pink options, original success variants, seven original star sprites and four byte-identical sounds; original Fredoka-Medium registered only for both Language targets | IMPLEMENTED_SOURCE; decoded image/audio/font provenance passes; animation/audio pending |
| CH03 | Fixed advance delay could cut off the spoken word or encouragement | One synthesizer queue now tracks actual utterance completion; cancellation identities ignore old callbacks; correct waits for learned speech and optional host encouragement, wrong retains 1500ms reset | IMPLEMENTED_SOURCE; pure queue regression covers stale/duplicate finish; real AVSpeechSynthesizer pending |
| BU01 | QA04-06 and reference 06: only an image prompt, token jargon, truncated empty text, reflowed selected letters | LanguageWordBuildClue projects typed host clue separately from typed learned answer/speech; one yellow outlined word field and fixed original-style circular letter pool; selected physical tokens fade to holes; no arbitrary fraction | IMPLEMENTED_SOURCE; deterministic Arrow/Ar and duplicate-r tests authored |
| BU02 | Wrong-letter retry and skip state could disappear after accepting the next letter | BuildSession retains hasIncorrectAttempt until the next word; rejected letters do not consume a token or change prefix; fixed-position/prefix/new-word tests added | IMPLEMENTED_SOURCE; physical drag and long-word layouts pending |
| BU03 | Per-letter progress was incorrectly sufficient as the only completion boundary for scoring | Typed LanguageWordCompletion scores exactly once; per-letter educational attempts remain separate. Wrong letter resets the local bonus run without spending points or erasing displayed streak. Its event ID is persisted through the existing ledger as a zero-point, streak-neutral marker, so replay remains idempotent after service recreation. Re-entry restores bonus from the saved streak, as DRAG initControls does | IMPLEMENTED_SOURCE; reward-service tests cover completed/repaired words, durable event replay and cross-session stale rejection |
| CH04 | Small factory batches returned to menu instead of continuous Android practice | Canonical four choices and Build request the next batch inside the existing activity; Build advances a monotonic presentation identity across batch replacement so repeated semantic word/token content starts at attempt 1; Mixed retains its own typed child replacement/mode progression | IMPLEMENTED_SOURCE; continuous progression and Mixed final review pending |

Build source is WriteScreen's DRAG branch / fragment_drag.xml in tap mode (handleLetterTap), not the separate keyboard WRITE screen. Plus Intro fixes the reading setting to index 2. WordItemLoader sets hostingWord to Hebrew for a Hebrew interface, otherwise English. With image-ready content, differing English/Hebrew host and learned language gives a text-only host clue (reference 06 is Hebrew Arrow / English Ar); same language gives audio-only practice; other interface languages show original image plus the English hosting fallback. Learning language and semantic identity remain unchanged. No new reading-level selector was invented.

Rewards and retry: WriteScreen 2415-2482 and subsequent branches, 2717-2746, 3463/3555, and 4531-4572 distinguish local bonus run from persisted displayed streak. Its wrong-choice state exposes Next immediately while its delayed reset preserves same-challenge retry. LanguageWordPracticeRewardService persists both scoring and rejected-letter identities in the ledger, so duplicate IDs are rejected before re-entry initialization even after service recreation. The existing Math policies and typed Math contract are unchanged.

The AVSpeechSynthesizerDelegate completion boundary follows Apple's [delegate contract](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizerdelegate). Nonisolated callbacks carry only object identity into the main actor; old cancellation identities cannot drain the current queue. Native actor/API typechecking remains pending.

Choice and Build source guards reject eleven and thirteen negative mutations respectively, covering wrong board family, speech/cancellation removal, immediate wrong-answer Next, physical-position loss, presentation identity, wrong host clue, durable rejected-letter identity, duplicate completion and lost retry state. Native XCTest has been authored, not executed on Windows.

## Word Cards reconstruction

| ID | Finding / root cause | Exact correction and evidence | Status / remaining check |
|---|---|---|---|
| CA01 | QA07 / reference 05: tiny pencil icon and corner controls | Android source/layout and the canonical screenshot confirm the visible Cards title. Shared inside navigation keeps that title with the original full wordmark and Play/X, 26/38-point side insets and safe-area content | IMPLEMENTED_SOURCE; final rendered header pending |
| CA02 | Short-word box too tall/wide, small word, low small mascot and hint | Short card 154/231 high (70 percent of previous 220/330), horizontal 32/65 margins; original blue/teal/green 76/119 text; original mascot 200/300 raised 35/45; readable 18/28 hint; no card elevation; ordinary full-viewport page | IMPLEMENTED_SOURCE; long phrases/accessibility/phone/tablet rendering pending |
| CA03 | Timer keyed only by card identity could advance inactive or repeated presentations | Active-scene task key plus independent CardsSession presentation UUID; one-card loops restart and stale repeated-card timers fail; two deterministic race tests added; shuffle bag and Android 4500-11000ms formula retained | IMPLEMENTED_SOURCE; native timer/manual/VoiceOver race pending |
| CA04 | Preserve prior Mac accessibility repair and non-graded scope | Exactly one accessibilityAction(.default) calls the same guarded speech-stop/advance path; no progress attempts; Android hint appears once per hub process and fades after five seconds | IMPLEMENTED_SOURCE; six API-negative mutations retained; native accessibility pending |

Cards Android source and both layouts were read completely. Original meadow, full wordmark and pairs mascot pixel/alpha dimensions were checked; existing provenance remains valid. The updated static audit follows the live shared header, active-scene guard and presentation identity instead of requiring removed speaker/logo tokens in CardsView.

All 16 canonical references now have explicit REFERENCE and IOS entries in [the visual crosswalk](language-android-visual-crosswalk.md). Soccer, Parent Levels/Language Auto, and the final Mixed/system review are reconstructed and reconciled in source. No post-fix runtime images have been generated or reviewed. Latest preservation comparison must be rerun at checkpoint review.
