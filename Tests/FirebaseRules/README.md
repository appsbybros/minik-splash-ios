# Firebase Rules emulator tests

These tests exercise the checked-in `firestore.rules` against the Firebase
Local Emulator Suite. They use only synthetic identities and documents under
the `demo-minik-rules` project ID; no production Firebase credentials or data
are required.

Prerequisites:

- Node.js 20 or newer;
- Java 21 or newer available through `JAVA_HOME`/`PATH`.

From the repository root:

```powershell
npm ci
npm run test:firebase-rules
```

The pinned CLI starts the Firestore emulator, runs the Node test suite, and
stops the emulator. The suite loads `firestore.rules` directly and separately
validates the exact structure of `firestore.indexes.json`. The emulator does
not prove production composite-index enforcement; deployment and a production
query check remain separate cutover steps.
