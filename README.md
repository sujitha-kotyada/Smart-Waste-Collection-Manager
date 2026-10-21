# EcoCollect — Smart Waste Collection Manager
### Sustainable Municipal Waste Management & Citizen Incident Reporting System
**Target Evaluation:** College Capstone / Final Year Engineering Demonstration
**SDG Alignment:** UN Sustainable Development Goal 11 (*Sustainable Cities and Communities*) & Goal 12 (*Responsible Consumption and Production*)

---

## 1. Project Overview & Problem Statement
Rapid urbanization and fragmented municipal collection infrastructure frequently cause overflowing public garbage bins, hazardous domestic littering, and unsegregated landfill dumping. Citizens lack transparent reporting channels, while field sanitation workers have no real-time route assignment dispatch system.

**EcoCollect** resolves this urban challenge through a responsive Flutter Web application connected to Firebase Authentication and Cloud Firestore, providing role-based workflows for:
1. **Community Residents:** Report waste incidents with categories, geographic locations, urgency ratings, and descriptions; track cleanup status in real time; access waste segregation education and transparent carbon-offset estimations.
2. **Municipal Field Sanitation Workers:** Access active assigned routes, review task severity, update operational statuses (`Assigned` $\rightarrow$ `In Progress` $\rightarrow$ `Completed`), log field resolution notes, and track daily cleared volumes.
3. **Municipal Administrators / Supervisors:** Real-time city-wide operations console, KPI monitoring (resolution percentage, open emergency queues), field personnel dispatching, and status overrides.

---

## 2. Technology Stack
- **Framework:** Flutter 3.41.4 (Channel stable)
- **Language:** Dart 3.11.1 (Sound Null Safety)
- **Primary Deployment Platform:** Web (HTML5 CanvasKit / Wasm, responsive desktop/tablet/mobile layouts)
- **Design System:** Material Design 3 with curated Eco-Emerald palette and custom UI tokens
- **Cloud Infrastructure:**
  - **Firebase Core:** `^5.0.0`
  - **Firebase Authentication:** `^7.0.0` (Email/Password registration, login, and password resets)
  - **Cloud Firestore:** `^7.0.0` (Persistent NoSQL database, structured queries, compound indexes)
  - **Firebase Security Rules:** Role-Based Access Control (RBAC) preventing unauthorized privilege escalation

---

## 3. System Architecture & User Roles

### User Roles & Permissions
| Role | Read Permissions | Create Permissions | Update Permissions | Delete Permissions |
| :--- | :--- | :--- | :--- | :--- |
| **Resident** | Own submitted reports, Eco tips, User profile | Waste reports (default status: `Pending`, unassigned) | Can edit report details only while status is `Pending` | None |
| **Worker** | Assigned tasks (`assignedWorkerId == uid`), Eco tips | None | Status transitions: `Assigned` $\rightarrow$ `In Progress` $\rightarrow$ `Completed` + resolution notes | None |
| **Admin** | City-wide municipal reports, worker assignments, system stats | None (supervises queue) | Worker assignment, re-assignment, any status override | Administrative archive |

### Evaluator Quick-Access Personas
To facilitate academic review without requiring multiple email accounts to be created in Firebase Console, the system includes instant role-switching personas in both the Login and Profile screens:
- **Resident:** `Sujitha (Resident)` (`sujitha.resident@ecocollect.org`)
- **Sanitation Worker:** `Rajesh Kumar (Electric Truck #04)` (`rajesh.field@ecocollect.org`)
- **Administrator:** `Admin Supervisor` (`admin.manager@ecocollect.org`)

---

## 4. Environmental & SDG Impact (Defensible Metrics)
The application adheres strictly to verifiable, documented calculation benchmarks:
- **UN SDG 11 (Target 11.6):** Reduce urban environmental impact via municipal waste management.
- **UN SDG 12 (Target 12.5):** Substantially reduce waste generation through segregation and diversion.
- **Defensible Benchmark Calculations:**
  - Diverted Waste: $5.2\text{ kg}$ average municipal batch weight per *verified completed* cleanup.
  - Avoided Greenhouse Gases: $0.72\text{ kg CO}_2\text{e}$ avoided per kg diverted from open dumping (EPA Waste Reduction Model benchmark).
  - Rescued Plastics: ~30 single-use containers diverted per completed plastic collection.
  - *Uncollected/pending reports do not claim diverted mass until confirmed cleaned by field crew.*

