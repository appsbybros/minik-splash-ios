import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

const projectId = "demo-minik-rules";
const rulesPath = fileURLToPath(new URL("../../firestore.rules", import.meta.url));
const indexesPath = fileURLToPath(
  new URL("../../firestore.indexes.json", import.meta.url),
);

const playerA1 = "v2_11111111-1111-4111-8111-111111111111";
const playerA2 = "v2_22222222-2222-4222-8222-222222222222";
const legacyPlayer = "11111111-1111-4111-8111-111111111111";

let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(rulesPath, "utf8"),
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
});

after(async () => {
  await testEnvironment.cleanup();
});

function authenticatedFirestore(uid) {
  return testEnvironment.authenticatedContext(uid).firestore();
}

function unauthenticatedFirestore() {
  return testEnvironment.unauthenticatedContext().firestore();
}

function ownershipReference(database, playerId) {
  return doc(database, "leaderboard_owners", playerId);
}

function publicReference(database, collectionName, playerId) {
  return doc(database, collectionName, playerId);
}

async function claimPlayer(uid, playerId) {
  const database = authenticatedFirestore(uid);
  await assertSucceeds(
    setDoc(ownershipReference(database, playerId), { owner_uid: uid }),
  );
  return database;
}

function scoreDocument(
  playerId,
  {
    alias = "Bright Otter 27",
    avatarId = "star",
    score = 120,
    streak = 8,
    appId = "3",
    achievedAt = serverTimestamp(),
  } = {},
) {
  const data = {
    app_id: appId,
    player_id: playerId,
    score,
    correct_answers_in_row: streak,
    date_achived: achievedAt,
    user_name: alias,
  };
  if (avatarId !== undefined) {
    data.avatar_id = avatarId;
  }
  return data;
}

function streakDocument(
  playerId,
  {
    alias = "Bright Otter 27",
    avatarId = "star",
    streak = 8,
    appId = "3",
    achievedAt = serverTimestamp(),
  } = {},
) {
  const data = {
    app_id: appId,
    player_id: playerId,
    correct_answers_in_row: streak,
    date_achived: achievedAt,
    user_name: alias,
  };
  if (avatarId !== undefined) {
    data.avatar_id = avatarId;
  }
  return data;
}

async function createScore(uid, collectionName = "score_records", playerId = playerA1) {
  const database = await claimPlayer(uid, playerId);
  await assertSucceeds(
    setDoc(
      publicReference(database, collectionName, playerId),
      scoreDocument(playerId),
    ),
  );
  return database;
}

async function createStreak(uid, playerId = playerA1) {
  const database = await claimPlayer(uid, playerId);
  await assertSucceeds(
    setDoc(
      publicReference(database, "correct_answers_in_row", playerId),
      streakDocument(playerId),
    ),
  );
  return database;
}

test("one authenticated UID can own two distinct secure profile IDs", async () => {
  const database = authenticatedFirestore("uid-a");

  await assertSucceeds(
    setDoc(ownershipReference(database, playerA1), { owner_uid: "uid-a" }),
  );
  await assertSucceeds(
    setDoc(ownershipReference(database, playerA2), { owner_uid: "uid-a" }),
  );

  assert.notEqual(playerA1, playerA2);
  assert.match(playerA1, /^v2_[0-9a-f-]{36}$/);
  assert.match(playerA2, /^v2_[0-9a-f-]{36}$/);
});

test("an owner can idempotently reassert an unchanged ownership binding", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertSucceeds(
    setDoc(ownershipReference(database, playerA1), { owner_uid: "uid-a" }),
  );
});

test("another UID cannot overwrite an existing ownership binding", async () => {
  await claimPlayer("uid-a", playerA1);
  const database = authenticatedFirestore("uid-b");
  await assertFails(
    setDoc(ownershipReference(database, playerA1), { owner_uid: "uid-b" }),
  );
});

test("an owner cannot transfer an ownership binding", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    updateDoc(ownershipReference(database, playerA1), { owner_uid: "uid-b" }),
  );
});

test("ownership documents cannot be read by owners or unrelated clients", async () => {
  await claimPlayer("uid-a", playerA1);
  await assertFails(
    getDoc(ownershipReference(authenticatedFirestore("uid-a"), playerA1)),
  );
  await assertFails(
    getDoc(ownershipReference(authenticatedFirestore("uid-b"), playerA1)),
  );
});

test("ownership documents cannot be publicly listed", async () => {
  await claimPlayer("uid-a", playerA1);
  const database = authenticatedFirestore("uid-b");
  await assertFails(
    getDocs(query(collection(database, "leaderboard_owners"), limit(20))),
  );
});

test("ownership bindings cannot be deleted by clients", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(deleteDoc(ownershipReference(database, playerA1)));
});

test("a malformed v2 profile ID cannot be claimed", async () => {
  const database = authenticatedFirestore("uid-a");
  await assertFails(
    setDoc(ownershipReference(database, "v2_not-a-uuid"), {
      owner_uid: "uid-a",
    }),
  );
});

