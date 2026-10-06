# Tic-Tac-Toe parity notes

The native game preserves the current Android production Random/Adaptive
mismatch through `TicTacToeCompatibilityPolicy.androidProduction`. Random
chooses Easy, Medium, or Hard uniformly but updates the persisted adaptive
state; Adaptive consumes that state without updating it.

The Android Minik-win phrase, “We lost this time. Hope it was fun!”, is kept in
`TicTacToeFeedbackCopy.androidCompatibleMinikWinPhrase` until product copy
explicitly supersedes it.

The two Android child-move MP3 files are reused. Minik moves remain silent.

The Android Plus board-holding mascot (`minik_plus_with_tic_tac_toe.webp`) and
pastel panel scene (`plus_background.webp`) are decoded into dedicated iOS
assets with source hashes recorded in `minik-visual-asset-provenance.tsv`.
`TicTacToeView` uses those production visuals directly; it has no substitute
mascot or generic practice-card fallback.

The preference seam is intentionally app-local. It does not introduce the
future parent/profile settings architecture.
