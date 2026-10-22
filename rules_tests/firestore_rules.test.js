const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const { doc, setDoc, updateDoc, getDoc, deleteDoc, collection, query, where, getDocs } = require('firebase/firestore');

const PROJECT_ID = 'smart-waste-collection-manager';

async function runTests() {
  const rules = fs.readFileSync(path.resolve(__dirname, '../firestore.rules'), 'utf8');

  const testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8080,
    },
  });

  console.log('Testing Firestore Security Rules on Emulator...');
  let passed = 0;
  let failed = 0;

  async function test(name, fn) {
    try {
      await fn();
      console.log(`  [PASS] ${name}`);
      passed++;
    } catch (e) {
      console.error(`  [FAIL] ${name}: ${e.message}`);
      failed++;
    } finally {
      await testEnv.clearFirestore();
    }
  }

  // 1. A resident cannot promote themselves to admin
  await test('A resident cannot promote themselves to admin', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users/res-1'), {
        uid: 'res-1',
        email: 'resident@test.com',
        displayName: 'Test Resident',
        role: 'resident',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const resContext = testEnv.authenticatedContext('res-1', { role: 'resident' });
    const resDb = resContext.firestore();

    await assertFails(
      updateDoc(doc(resDb, 'users/res-1'), {
        role: 'admin',
      })
    );
  });

  // 2. A user cannot tamper with their own uid or createdAt
  await test('A user cannot tamper with their own uid or createdAt', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'users/res-1'), {
        uid: 'res-1',
        email: 'resident@test.com',
        displayName: 'Test Resident',
        role: 'resident',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const resContext = testEnv.authenticatedContext('res-1', { role: 'resident' });
    const resDb = resContext.firestore();

    // Tamper uid
    await assertFails(
      updateDoc(doc(resDb, 'users/res-1'), {
        uid: 'tampered-uid',
      })
    );

    // Tamper createdAt
    await assertFails(
      updateDoc(doc(resDb, 'users/res-1'), {
        createdAt: '2020-01-01T00:00:00Z',
      })
    );
  });

  // 3. Valid report creation is allowed for resident and enforces ID match
  await test('Valid report creation is allowed and rejects mismatched report IDs', async () => {
    const resContext = testEnv.authenticatedContext('res-1', { role: 'resident' });
    const resDb = resContext.firestore();

    // Mismatched ID should fail
    await assertFails(
      setDoc(doc(resDb, 'reports/rep-1'), {
        id: 'rep-mismatched-id',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Pending',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      })
    );

    // Matching ID succeeds
    await assertSucceeds(
      setDoc(doc(resDb, 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Pending',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      })
    );
  });

  // 4. Incident facts cannot be tampered with by a worker
  await test('A worker cannot modify report description, priority, location, or reporter ID', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Assigned',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/worker-1'), {
        uid: 'worker-1',
        email: 'worker@test.com',
        role: 'worker',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const workerContext = testEnv.authenticatedContext('worker-1', { role: 'worker' });
    const workerDb = workerContext.firestore();

    // Tamper description
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        description: 'Tampered description',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    // Tamper priority
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        priority: 'Low',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    // Tamper location
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        location: '999 Faked Address',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    // Tamper reporterId
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        reporterId: 'res-someone-else',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 5. Worker cannot update a report assigned to another worker
  await test('A worker cannot update a report assigned to another worker', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Assigned',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/worker-2'), {
        uid: 'worker-2',
        email: 'worker2@test.com',
        role: 'worker',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const workerContext = testEnv.authenticatedContext('worker-2', { role: 'worker' });
    const workerDb = workerContext.firestore();

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 6. Resident cannot update report once status is no longer Pending
  await test('A resident cannot modify an already assigned report', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Assigned',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/res-1'), {
        uid: 'res-1',
        email: 'resident@test.com',
        role: 'resident',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const resContext = testEnv.authenticatedContext('res-1', { role: 'resident' });
    const resDb = resContext.firestore();

    await assertFails(
      updateDoc(doc(resDb, 'reports/rep-1'), {
        description: 'Trying to edit after worker assignment',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 7. Assigned -> In Progress transition cannot introduce resolutionNotes
  await test('Assigned -> In Progress transition cannot introduce resolution notes', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Assigned',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/worker-1'), {
        uid: 'worker-1',
        email: 'worker@test.com',
        role: 'worker',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const workerContext = testEnv.authenticatedContext('worker-1', { role: 'worker' });
    const workerDb = workerContext.firestore();

    // Attempting to attach resolutionNotes when starting work
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'In Progress',
        resolutionNotes: 'Preliminary note attached too early',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    // Starting work without resolution notes succeeds
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 8. In Progress -> Completed requires non-empty resolutionNotes
  await test('In Progress -> Completed requires non-empty resolution notes', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'In Progress',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T11:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/worker-1'), {
        uid: 'worker-1',
        email: 'worker@test.com',
        role: 'worker',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const workerContext = testEnv.authenticatedContext('worker-1', { role: 'worker' });
    const workerDb = workerContext.firestore();

    // Attempting to complete without resolution notes
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'Completed',
        updatedAt: '2026-10-21T12:00:00Z',
      })
    );

    // Attempting to complete with empty resolution notes
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'Completed',
        resolutionNotes: '',
        updatedAt: '2026-10-21T12:00:00Z',
      })
    );

    // Completing with valid notes succeeds
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'Completed',
        resolutionNotes: 'Cleaned area thoroughly and recycled bottles.',
        updatedAt: '2026-10-21T12:00:00Z',
      })
    );
  });

  // 9. Workers cannot modify resolution notes once completed
  await test('Workers cannot modify or clear resolution notes after completion', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Completed',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        resolutionNotes: 'Initial completion note',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T12:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/worker-1'), {
        uid: 'worker-1',
        email: 'worker@test.com',
        role: 'worker',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const workerContext = testEnv.authenticatedContext('worker-1', { role: 'worker' });
    const workerDb = workerContext.firestore();

    // Trying to alter resolution notes on completed report
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        resolutionNotes: 'Altered completion note',
        updatedAt: '2026-10-21T13:00:00Z',
      })
    );

    // Trying to clear resolution notes on completed report
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        resolutionNotes: null,
        updatedAt: '2026-10-21T13:00:00Z',
      })
    );

    // Updating updatedAt only without touching notes succeeds
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        updatedAt: '2026-10-21T13:00:00Z',
      })
    );
  });

  // 10. Legitimate admin operations (worker assignment and dispatch)
  await test('Legitimate admin operations (dispatch and assignment) succeed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'reports/rep-1'), {
        id: 'rep-1',
        reporterId: 'res-1',
        reporterName: 'Resident Sujitha',
        wasteCategory: 'Plastic Waste',
        location: '123 Elm Street Sector 4',
        description: 'Piles of bottles',
        priority: 'High',
        status: 'Pending',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/admin-1'), {
        uid: 'admin-1',
        email: 'admin@test.com',
        role: 'admin',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const adminContext = testEnv.authenticatedContext('admin-1', { admin: true, role: 'admin' });
    const adminDb = adminContext.firestore();

    // Admin assigns worker
    await assertSucceeds(
      updateDoc(doc(adminDb, 'reports/rep-1'), {
        status: 'Assigned',
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        updatedAt: '2026-10-21T10:30:00Z',
      })
    );
  });

  // 11. A resident can successfully create their own valid profile document
  await test('A resident can successfully create their own valid profile document', async () => {
    const resContext = testEnv.authenticatedContext('res-new-1', { email: 'resident.new@test.com' });
    const resDb = resContext.firestore();

    await assertSucceeds(
      setDoc(doc(resDb, 'users/res-new-1'), {
        uid: 'res-new-1',
        email: 'resident.new@test.com',
        displayName: 'New Resident',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      })
    );
  });

  // 12. Rejection of self-created worker and admin profiles on creation
  await test('Rejection of self-created worker and admin profiles on creation', async () => {
    const workerAttacker = testEnv.authenticatedContext('attacker-worker', { email: 'worker.bad@test.com' });
    const workerDb = workerAttacker.firestore();

    await assertFails(
      setDoc(doc(workerDb, 'users/attacker-worker'), {
        uid: 'attacker-worker',
        email: 'worker.bad@test.com',
        displayName: 'Attacker Worker',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      })
    );

    const adminAttacker = testEnv.authenticatedContext('attacker-admin', { email: 'admin.bad@test.com' });
    const adminDb = adminAttacker.firestore();

    await assertFails(
      setDoc(doc(adminDb, 'users/attacker-admin'), {
        uid: 'attacker-admin',
        email: 'admin.bad@test.com',
        displayName: 'Attacker Admin',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      })
    );
  });

  // 13. Rejection of creating a profile document for another UID
  await test('Rejection of creating a profile document for another UID', async () => {
    const userA = testEnv.authenticatedContext('user-a', { email: 'usera@test.com' });
    const userADb = userA.firestore();

    // Trying to create a profile under user-b document path
    await assertFails(
      setDoc(doc(userADb, 'users/user-b'), {
        uid: 'user-b',
        email: 'userb@test.com',
        displayName: 'Victim User',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      })
    );

    // Trying to create user-a document with mismatched internal uid
    await assertFails(
      setDoc(doc(userADb, 'users/user-a'), {
        uid: 'user-mismatch',
        email: 'usera@test.com',
        displayName: 'Spoofed UID',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      })
    );
  });

  // 14. Rejection of unauthenticated profile creation
  await test('Rejection of unauthenticated profile creation', async () => {
    const unauthContext = testEnv.unauthenticatedContext();
    const unauthDb = unauthContext.firestore();

    await assertFails(
      setDoc(doc(unauthDb, 'users/unauth-user'), {
        uid: 'unauth-user',
        email: 'unauth@test.com',
        displayName: 'Anonymous',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      })
    );
  });

  // 15. Profile-read privacy: user can read own profile, admin can read all, unauthorized reads rejected
  await test('Profile-read privacy: user can read own profile, admin can read all, unauthorized reads rejected', async () => {
    // Seed test profiles
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/res-alice'), {
        uid: 'res-alice',
        email: 'alice@resident.org',
        displayName: 'Alice Resident',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/res-bob'), {
        uid: 'res-bob',
        email: 'bob@resident.org',
        displayName: 'Bob Resident',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/worker-charlie'), {
        uid: 'worker-charlie',
        email: 'charlie@worker.org',
        displayName: 'Charlie Worker',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/admin-dan'), {
        uid: 'admin-dan',
        email: 'dan@admin.org',
        displayName: 'Dan Admin',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const aliceContext = testEnv.authenticatedContext('res-alice', { email: 'alice@resident.org', role: 'resident' });
    const aliceDb = aliceContext.firestore();

    // 1. Alice can read her own profile
    await assertSucceeds(getDoc(doc(aliceDb, 'users/res-alice')));

    // 2. Alice CANNOT read Bob's profile (protects Bob's email and PII)
    await assertFails(getDoc(doc(aliceDb, 'users/res-bob')));

    // 3. Alice CANNOT read Charlie's profile (protects worker email and PII)
    await assertFails(getDoc(doc(aliceDb, 'users/worker-charlie')));

    // 4. Unauthenticated context CANNOT read any profile
    const unauthDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(unauthDb, 'users/res-alice')));

    // 5. Administrator CAN read any profile
    const adminContext = testEnv.authenticatedContext('admin-dan', { admin: true, role: 'admin' });
    const adminDb = adminContext.firestore();
    await assertSucceeds(getDoc(doc(adminDb, 'users/res-alice')));
    await assertSucceeds(getDoc(doc(adminDb, 'users/worker-charlie')));
  });

  // =========================================================================
  // Checkpoint 5: Role Authorization Consistency Tests (Requirements 1 - 13)
  // =========================================================================

  // CP5 Req 1: Profile-only resident, worker, and admin authorization
  await test('CP5 Req 1: Profile-only resident, worker, and admin authorization without custom claims', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/po-admin'), {
        uid: 'po-admin',
        email: 'po-admin@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/po-worker'), {
        uid: 'po-worker',
        email: 'po-worker@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/po-resident'), {
        uid: 'po-resident',
        email: 'po-res@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-po-worker'), {
        id: 'rep-po-worker',
        reporterId: 'po-resident',
        reporterName: 'Resident User',
        wasteCategory: 'Household Waste',
        location: '456 Oak Avenue',
        description: 'Household trash',
        priority: 'Medium',
        status: 'Assigned',
        assignedWorkerId: 'po-worker',
        assignedWorkerName: 'Profile Worker',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    // Admin without role claims can read other profiles
    const adminDb = testEnv.authenticatedContext('po-admin', { email: 'po-admin@test.com' }).firestore();
    await assertSucceeds(getDoc(doc(adminDb, 'users/po-resident')));

    // Worker without role claims can update assigned report
    const workerDb = testEnv.authenticatedContext('po-worker', { email: 'po-worker@test.com' }).firestore();
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-po-worker'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );

    // Resident without role claims can read own profile, but cannot read other profiles
    const resDb = testEnv.authenticatedContext('po-resident', { email: 'po-res@test.com' }).firestore();
    await assertSucceeds(getDoc(doc(resDb, 'users/po-resident')));
    await assertFails(getDoc(doc(resDb, 'users/po-worker')));
  });

  // CP5 Req 2: Matching role string and boolean claims
  await test('CP5 Req 2: Matching role string and boolean claims succeed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/m-admin'), {
        uid: 'm-admin',
        email: 'admin@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/m-worker'), {
        uid: 'm-worker',
        email: 'worker@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/m-res'), {
        uid: 'm-res',
        email: 'res@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-m-worker'), {
        id: 'rep-m-worker',
        reporterId: 'm-res',
        reporterName: 'Resident M',
        wasteCategory: 'Household Waste',
        location: '789 Pine Street',
        description: 'Trash pile',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'm-worker',
        assignedWorkerName: 'Worker M',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    const adminDb = testEnv.authenticatedContext('m-admin', { admin: true, role: 'admin' }).firestore();
    await assertSucceeds(getDoc(doc(adminDb, 'users/m-res')));

    const workerDb = testEnv.authenticatedContext('m-worker', { worker: true, role: 'worker' }).firestore();
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-m-worker'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );

    const resDb = testEnv.authenticatedContext('m-res', { role: 'resident' }).firestore();
    await assertSucceeds(getDoc(doc(resDb, 'users/m-res')));
  });

  // CP5 Req 3: Admin claims conflicting with a worker profile
  await test('CP5 Req 3: Admin claims conflicting with a worker profile fail closed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/worker-conflict'), {
        uid: 'worker-conflict',
        email: 'worker.c@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/other-res-3'), {
        uid: 'other-res-3',
        email: 'other3@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-wc'), {
        id: 'rep-wc',
        reporterId: 'other-res-3',
        reporterName: 'Other Resident',
        wasteCategory: 'Household Waste',
        location: '789 Pine Street',
        description: 'Trash pile',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'worker-conflict',
        assignedWorkerName: 'Worker Conflict',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    // User has worker profile but asserts admin claims
    const conflictedDb = testEnv.authenticatedContext('worker-conflict', { admin: true, role: 'admin' }).firestore();
    // Cannot act as admin (profile is not admin)
    await assertFails(getDoc(doc(conflictedDb, 'users/other-res-3')));
    // Cannot act as worker (claims contradict worker profile)
    await assertFails(
      updateDoc(doc(conflictedDb, 'reports/rep-wc'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );
  });

  // CP5 Req 4: Worker claims conflicting with an admin profile
  await test('CP5 Req 4: Worker claims conflicting with an admin profile fail closed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/admin-conflict'), {
        uid: 'admin-conflict',
        email: 'admin.c@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/target-res-4'), {
        uid: 'target-res-4',
        email: 'target4@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-ac'), {
        id: 'rep-ac',
        reporterId: 'target-res-4',
        reporterName: 'Target Resident',
        wasteCategory: 'Household Waste',
        location: '789 Pine Street',
        description: 'Trash pile',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'admin-conflict',
        assignedWorkerName: 'Admin Conflict',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    // User has admin profile but asserts worker claims
    const conflictedDb = testEnv.authenticatedContext('admin-conflict', { worker: true, role: 'worker' }).firestore();
    // Cannot act as admin (claims contradict admin role)
    await assertFails(getDoc(doc(conflictedDb, 'users/target-res-4')));
    // Cannot act as worker (profile is not worker)
    await assertFails(
      updateDoc(doc(conflictedDb, 'reports/rep-ac'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );
  });

  // CP5 Req 5: role: resident conflicting with an admin profile
  await test('CP5 Req 5: role: resident claim conflicting with an admin profile fails closed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/admin-res-claim'), {
        uid: 'admin-res-claim',
        email: 'admin.rc@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/other-res-5'), {
        uid: 'other-res-5',
        email: 'other5@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    // Admin profile with role: 'resident' claim cannot perform admin operations
    const db = testEnv.authenticatedContext('admin-res-claim', { role: 'resident' }).firestore();
    await assertFails(getDoc(doc(db, 'users/other-res-5')));
  });

  // CP5 Req 6: role: admin conflicting with a resident profile
  await test('CP5 Req 6: role: admin claim conflicting with a resident profile fails closed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/res-admin-claim'), {
        uid: 'res-admin-claim',
        email: 'res.ac@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/other-res-6'), {
        uid: 'other-res-6',
        email: 'other6@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    // Resident profile with role: 'admin' claim cannot perform admin operations
    const db = testEnv.authenticatedContext('res-admin-claim', { role: 'admin' }).firestore();
    await assertFails(getDoc(doc(db, 'users/other-res-6')));
  });

  // CP5 Req 7: Invalid role strings and malformed claim types
  await test('CP5 Req 7: Invalid role strings and malformed claim types are rejected', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/admin-malformed'), {
        uid: 'admin-malformed',
        email: 'admin.m@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/target-7'), {
        uid: 'target-7',
        email: 'target7@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    // Unknown role string
    const dbUnknownRole = testEnv.authenticatedContext('admin-malformed', { role: 'superadmin' }).firestore();
    await assertFails(getDoc(doc(dbUnknownRole, 'users/target-7')));

    // String type for boolean flag 'admin'
    const dbStringBool = testEnv.authenticatedContext('admin-malformed', { admin: 'true', role: 'admin' }).firestore();
    await assertFails(getDoc(doc(dbStringBool, 'users/target-7')));

    // Numeric type for boolean flag 'worker'
    const dbNumBool = testEnv.authenticatedContext('admin-malformed', { worker: 1, role: 'admin' }).firestore();
    await assertFails(getDoc(doc(dbNumBool, 'users/target-7')));

    // Non-string role
    const dbArrayRole = testEnv.authenticatedContext('admin-malformed', { role: 123 }).firestore();
    await assertFails(getDoc(doc(dbArrayRole, 'users/target-7')));
  });

  // CP5 Req 8: admin: true and worker: true together
  await test('CP5 Req 8: admin: true and worker: true together are rejected', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/dual-privileged'), {
        uid: 'dual-privileged',
        email: 'dual@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/target-8'), {
        uid: 'target-8',
        email: 'target8@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const db = testEnv.authenticatedContext('dual-privileged', { admin: true, worker: true }).firestore();
    await assertFails(getDoc(doc(db, 'users/target-8')));
  });

  // CP5 Req 9: Contradictory role strings and boolean flags in both directions
  await test('CP5 Req 9: Contradictory role strings and boolean flags in both directions are rejected', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/contra-admin'), {
        uid: 'contra-admin',
        email: 'contra.admin@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/contra-worker'), {
        uid: 'contra-worker',
        email: 'contra.worker@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/target-9'), {
        uid: 'target-9',
        email: 'target9@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    // 1. role: admin with admin: false
    const dbAdminFalse = testEnv.authenticatedContext('contra-admin', { role: 'admin', admin: false }).firestore();
    await assertFails(getDoc(doc(dbAdminFalse, 'users/target-9')));

    // 2. role: worker with worker: false
    const dbWorkerFalse = testEnv.authenticatedContext('contra-worker', { role: 'worker', worker: false }).firestore();
    await assertFails(getDoc(doc(dbWorkerFalse, 'users/target-9')));

    // 3. role: admin with worker: true
    const dbAdminWorkerTrue = testEnv.authenticatedContext('contra-admin', { role: 'admin', worker: true }).firestore();
    await assertFails(getDoc(doc(dbAdminWorkerTrue, 'users/target-9')));

    // 4. role: worker with admin: true
    const dbWorkerAdminTrue = testEnv.authenticatedContext('contra-worker', { role: 'worker', admin: true }).firestore();
    await assertFails(getDoc(doc(dbWorkerAdminTrue, 'users/target-9')));

    // 5. role: resident with admin: true
    const dbResAdminTrue = testEnv.authenticatedContext('contra-admin', { role: 'resident', admin: true }).firestore();
    await assertFails(getDoc(doc(dbResAdminTrue, 'users/target-9')));

    // 6. role: resident with worker: true
    const dbResWorkerTrue = testEnv.authenticatedContext('contra-worker', { role: 'resident', worker: true }).firestore();
    await assertFails(getDoc(doc(dbResWorkerTrue, 'users/target-9')));
  });

  // CP5 Req 10: Explicit false flags with a valid profile, according to the documented policy
  await test('CP5 Req 10: Explicit false flags with a valid profile behave according to documented policy', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/ef-res'), {
        uid: 'ef-res',
        email: 'ef.res@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/ef-admin'), {
        uid: 'ef-admin',
        email: 'ef.admin@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/ef-worker'), {
        uid: 'ef-worker',
        email: 'ef.worker@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-ef-worker'), {
        id: 'rep-ef-worker',
        reporterId: 'ef-res',
        reporterName: 'Resident EF',
        wasteCategory: 'Household Waste',
        location: '101 Pine Street',
        description: 'Trash pile',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'ef-worker',
        assignedWorkerName: 'Worker EF',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    // Resident with { admin: false, worker: false } can read own profile, but cannot read others
    const resDb = testEnv.authenticatedContext('ef-res', { admin: false, worker: false }).firestore();
    await assertSucceeds(getDoc(doc(resDb, 'users/ef-res')));
    await assertFails(getDoc(doc(resDb, 'users/ef-admin')));

    // Admin with non-conflicting { worker: false } can act as admin
    const adminWorkerFalseDb = testEnv.authenticatedContext('ef-admin', { worker: false }).firestore();
    await assertSucceeds(getDoc(doc(adminWorkerFalseDb, 'users/ef-res')));

    // Admin with { admin: false } is explicitly denied admin role
    const adminFalseDb = testEnv.authenticatedContext('ef-admin', { admin: false }).firestore();
    await assertFails(getDoc(doc(adminFalseDb, 'users/ef-res')));

    // Worker with non-conflicting { admin: false } can act as worker
    const workerAdminFalseDb = testEnv.authenticatedContext('ef-worker', { admin: false }).firestore();
    await assertSucceeds(
      updateDoc(doc(workerAdminFalseDb, 'reports/rep-ef-worker'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );

    // Worker with { worker: false } is explicitly denied worker role
    const workerFalseDb = testEnv.authenticatedContext('ef-worker', { worker: false }).firestore();
    await assertFails(
      updateDoc(doc(workerFalseDb, 'reports/rep-ef-worker'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );
  });

  // CP5 Req 11: Attempts by a resident to self-promote
  await test('CP5 Req 11: Resident cannot self-promote to admin or worker', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/res-promo'), {
        uid: 'res-promo',
        email: 'promo@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const resDb = testEnv.authenticatedContext('res-promo', { role: 'resident' }).firestore();

    // Resident attempts to update role to admin
    await assertFails(
      updateDoc(doc(resDb, 'users/res-promo'), {
        role: 'admin',
      })
    );

    // Resident attempts to update role to worker
    await assertFails(
      updateDoc(doc(resDb, 'users/res-promo'), {
        role: 'worker',
      })
    );
  });

  // CP5 Req 12: Existing legitimate admin dispatch and worker report updates
  await test('CP5 Req 12: Legitimate admin dispatch and worker report lifecycle progression', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/admin-dispatch'), {
        uid: 'admin-dispatch',
        email: 'admin.dispatch@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/worker-field'), {
        uid: 'worker-field',
        email: 'worker.field@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/resident-creator'), {
        uid: 'resident-creator',
        email: 'resident.creator@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-lifecycle'), {
        id: 'rep-lifecycle',
        reporterId: 'resident-creator',
        reporterName: 'Resident Creator',
        wasteCategory: 'Plastic Waste',
        location: '123 Market Street',
        description: 'Large waste pile',
        priority: 'High',
        status: 'Pending',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    const adminDb = testEnv.authenticatedContext('admin-dispatch', { admin: true, role: 'admin' }).firestore();
    const workerDb = testEnv.authenticatedContext('worker-field', { worker: true, role: 'worker' }).firestore();

    // 1. Admin assigns worker to pending report
    await assertSucceeds(
      updateDoc(doc(adminDb, 'reports/rep-lifecycle'), {
        status: 'Assigned',
        assignedWorkerId: 'worker-field',
        assignedWorkerName: 'Worker Field',
        updatedAt: '2026-10-22T10:30:00Z',
      })
    );

    // 2. Worker transitions Assigned -> In Progress
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-lifecycle'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );

    // 3. Worker transitions In Progress -> Completed with resolution notes
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-lifecycle'), {
        status: 'Completed',
        resolutionNotes: 'Collected and transported to sorting facility.',
        updatedAt: '2026-10-22T11:30:00Z',
      })
    );
  });

  // CP5 Req 13: A demoted admin's stale privileged claims no longer granting admin access
  await test('CP5 Req 13: Demoted admin stale claims no longer grant admin access', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      // Admin was demoted in Firestore to 'resident'
      await setDoc(doc(db, 'users/demoted-admin'), {
        uid: 'demoted-admin',
        email: 'demoted@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/other-profile-13'), {
        uid: 'other-profile-13',
        email: 'other13@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-to-delete'), {
        id: 'rep-to-delete',
        reporterId: 'other-profile-13',
        reporterName: 'Other Profile',
        wasteCategory: 'Household Waste',
        location: '555 Birch Road',
        description: 'Old report',
        priority: 'Low',
        status: 'Pending',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    // Token still has stale admin claims from before demotion
    const demotedDb = testEnv.authenticatedContext('demoted-admin', { admin: true, role: 'admin' }).firestore();

    // 1. Demoted admin CANNOT read other users' profiles
    await assertFails(getDoc(doc(demotedDb, 'users/other-profile-13')));

    // 2. Demoted admin CANNOT delete reports
    await assertFails(deleteDoc(doc(demotedDb, 'reports/rep-to-delete')));

    // 3. Demoted admin CANNOT promote users or alter roles
    await assertFails(
      updateDoc(doc(demotedDb, 'users/other-profile-13'), {
        role: 'admin',
      })
    );
  });

  // =========================================================================
  // Checkpoint 7: Final Role-Claim Regression Tests (Cases 1 - 9)
  // =========================================================================

  // Case 1: Admin profile with { role: "admin", worker: false }
  await test('CP7 Case 1: Admin profile with { role: "admin", worker: false } succeeds for admin operations', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-admin-1'), {
        uid: 'cp7-admin-1',
        email: 'cp7.admin1@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-target-1'), {
        uid: 'cp7-target-1',
        email: 'cp7.target1@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const adminDb = testEnv.authenticatedContext('cp7-admin-1', { role: 'admin', worker: false }).firestore();
    // Admin reads another user's profile (protected admin operation)
    await assertSucceeds(getDoc(doc(adminDb, 'users/cp7-target-1')));
  });

  // Case 2: Worker profile with { role: "worker", admin: false }
  await test('CP7 Case 2: Worker profile with { role: "worker", admin: false } succeeds for worker operations', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-worker-2'), {
        uid: 'cp7-worker-2',
        email: 'cp7.worker2@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-cp7-2'), {
        id: 'rep-cp7-2',
        reporterId: 'cp7-resident-creator',
        reporterName: 'Resident Creator',
        wasteCategory: 'Household Waste',
        location: '123 Park Street',
        description: 'Household trash',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'cp7-worker-2',
        assignedWorkerName: 'CP7 Worker 2',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    const workerDb = testEnv.authenticatedContext('cp7-worker-2', { role: 'worker', admin: false }).firestore();
    // Worker advances status on assigned report
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-cp7-2'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );
  });

  // Case 3: Resident profile with { role: "resident", admin: false, worker: false }
  await test('CP7 Case 3: Resident profile with { role: "resident", admin: false, worker: false } allows own profile and denies admin ops', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-res-3'), {
        uid: 'cp7-res-3',
        email: 'cp7.res3@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-other-3'), {
        uid: 'cp7-other-3',
        email: 'cp7.other3@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const resDb = testEnv.authenticatedContext('cp7-res-3', { role: 'resident', admin: false, worker: false }).firestore();
    // Resident can read own profile
    await assertSucceeds(getDoc(doc(resDb, 'users/cp7-res-3')));
    // Resident CANNOT read another user's profile
    await assertFails(getDoc(doc(resDb, 'users/cp7-other-3')));
  });

  // Case 4: Admin profile with { admin: false }
  await test('CP7 Case 4: Admin profile with { admin: false } is explicitly denied admin operations', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-admin-4'), {
        uid: 'cp7-admin-4',
        email: 'cp7.admin4@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-target-4'), {
        uid: 'cp7-target-4',
        email: 'cp7.target4@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const adminFalseDb = testEnv.authenticatedContext('cp7-admin-4', { admin: false }).firestore();
    // Denied admin profile inspection due to explicit false flag
    await assertFails(getDoc(doc(adminFalseDb, 'users/cp7-target-4')));
  });

  // Case 5: Worker profile with { worker: false }
  await test('CP7 Case 5: Worker profile with { worker: false } is explicitly denied worker operations', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-worker-5'), {
        uid: 'cp7-worker-5',
        email: 'cp7.worker5@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-cp7-5'), {
        id: 'rep-cp7-5',
        reporterId: 'cp7-resident-creator',
        reporterName: 'Resident Creator',
        wasteCategory: 'Household Waste',
        location: '123 Park Street',
        description: 'Household trash',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'cp7-worker-5',
        assignedWorkerName: 'CP7 Worker 5',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    const workerFalseDb = testEnv.authenticatedContext('cp7-worker-5', { worker: false }).firestore();
    // Denied worker report status advance due to explicit false flag
    await assertFails(
      updateDoc(doc(workerFalseDb, 'reports/rep-cp7-5'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );
  });

  // Case 6: Admin profile with { role: "worker", admin: true }
  await test('CP7 Case 6: Admin profile with { role: "worker", admin: true } fails closed due to contradictory claims', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-admin-6'), {
        uid: 'cp7-admin-6',
        email: 'cp7.admin6@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-target-6'), {
        uid: 'cp7-target-6',
        email: 'cp7.target6@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const conflictedDb = testEnv.authenticatedContext('cp7-admin-6', { role: 'worker', admin: true }).firestore();
    // Contradictory claims fail closed; cannot perform admin operations
    await assertFails(getDoc(doc(conflictedDb, 'users/cp7-target-6')));
  });

  // Case 7: Worker profile with { role: "admin", worker: true }
  await test('CP7 Case 7: Worker profile with { role: "admin", worker: true } fails closed due to contradictory claims', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-worker-7'), {
        uid: 'cp7-worker-7',
        email: 'cp7.worker7@test.com',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-target-7'), {
        uid: 'cp7-target-7',
        email: 'cp7.target7@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'reports/rep-cp7-7'), {
        id: 'rep-cp7-7',
        reporterId: 'cp7-resident-creator',
        reporterName: 'Resident Creator',
        wasteCategory: 'Household Waste',
        location: '123 Park Street',
        description: 'Household trash',
        priority: 'Low',
        status: 'Assigned',
        assignedWorkerId: 'cp7-worker-7',
        assignedWorkerName: 'CP7 Worker 7',
        createdAt: '2026-10-22T10:00:00Z',
        updatedAt: '2026-10-22T10:00:00Z',
      });
    });

    const conflictedDb = testEnv.authenticatedContext('cp7-worker-7', { role: 'admin', worker: true }).firestore();
    // Contradictory claims fail closed; cannot perform worker operations
    await assertFails(
      updateDoc(doc(conflictedDb, 'reports/rep-cp7-7'), {
        status: 'In Progress',
        updatedAt: '2026-10-22T11:00:00Z',
      })
    );
    // Cannot perform admin operations
    await assertFails(getDoc(doc(conflictedDb, 'users/cp7-target-7')));
  });

  // Case 8: Resident profile with { admin: true }
  await test('CP7 Case 8: Resident profile with { admin: true } fails closed and cannot perform admin operations', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-res-8'), {
        uid: 'cp7-res-8',
        email: 'cp7.res8@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-target-8'), {
        uid: 'cp7-target-8',
        email: 'cp7.target8@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const resClaimDb = testEnv.authenticatedContext('cp7-res-8', { admin: true }).firestore();
    // Resident with admin claim cannot read another user's profile as admin
    await assertFails(getDoc(doc(resClaimDb, 'users/cp7-target-8')));
    // Resident cannot promote users or alter roles
    await assertFails(
      updateDoc(doc(resClaimDb, 'users/cp7-target-8'), {
        role: 'admin',
      })
    );
  });

  // Case 9: Admin profile with no recognized role claims
  await test('CP7 Case 9: Admin profile with no recognized role claims succeeds for admin operations', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/cp7-admin-9'), {
        uid: 'cp7-admin-9',
        email: 'cp7.admin9@test.com',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/cp7-target-9'), {
        uid: 'cp7-target-9',
        email: 'cp7.target9@test.com',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    // Standard token with no custom role claims (profile-only admin)
    const adminDb = testEnv.authenticatedContext('cp7-admin-9', { email: 'cp7.admin9@test.com' }).firestore();
    // Succeeds at reading another user's profile as admin
    await assertSucceeds(getDoc(doc(adminDb, 'users/cp7-target-9')));
  });


  // =========================================================================
  // Checkpoint 9: Positive Display Name Profile Update Test
  // =========================================================================

  await test('CP9: An authenticated user can update their own existing profile displayName successfully', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/user-edit-name'), {
        uid: 'user-edit-name',
        email: 'user.edit@test.com',
        displayName: 'Original Name',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const userDb = testEnv.authenticatedContext('user-edit-name', { role: 'resident' }).firestore();

    // Owner updates only displayName while preserving immutable identity fields
    await assertSucceeds(
      updateDoc(doc(userDb, 'users/user-edit-name'), {
        displayName: 'Updated Display Name',
      })
    );
  });


  // =========================================================================
  // Checkpoint 17: Admin Dynamic Worker Query Authorization Test
  // =========================================================================

  await test('CP17: Admin can query users collection for available workers, non-admins fail closed', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/admin-cp17'), {
        uid: 'admin-cp17',
        email: 'admin.cp17@test.com',
        displayName: 'Admin User',
        role: 'admin',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/worker-cp17-1'), {
        uid: 'worker-cp17-1',
        email: 'worker1@test.com',
        displayName: 'Field Worker 1',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/worker-cp17-2'), {
        uid: 'worker-cp17-2',
        email: 'worker2@test.com',
        displayName: 'Field Worker 2',
        role: 'worker',
        createdAt: '2026-10-22T10:00:00Z',
      });
      await setDoc(doc(db, 'users/resident-cp17'), {
        uid: 'resident-cp17',
        email: 'res@test.com',
        displayName: 'Resident User',
        role: 'resident',
        createdAt: '2026-10-22T10:00:00Z',
      });
    });

    const adminDb = testEnv.authenticatedContext('admin-cp17', { role: 'admin' }).firestore();
    const residentDb = testEnv.authenticatedContext('resident-cp17', { role: 'resident' }).firestore();
    const workerDb = testEnv.authenticatedContext('worker-cp17-1', { role: 'worker' }).firestore();

    // Admin can query workers from /users
    const adminWorkerQuery = query(collection(adminDb, 'users'), where('role', '==', 'worker'));
    const adminSnap = await assertSucceeds(getDocs(adminWorkerQuery));
    if (adminSnap.docs.length !== 2) {
      throw new Error(`Expected 2 worker documents for admin query, got ${adminSnap.docs.length}`);
    }

    // Resident querying workers collection fails closed
    const resWorkerQuery = query(collection(residentDb, 'users'), where('role', '==', 'worker'));
    await assertFails(getDocs(resWorkerQuery));

    // Worker querying workers collection fails closed
    const workerWorkerQuery = query(collection(workerDb, 'users'), where('role', '==', 'worker'));
    await assertFails(getDocs(workerWorkerQuery));
  });

  await testEnv.cleanup();
  console.log(`\nFinished: ${passed} passed, ${failed} failed.`);
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error('Test execution error:', err);
  process.exit(1);
});