test("a legacy unversioned profile ID cannot be claimed", async () => {
  const database = authenticatedFirestore("uid-a");
  await assertFails(
    setDoc(ownershipReference(database, legacyPlayer), { owner_uid: "uid-a" }),
  );
});

test("a legacy unversioned profile cannot write even if an administrator seeded ownership", async () => {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(ownershipReference(context.firestore(), legacyPlayer), {
      owner_uid: "uid-a",
    });
  });
  const database = authenticatedFirestore("uid-a");
  await assertFails(
    setDoc(
      publicReference(database, "score_records", legacyPlayer),
      scoreDocument(legacyPlayer),
    ),
  );
});

test("an unauthenticated client cannot create ownership", async () => {
  const database = unauthenticatedFirestore();
  await assertFails(
    setDoc(ownershipReference(database, playerA1), { owner_uid: "uid-a" }),
  );
});

test("an owner can create a valid score_records document", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertSucceeds(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1),
    ),
  );
});

test("an owner can create a valid score_records_english_only document", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertSucceeds(
    setDoc(
      publicReference(database, "score_records_english_only", playerA1),
      scoreDocument(playerA1, { avatarId: undefined }),
    ),
  );
});

test("an owner can create a valid correct_answers_in_row document", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertSucceeds(
    setDoc(
      publicReference(database, "correct_answers_in_row", playerA1),
      streakDocument(playerA1),
    ),
  );
});

test("representative public documents contain only the shared contract fields", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  for (const collectionName of ["score_records", "score_records_english_only"]) {
    await assertSucceeds(
      setDoc(
        publicReference(database, collectionName, playerA1),
        scoreDocument(playerA1),
      ),
    );
  }
  await assertSucceeds(
    setDoc(
      publicReference(database, "correct_answers_in_row", playerA1),
      streakDocument(playerA1),
    ),
  );

  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const scoreKeys = [
      "app_id",
      "avatar_id",
      "correct_answers_in_row",
      "date_achived",
      "player_id",
      "score",
      "user_name",
    ];
    for (const collectionName of ["score_records", "score_records_english_only"]) {
      const snapshot = await getDoc(
        publicReference(context.firestore(), collectionName, playerA1),
      );
      const data = snapshot.data();
      assert.deepEqual(Object.keys(data).sort(), scoreKeys);
      assert.equal(data.app_id, "3");
      assert.equal(data.player_id, playerA1);
      assert.ok(data.date_achived instanceof Timestamp);
    }

    const streakSnapshot = await getDoc(
      publicReference(
        context.firestore(),
        "correct_answers_in_row",
        playerA1,
      ),
    );
    const streakData = streakSnapshot.data();
    assert.deepEqual(Object.keys(streakData).sort(), [
      "app_id",
      "avatar_id",
      "correct_answers_in_row",
      "date_achived",
      "player_id",
      "user_name",
    ]);
    assert.equal(streakData.app_id, "3");
    assert.equal(streakData.player_id, playerA1);
    assert.ok(streakData.date_achived instanceof Timestamp);
  });
});

test("an owner can update a score and streak monotonically", async () => {
  const database = await createScore("uid-a");
  await assertSucceeds(
    updateDoc(publicReference(database, "score_records", playerA1), {
      score: 150,
      correct_answers_in_row: 9,
      date_achived: serverTimestamp(),
    }),
  );
});

test("a score or associated streak cannot regress", async () => {
  const database = await createScore("uid-a");
  const reference = publicReference(database, "score_records", playerA1);
  await assertFails(
    updateDoc(reference, { score: 119, date_achived: serverTimestamp() }),
  );
  await assertFails(
    updateDoc(reference, {
      correct_answers_in_row: 7,
      date_achived: serverTimestamp(),
    }),
  );
});

test("a streak record can increase but cannot regress", async () => {
  const database = await createStreak("uid-a");
  const reference = publicReference(
    database,
    "correct_answers_in_row",
    playerA1,
  );
  await assertSucceeds(
    updateDoc(reference, {
      correct_answers_in_row: 9,
      date_achived: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(reference, {
      correct_answers_in_row: 8,
      date_achived: serverTimestamp(),
    }),
  );
});

test("an owner can delete owned public records from all active collections", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  for (const collectionName of ["score_records", "score_records_english_only"]) {
    const reference = publicReference(database, collectionName, playerA1);
    await assertSucceeds(setDoc(reference, scoreDocument(playerA1)));
    await assertSucceeds(deleteDoc(reference));
  }
  const streakReference = publicReference(
    database,
    "correct_answers_in_row",
    playerA1,
  );
  await assertSucceeds(setDoc(streakReference, streakDocument(playerA1)));
  await assertSucceeds(deleteDoc(streakReference));
});

test("another UID cannot update or delete an owned public record", async () => {
  await createScore("uid-a");
  const reference = publicReference(
    authenticatedFirestore("uid-b"),
    "score_records",
    playerA1,
  );
  await assertFails(
    updateDoc(reference, { score: 150, date_achived: serverTimestamp() }),
  );
  await assertFails(deleteDoc(reference));
});

test("unauthenticated public writes are denied", async () => {
  await claimPlayer("uid-a", playerA1);
  const database = unauthenticatedFirestore();
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1),
    ),
  );
});

