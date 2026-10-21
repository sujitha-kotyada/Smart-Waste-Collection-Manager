# Security & Access Control Architecture (RBAC)

## 1. Authentication & Identity Management
EcoCollect integrates with Firebase Authentication for identity verification:
- Password policies require at least 6 characters.
- Secure email-based password recovery handled via Firebase Auth.
- Session tokens are managed securely in local browser storage without exposing plaintext credentials.

---

## 2. Role-Based Access Control (RBAC)

### Threat Model & Defense Against Privilege Escalation
In naive applications, a registration form accepts a client-provided `role` field, allowing malicious actors to register directly as an `admin`.

**EcoCollect enforces security at multiple levels:**
1. **Client-Side Registration Guard:** The registration workflow (`register_screen.dart`) forces `role == 'resident'`.
2. **Firestore Security Rules Enforcement (`firestore.rules`):**
   - When a user profile is created at `/users/{userId}`, security rules mandate:
     ```javascript
     allow create: if isOwner(userId) && request.resource.data.role == 'resident';
     ```
   - When a user profile is updated, rules prevent modifying the `role` field:
     ```javascript
     allow update: if isOwner(userId) && request.resource.data.role == resource.data.role;
     ```
   - Modifying a user's role requires administrator authorization:
     ```javascript
     allow update: if isAdmin();
     ```

### First-Admin Provisioning Dilemma & Resolution
In a secure zero-trust environment, public self-elevation or hardcoded backdoor admin routes introduce severe attack vectors. EcoCollect resolves the first-admin provisioning dilemma through a **trusted out-of-band administrative procedure**:
1. **Initial Registration:** The intended administrator registers normally through the application UI or Firebase Authentication Console. By default, public registration creates a standard `resident` document.
2. **Elevated Privilege Grant:** The project owner elevates the user via:
   - **Method A (Firebase Console):** Navigate to **Firestore Database** $\rightarrow$ `users` collection $\rightarrow$ select user document `{userId}` $\rightarrow$ update `role` string from `"resident"` to `"admin"`.
   - **Method B (Firebase Admin SDK / Custom Claims):** Set tamper-proof custom claims using the Admin SDK:
     ```javascript
     admin.auth().setCustomUserClaims(userId, { admin: true, role: 'admin' });
     ```
3. **Subsequent Admin Management:** Once the primary administrator is provisioned, further worker assignments and administrator updates can be performed by authorized administrators according to `firestore.rules`.

---

## 3. Storage & Persistence Security Model

### Strict Cloud Mode vs. Isolated Demo Sandbox
- **Live Cloud Sync (`FirestoreWasteReportRepository`):**
  - When users sign in with real Firebase Authentication credentials, all reads and writes interact directly with Cloud Firestore.
  - Failures (e.g. `permission-denied`, network drops) are **never silently caught or masked with in-memory fallbacks**. Real errors are surfaced to the UI and logged honestly.
  - Success confirmations are only shown when the Cloud Firestore write has committed.
- **Simulated Demo Sandbox (`LocalWasteReportRepository`):**
  - Evaluator fast-access buttons and offline testing explicitly operate in an in-memory sandbox.
  - The UI displays a persistent top notification banner: `SIMULATED DEMO SANDBOX — In-memory evaluation only. Cloud Firestore writes are disabled.`
  - The local persona switcher is strictly restricted to demo mode and is mathematically incapable of escalating privileges in Cloud Firestore.

---

## 4. Report Lifecycle State Machine Security

Firestore security rules (`firestore.rules`) strictly govern write permissions on `/reports/{reportId}`:

1. **Creation:**
   - Authenticated user can only create a report with `reporterId == request.auth.uid`.
   - The initial status must be strictly `'Pending'`.
   - Client cannot set an `assignedWorkerId` or `resolutionNotes` upon creation.
   - Waste category, priority, and location are validated for allowable types and minimum length.

2. **Resident Updates:**
   - Residents can only update their own reports while `status == 'Pending'`.
   - Incident facts (`reporterId`, `createdAt`) are strictly immutable.
   - Residents cannot mark reports as `Completed`, `Assigned`, or inject resolution notes.

3. **Field Worker Updates:**
   - Workers can only update reports assigned to them (`assignedWorkerId == request.auth.uid`).
   - Incident facts (`reporterId`, `createdAt`, `wasteCategory`, `location`) are strictly **immutable**.
   - Workers cannot modify original report timestamps or resident descriptions.
   - Workers can only advance statuses through valid operational states:
     - `Assigned` $\rightarrow$ `In Progress`
     - `In Progress` $\rightarrow$ `Completed` (requires non-empty `resolutionNotes`).

4. **Administrator Updates:**
   - Administrators possess full operational authority to assign field crews, reassign routes, and override statuses.

---

## 5. Secrets Management & Code Hygiene
- **No committed service-account JSON files or private API keys.**
- Standard public web configurations in `lib/firebase_options.dart` are restricted through Firebase Security Rules and domain whitelisting.
- `.gitignore` strictly ignores:
  - `*.env`
  - `*.service_account.json`
  - `*credentials*.json`
  - `*.pem`, `*.key`
  - Debug logs (`firebase-debug.log`, `firestore-debug.log`)
  - Local build artifacts (`build/`, `.dart_tool/`)

---

## 6. Console Configuration Checklist
To activate the live cloud backend in Firebase Console:
1. Navigate to **Firebase Console** $\rightarrow$ `smart-waste-collection-manager`.
2. Under **Build $\rightarrow$ Authentication $\rightarrow$ Sign-in method**:
   - Enable **Email/Password** provider.
3. Under **Build $\rightarrow$ Firestore Database**:
   - The database instance exists (`projects/smart-waste-collection-manager/databases/(default)` in `FIRESTORE_NATIVE` mode).
   - Deployed default rules start in locked mode (`allow read, write: if false;`).
4. Deploy the authored, hardened security rules and composite indexes:
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```
5. Provision the first municipal administrator account via the trusted out-of-band procedure documented in Section 2.
