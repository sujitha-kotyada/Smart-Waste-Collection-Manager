# Database Schema Specification — Cloud Firestore

## 1. Overview
EcoCollect uses Google Cloud Firestore, a scalable NoSQL document database. Data is organized into two primary root-level collections:
1. `users`: Stores user profile data and RBAC authority levels.
2. `reports`: Stores municipal waste incident reports, dispatch states, field notes, and audit timestamps.

---

## 2. Collections Schema

### A. `users` Collection
**Path:** `/users/{userId}`
**Primary Key:** Firebase Auth `uid`

| Field | Type | Description | Constraints / Validation |
| :--- | :--- | :--- | :--- |
| `uid` | `string` | Unique identifier matching Firebase Auth | Required, immutable |
| `email` | `string` | Registered email address | Required, valid email format |
| `displayName` | `string` | Citizen or Worker name | Required, min length 2 |
| `role` | `string` | Access tier (`resident`, `worker`, `admin`) | Required. Defaults to `resident` on client registration. Privilege changes restricted to administrators. |
| `createdAt` | `string` / `timestamp` | Profile registration date (ISO-8601) | Required, set on account creation |

---

### B. `reports` Collection
**Path:** `/reports/{reportId}`
**Primary Key:** Unique generated alphanumeric string (e.g. `REP-7281902`)

| Field | Type | Description | Constraints / Lifecycle |
| :--- | :--- | :--- | :--- |
| `id` | `string` | Unique report identifier | Required |
| `reporterId` | `string` | `uid` of the submitting resident | Required, matched to `request.auth.uid` |
| `reporterName` | `string` | Name of submitting resident | Required |
| `wasteCategory` | `string` | Category (`Household Waste`, `Plastic Waste`, `Organic Waste`, `Paper & Cardboard`, `E-Waste`, `Hazardous Waste`, `Construction Debris`, `Overflowing Bin`, `Other`) | Required |
| `location` | `string` | Physical location, sector, or landmark | Required, min length 3 |
| `description` | `string` | Incident details, volume estimate | Optional |
| `priority` | `string` | Urgency rating (`Low`, `Medium`, `High`, `Urgent`) | Defaults to `Medium` |
| `status` | `string` | Lifecycle state (`Pending`, `Assigned`, `In Progress`, `Completed`, `Rejected`) | Initial: `Pending`. Subject to RBAC transition enforcement. |
| `assignedWorkerId` | `string`? | `uid` of assigned field sanitation worker | Nullable; populated by administrator |
| `assignedWorkerName`| `string`? | Name & vehicle crew of assigned worker | Nullable; populated on assignment |
| `resolutionNotes` | `string`? | Verification & segregation log by worker | Populated on status transition to `Completed` |
| `createdAt` | `string` / `timestamp` | Submission timestamp | Set on document creation |
| `updatedAt` | `string` / `timestamp` | Last status or detail modification | Updated on each state transition |

---

## 3. Indexes & Query Performance
Configured in `firestore.indexes.json` for rapid dashboard filtering:

1. **User Reports Query:**
   - Collection: `reports`
   - Fields: `reporterId` (ASC), `createdAt` (DESC)
   - Purpose: Enables instant listing of personal reports ordered by newest first.

2. **Worker Queue Query:**
   - Collection: `reports`
   - Fields: `assignedWorkerId` (ASC), `status` (ASC)
   - Purpose: Filters active tasks assigned to specific field sanitation personnel.

3. **Municipal Status Stream:**
   - Collection: `reports`
   - Fields: `status` (ASC), `createdAt` (DESC)
   - Purpose: Allows city administrators to stream pending emergency queues efficiently.