test("a public write requires a matching ownership mapping", async () => {
  const database = authenticatedFirestore("uid-a");
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1),
    ),
  );
});

test("extra public or platform-specific fields are denied", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    setDoc(publicReference(database, "score_records", playerA1), {
      ...scoreDocument(playerA1),
      platform: "ios",
    }),
  );
});

test("a malformed public document profile ID is denied", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument("v2_not-a-uuid"),
    ),
  );
});

test("a non-curated public alias is denied", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1, { alias: "A real or free-text name" }),
    ),
  );
});

test("an invalid avatar identifier is denied", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1, { avatarId: "custom-photo" }),
    ),
  );
});

test("negative, zero, or out-of-range score and streak values are denied", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  const scoreReference = publicReference(database, "score_records", playerA1);
  const streakReference = publicReference(
    database,
    "correct_answers_in_row",
    playerA1,
  );

  await assertFails(setDoc(scoreReference, scoreDocument(playerA1, { score: 0 })));
  await assertFails(setDoc(scoreReference, scoreDocument(playerA1, { score: -1 })));
  await assertFails(
    setDoc(scoreReference, scoreDocument(playerA1, { score: 1_000_000_001 })),
  );
  await assertFails(
    setDoc(scoreReference, scoreDocument(playerA1, { streak: -1 })),
  );
  await assertFails(
    setDoc(scoreReference, scoreDocument(playerA1, { streak: 1_000_001 })),
  );
  await assertFails(
    setDoc(streakReference, streakDocument(playerA1, { streak: 0 })),
  );
});

test("the public contract rejects an app_id other than 3", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1, { appId: "4" }),
    ),
  );
});

test("a client-supplied timestamp that differs from request time is denied", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertFails(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1, {
        achievedAt: Timestamp.fromMillis(1_700_000_000_000),
      }),
    ),
  );
});

test("writes to unrelated Firestore paths are denied", async () => {
  const database = authenticatedFirestore("uid-a");
  await assertFails(setDoc(doc(database, "profiles", "uid-a"), { name: "Maya" }));
});

test("authenticated clients can run the three legitimate top-20 leaderboard queries", async () => {
  const database = await claimPlayer("uid-a", playerA1);
  await assertSucceeds(
    setDoc(
      publicReference(database, "score_records", playerA1),
      scoreDocument(playerA1),
    ),
  );
  await assertSucceeds(
    setDoc(
      publicReference(database, "score_records_english_only", playerA1),
      scoreDocument(playerA1),
    ),
  );
  await assertSucceeds(
    setDoc(
      publicReference(database, "correct_answers_in_row", playerA1),
      streakDocument(playerA1),
    ),
  );

  const reader = authenticatedFirestore("uid-b");
  for (const [collectionName, rankingField] of [
    ["score_records", "score"],
    ["score_records_english_only", "score"],
    ["correct_answers_in_row", "correct_answers_in_row"],
  ]) {
    await assertSucceeds(
      getDocs(
        query(
          collection(reader, collectionName),
          where("app_id", "==", "3"),
          orderBy(rankingField, "desc"),
          limit(20),
        ),
      ),
    );
  }
});

test("unauthenticated leaderboard reads are denied", async () => {
  const database = unauthenticatedFirestore();
  await assertFails(
    getDocs(query(collection(database, "score_records"), limit(20))),
  );
});

test("leaderboard reads without a limit or above the top-20 limit are denied", async () => {
  const database = authenticatedFirestore("uid-a");
  await assertFails(getDocs(collection(database, "score_records")));
  await assertFails(
    getDocs(query(collection(database, "score_records"), limit(21))),
  );
});

test("direct public-document reads are denied while list queries are the public surface", async () => {
  await createScore("uid-a");
  const database = authenticatedFirestore("uid-b");
  await assertFails(
    getDoc(publicReference(database, "score_records", playerA1)),
  );
});

test("checked-in composite index JSON exactly covers the three shared leaderboard queries", () => {
  const configuration = JSON.parse(readFileSync(indexesPath, "utf8"));
  assert.deepEqual(configuration.fieldOverrides, []);
  assert.deepEqual(configuration.indexes, [
    {
      collectionGroup: "score_records",
      queryScope: "COLLECTION",
      fields: [
        { fieldPath: "app_id", order: "ASCENDING" },
        { fieldPath: "score", order: "DESCENDING" },
      ],
    },
    {
      collectionGroup: "score_records_english_only",
      queryScope: "COLLECTION",
      fields: [
        { fieldPath: "app_id", order: "ASCENDING" },
        { fieldPath: "score", order: "DESCENDING" },
      ],
    },
    {
      collectionGroup: "correct_answers_in_row",
      queryScope: "COLLECTION",
      fields: [
        { fieldPath: "app_id", order: "ASCENDING" },
        { fieldPath: "correct_answers_in_row", order: "DESCENDING" },
      ],
    },
  ]);
});
