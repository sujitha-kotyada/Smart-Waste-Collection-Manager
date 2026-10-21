const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');
const { doc, setDoc, updateDoc } = require('firebase/firestore');

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

  // 4. A worker cannot modify report description, priority, location, or reporter ID
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

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        description: 'Tampered description by worker',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        priority: 'Low',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        location: 'Fake location Sector 99',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        reporterId: 'another-user',
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 5. A worker cannot update a report assigned to another worker
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
        assignedWorkerId: 'worker-2', // Assigned to worker-2
        assignedWorkerName: 'Another Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
      await setDoc(doc(context.firestore(), 'users/worker-1'), {
        uid: 'worker-1',
        email: 'worker1@test.com',
        role: 'worker',
        createdAt: '2026-10-21T10:00:00Z',
      });
    });

    const worker1Context = testEnv.authenticatedContext('worker-1', { role: 'worker' });
    const worker1Db = worker1Context.firestore();

    // worker-1 attempts to advance worker-2's report to In Progress
    await assertFails(
      updateDoc(doc(worker1Db, 'reports/rep-1'), {
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 6. A resident cannot modify an already assigned report
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
        status: 'Assigned', // Already assigned by municipal dispatch
        assignedWorkerId: 'worker-1',
        assignedWorkerName: 'Rajesh Worker',
        createdAt: '2026-10-21T10:00:00Z',
        updatedAt: '2026-10-21T10:00:00Z',
      });
    });

    const resContext = testEnv.authenticatedContext('res-1', { role: 'resident' });
    const resDb = resContext.firestore();

    // Resident tries to alter details after dispatch
    await assertFails(
      updateDoc(doc(resDb, 'reports/rep-1'), {
        description: 'Resident modifying already assigned incident',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    // Resident tries to self-complete or inject resolution notes
    await assertFails(
      updateDoc(doc(resDb, 'reports/rep-1'), {
        resolutionNotes: 'Resident injected note',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 7. Assigned -> In Progress must not introduce completion notes
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

    // Introducing notes on In Progress should FAIL
    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'In Progress',
        resolutionNotes: 'Premature note',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );

    // Without notes succeeds
    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'In Progress',
        updatedAt: '2026-10-21T11:00:00Z',
      })
    );
  });

  // 8. In Progress -> Completed requires non-empty resolution notes
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

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'Completed',
        updatedAt: '2026-10-21T12:00:00Z',
      })
    );

    await assertFails(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'Completed',
        resolutionNotes: '',
        updatedAt: '2026-10-21T12:00:00Z',
      })
    );

    await assertSucceeds(
      updateDoc(doc(workerDb, 'reports/rep-1'), {
        status: 'Completed',
        resolutionNotes: 'Properly collected and deposited.',
        updatedAt: '2026-10-21T12:00:00Z',
      })
    );
  });

  // 9. Workers cannot tamper with resolution notes after completion
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
        resolutionNotes: 'Original immutable completion note',
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

  await testEnv.cleanup();
  console.log(`\nFinished: ${passed} passed, ${failed} failed.`);
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error('Test execution error:', err);
  process.exit(1);
});
