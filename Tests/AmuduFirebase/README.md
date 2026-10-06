# Spud (Amudu) Realtime Database rules — reference copy

Byte-identical copies of the Android project's `C:/Projects/MinikAmudu/firebase/` files. The iOS app writes the same
`minikAmudu/rooms/{CODE}` tree as Android, so these rules govern both platforms. Never deploy from here; production
rules are merged and deployed only with the owner's separate authorization.

| File | SHA-256 |
|---|---|
| `database.rules.json` | `74628dae6ab286fafc44a35b91ce734b31755ccedcce091bcf5b8180cb19b688` |
| `rules-test.cjs` | `12c6f3fbcc3d658883720e8060135c15e35167b4d1220e909fdbafead257bbc7` |
| `firebase.json` | `8980a41bdbd7e364174987800b571acfefb536320293a4bc2fdae3d7c1510e75` |
| `start-emulators.ps1` | `28c3a00402243f93613c6d97a5eded2a27cb62ea3d243678bbc607c34c5d71f2` |

## Run offline (local database emulator only)

`rules-test.cjs` uses mock auth tokens, so only the database emulator is needed. Start the cached emulator jar directly
(no Firebase CLI, so no update checks or downloads), then run the test against it:

```sh
java -jar ~/.cache/firebase/emulators/firebase-database-emulator-v4.11.2.jar --host 127.0.0.1 --port 19006 &
AMUDU_DATABASE_PORT=19006 node Tests/AmuduFirebase/rules-test.cjs
```

The script loads `@firebase/rules-unit-testing` and `firebase` read-only from
`C:/Projects/MinikPingPong/firebase/node_modules` (as on Android). Result on 2026-10-04: 106 passed, 0 failed,
0 production writes.