---

## 5. Local Setup & Execution Guide

### Prerequisites
- Flutter SDK (v3.41.4 or compatible)
- Google Chrome or Microsoft Edge browser
- Firebase CLI (optional, for remote security rules deployment)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the Application in Chrome
```bash
flutter run -d chrome
```

### 3. Run Analysis & Automated Test Suite
```bash
# Code format check
dart format --output=none --set-exit-if-changed .

# Static code analysis
flutter analyze

# Automated test suite (17 Unit & Widget tests)
flutter test
```

### 4. Build Production Web Release Bundle
```bash
flutter build web --release
```
The optimized web distribution bundle is generated in `build/web/`.

---

## 6. Firebase Configuration & Deployment

### Configured Firebase Project
- **Project ID:** `smart-waste-collection-manager`
- **Project Number:** `739741914803`
- **Web App ID:** `1:739741914803:web:6c9487acb2038cb27bc2c6`
- **Options File:** `lib/firebase_options.dart`

### Firestore Security Rules Deployment
The project includes production-ready `firestore.rules` and `firestore.indexes.json`. To deploy:
```bash
firebase deploy --only firestore:rules,firestore:indexes
```

### Note on Cloud Operations vs Evaluator Demo Sandbox
EcoCollect separates live cloud operations from local demonstration:
1. **Live Cloud Sync (`FirestoreWasteReportRepository`):** Active for real Firebase-authenticated accounts. Reads and writes interact directly with Cloud Firestore. Failures (e.g., locked rules, permission errors, network drops) are **never silently caught or masked**; errors are surfaced directly to the user interface.
2. **Simulated Demo Sandbox (`LocalWasteReportRepository`):** An explicitly chosen, visibly labeled in-memory evaluation sandbox with evaluator fast-access persona buttons. It guarantees full demonstration of Resident, Worker, and Admin roles without mutating live cloud data.

---

## 7. Directory Structure
```
lib/
├── firebase_options.dart               # Generated Firebase configuration
├── main.dart                           # Application entry point & role shell
├── core/
│   ├── constants/app_constants.dart    # Categories, statuses, RBAC transitions
│   ├── theme/app_theme.dart            # Material 3 eco palette, typography
│   └── utils/
│       ├── date_formatter.dart         # Relative and standard date formatting
│       └── impact_calculator.dart      # Defensible SDG 11 & 12 formulas
├── models/
│   ├── app_user.dart                   # User identity, roles & permissions
│   └── waste_report.dart               # Waste report data model & validation
├── repositories/
│   └── waste_report_repository.dart    # Cloud Firestore & isolated Demo repositories
├── services/
│   └── auth_service.dart               # Firebase Auth wrapper & demo personas
└── features/
    ├── admin/admin_dashboard.dart      # Municipal operations console & dispatch
    ├── auth/
    │   ├── login_screen.dart           # Authentication & demo quick login
    │   └── register_screen.dart        # Resident registration form
    ├── eco_tips/eco_tips_screen.dart   # Waste segregation & SDG targets guide
    ├── profile/profile_screen.dart     # Role indicators & persona switcher
    ├── resident/
    │   ├── report_detail_sheet.dart    # Tracking timeline & resolution log
    │   ├── report_waste_dialog.dart    # Form validation & incident submission
    │   ├── resident_dashboard.dart     # Greeting, 4 stats cards, SDG summary
    │   └── resident_reports_screen.dart# Search, category filter, sorting
    └── worker/worker_dashboard.dart    # Route dispatch, status progress, notes
```

---

## 8. Documentation Index
- [System Architecture](docs/ARCHITECTURE.md)
- [Database Schema & Data Flow](docs/DATABASE_SCHEMA.md)
- [Security & Access Control (RBAC)](docs/SECURITY.md)
- [Testing Verification & Coverage](docs/TESTING.md)
- [Complete Academic Project Report](docs/PROJECT_REPORT.md)
