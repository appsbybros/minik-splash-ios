# Language speech static audit

This ledger records source-level speech wiring only. It does not establish that
audio is audible in Appetize, Simulator, or on a physical device.

| Activity | Learned-language cue and invocation | Replay | Lifecycle | Static result |
| --- | --- | --- | --- | --- |
| Learn | Letter/word study-card plan is spoken when shown. | One explicit card plan. | Stops on exit, background, and disappearance. | Wired |
| Pairs / Letter Pairs | The selected tile's typed word cue is spoken. | Selection is the pronunciation control. | Stops on exit, background, and disappearance. | Wired |
| First Letter picture → letter | Image prompt carries the full learned word; selected letter carries its learned-language text cue. | One prompt cue. | Shared Multiple Choice stops on exit, background, and disappearance. | Wired |
| First Letter letter → picture | Letter prompt carries its text cue; every image choice carries its full learned word. | One prompt cue. | Shared Multiple Choice stops on exit, background, and disappearance. | Wired |
| Picture → Word | Image prompt carries its learned word; text choices derive their learned-language cues. | One prompt cue. | Shared Multiple Choice stops on exit, background, and disappearance. | Wired |
| Word → Picture | Text prompt and every image choice resolve the corresponding learned word. | One prompt cue. | Shared Multiple Choice stops on exit, background, and disappearance. | Wired |
| Build Word | Image prompt carries the full word; button/VoiceOver activation and drag/drop paths speak the selected token. | One full-word prompt cue. | Stops on exit, background, and disappearance. | Wired |
| Word Cards | Study-card plan is spoken when the card is shown. | One explicit card plan. | Stops on exit, background, and disappearance. | Wired |
| Soccer | Full word is spoken for the round; selected ordered token is spoken once. | One full-word cue. | Stops on exit, background, and disappearance. | Wired |
| Tower | Full word is spoken for the round; accepted token is spoken once, followed by the completed word only at completion. | One full-word cue. | Stops on exit, background, and disappearance. | Wired |
| Picture Memory | Each newly revealed Language card returns one typed learned-word cue; Math supplies no cue map. | Reveal is the pronunciation control. | Stops on exit, background, and disappearance. | Wired |

`LearningSpeechPlayer` always submits a valid cue to `AVSpeechSynthesizer`.
When the requested installed locale voice is unavailable, the synthesizer is
allowed to use its system default instead of silently dropping the utterance.

Live audio, voice availability, interruption handling, and remote-stream volume
remain `REQUIRES_RUNTIME_RETEST` on Apple hardware.
