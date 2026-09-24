<div align="center">

# ⚡ QUICKSERVE

### Smart Local Service Request & Dispatch Platform

**Book. Dispatch. Track. Complete.**

A full-stack service management platform connecting customers, service agents, and administrators through a secure, real-time workflow.

<p>
<img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?style=for-the-badge&logo=flutter&logoColor=white">
<img src="https://img.shields.io/badge/Dart-3.13.4-0175C2?style=for-the-badge&logo=dart&logoColor=white">
<img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white">
<img src="https://img.shields.io/badge/PostgreSQL-Database-336791?style=for-the-badge&logo=postgresql&logoColor=white">
</p>

<p>
<img src="https://img.shields.io/badge/PostGIS-Spatial_Dispatch-336791?style=for-the-badge&logo=postgresql&logoColor=white">
<img src="https://img.shields.io/badge/Riverpod-State_Management-6C63FF?style=for-the-badge">
<img src="https://img.shields.io/badge/Tests-83%2F83-success?style=for-the-badge">
<img src="https://img.shields.io/badge/Platform-Android_%7C_Web-informational?style=for-the-badge">
</p>

<p>
<a href="#-overview">Overview</a> •
<a href="#-features">Features</a> •
<a href="#-how-it-works">How It Works</a> •
<a href="#-architecture">Architecture</a> •
<a href="#-security">Security</a> •
<a href="#-setup">Setup</a> •
<a href="#-testing">Testing</a>
</p>

</div>

---

## 🖼️ Product Preview

<p align="center">
  <img src="docs/assets/quickserve-preview.png" alt="QuickServe Preview" width="900">
</p>

<p align="center"><sub>Customer • Agent • Administrator workflows</sub></p>

---

## 🚀 Overview

**QuickServe** is a full-stack **Service Request Management Platform** designed for local services such as:

- ❄️ AC servicing
- 🔧 Plumbing
- ⚡ Electrical work
- 🧹 Cleaning

The platform provides three connected experiences:

| Role | Main Responsibility |
|---|---|
| 👤 **Customer** | Create, track and manage service requests |
| 🛠️ **Service Agent** | Receive offers, perform assigned jobs and update progress |
| 🧑‍💼 **Administrator** | Monitor operations, assign agents and manage requests |

QuickServe uses **Flutter** for Android and the web administration portal, with **Supabase, PostgreSQL, PostGIS, RLS and Realtime** providing the backend foundation.

---

## ✨ Why QuickServe?

QuickServe is built around one simple operational flow:

```text
Customer Request
       ↓
Backend Dispatch
       ↓
Agent Offer
       ↓
Agent Accepts
       ↓
Service Starts
       ↓
Service Completed
       ↓
Payment Recorded
       ↓
Admin Verification
```

The important part is that **authorization and dispatch decisions are enforced by the backend**, rather than relying only on what the client application displays.

---

# 📋 Table of Contents

- [Overview](#-overview)
- [Why QuickServe](#-why-quickserve)
- [Features](#-features)
- [How It Works](#-how-it-works)
- [Request Lifecycle](#-request-lifecycle)
- [Smart Dispatch](#-smart-dispatch)
- [Location & Privacy](#-location--privacy)
- [Architecture](#-architecture)
- [Technology Stack](#-technology-stack)
- [Database](#-database)
- [Security](#-security)
- [Application Flows](#-application-flows)
- [Project Structure](#-project-structure)
- [Setup](#-setup)
- [Testing](#-testing)
- [Demo Accounts](#-demo-accounts)
- [Release & Hosting](#-release--hosting)
- [Documentation](#-documentation)
- [Implementation Status](#-implementation-status)
- [Future Improvements](#-future-improvements)
- [License](#-license)

---

# ✨ Features

<table>
<tr>
<td width="33%" valign="top">

### 👤 Customer

- Registration & login
- Browse services
- Create service requests
- Preferred date & time
- Address & priority
- Unique request ID
- Request tracking
- Status history
- Eligible cancellation
- Assigned-agent visibility
- Active agent location
- Payment tracking
- Profile & logout

</td>
<td width="33%" valign="top">

### 🛠️ Service Agent

- Secure login
- Agent profile
- Online / offline status
- Configurable 10–20 km service radius
- Job offers
- 120-second offer window
- Accept / reject
- Start service
- Add work notes
- Complete service
- Record payment
- Active-job location

</td>
<td width="33%" valign="top">

### 🧑‍💼 Administrator

- Responsive web dashboard
- Request management
- Customer management
- Agent management
- Manual agent assignment
- Request status management
- Agent operational tracking
- Payment records
- Activity / status history

</td>
</tr>
</table>

---

# 🔄 How It Works

## 1. Customer Creates a Request

The customer selects a service and provides:

```text
Service Type
Description
Preferred Date / Time
Service Address
Priority
```

A unique request identifier is generated, for example:

```text
REQ-2026-000123
```

## 2. Backend Finds Eligible Agents

The backend evaluates agents using:

- Current location
- Service radius
- Availability
- Verification status
- Service capability
- Current workload

## 3. Agent Receives an Offer

The selected agent receives a real-time offer with a **120-second acceptance window**.

```text
        REQUEST
           │
           ▼
    Eligible Agents
           │
           ▼
      Best Candidate
           │
           ▼
     120s Offer
       /       \
   ACCEPT     REJECT/EXPIRE
      │             │
      ▼             ▼
   ASSIGNED     Next Candidate
```

## 4. Service Is Performed

After acceptance:

```text
ASSIGNED
   ↓
IN_PROGRESS
   ↓
COMPLETED
```

The customer can see the assigned agent's current location during the active authorized service state.

---

# 🔁 Request Lifecycle

```text
┌───────────┐
│  PENDING  │
└─────┬─────┘
      ↓
┌──────────────┐
│ DISPATCHING  │
└─────┬────────┘
      ↓
┌────────────┐
│  ASSIGNED  │
└─────┬──────┘
      ↓
┌──────────────┐
│ IN_PROGRESS  │
└─────┬────────┘
      ↓
┌────────────┐
│ COMPLETED  │
└────────────┘

Eligible requests
      │
      └──────────► CANCELLED
```

### Assignment States

```text
OFFERED → ACCEPTED → COMPLETED
    │
    ├──────► REJECTED
    └──────► CANCELLED
```

---

# 🧠 Smart Dispatch

QuickServe performs dispatch on the **backend using PostgreSQL + PostGIS**.

### Candidate Eligibility

An agent must satisfy the applicable conditions:

| Condition | Purpose |
|---|---|
| 📍 Within radius | Agent is geographically reachable |
| 🟢 Available | Agent can receive work |
| ✅ Verified | Agent is authorized to provide service |
| 🛠️ Suitable | Agent can handle the requested service |
| 📡 Current location | Spatial matching can be performed |

### Candidate Ordering

Eligible agents are ordered deterministically by:

```text
1. Lower active workload
2. Shorter distance
3. Agent ID as tie-breaker
```

### Concurrency Safety

The dispatcher uses PostgreSQL row locking with:

```text
FOR UPDATE SKIP LOCKED
```

This helps prevent two concurrent dispatch attempts from reserving the same offer slot incorrectly.

---

# 📍 Location & Privacy

QuickServe intentionally limits location visibility.

| User | Location Access |
|---|---|
| 👤 Customer | Assigned agent during an active authorized service |
| 🛠️ Agent | Own current location |
| 🧑‍💼 Administrator | Operational agent visibility |
| Other customers | ❌ No access |
| Anonymous users | ❌ No access |

### Location Design

- Foreground GPS is used for active service workflows.
- Current agent location is stored for operational tracking.
- Unlimited historical GPS tracking is not used.
- Production workflows do not rely on fake GPS coordinates.
- Customer access is state-dependent and ends when the relevant service relationship ends.

---

# 🏗️ Architecture

```text
                         QUICK SERVE
                              │
             ┌────────────────┴────────────────┐
             │                                 │
      Flutter Android                    Flutter Web
       Customer / Agent                  Admin Portal
             │                                 │
             └────────────────┬────────────────┘
                              │
                    Riverpod + go_router
                              │
                              ▼
                       Supabase Client
                              │
             ┌────────────────┼────────────────┐
             │                │                │
         Supabase Auth       RLS          Realtime
             │                │                │
             └────────────────┼────────────────┘
                              ▼
                     PostgreSQL Database
                              │
                         ┌────┴────┐
                         │ PostGIS │
                         └────┬────┘
                              │
                       Dispatch RPCs
                              │
                              ▼
                       Agent Assignment
```

### Architecture Principles

1. **Backend-authoritative security** — the client cannot grant itself privileges.
2. **Database-enforced authorization** — RLS protects data at the PostgreSQL layer.
3. **Spatial dispatch** — PostGIS handles distance-based agent matching.
4. **Realtime operations** — Supabase Realtime keeps request/offer state synchronized.
5. **Shared backend** — Android and Web use the same backend rules and data model.

---

# 🧰 Technology Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter |
| Web Admin | Flutter Web |
| Language | Dart |
| State Management | Riverpod |
| Navigation | go_router |
| Backend | Supabase |
| Authentication | Supabase Auth |
| Database | PostgreSQL |
| Spatial Database | PostGIS |
| Authorization | PostgreSQL RLS |
| Realtime | Supabase Realtime |
| Maps | flutter_map + OpenStreetMap |
| GPS | geolocator |
| Testing | Flutter Test |
| Source Control | Git + GitHub |
| Hosting Configuration | Firebase Hosting |

---

# 🗄️ Database

The main operational data is organized around users, requests, assignments, agents, locations, payments and status history.

```text
profiles
   │
   ├──────────────┐
   │              │
   ▼              ▼
service_requests  agent_profiles
   │
   ├───────────────┐
   │               │
   ▼               ▼
assignments     status_history
   │
   ▼
agent_locations

service_requests
       │
       ▼
    payments
```

### Important Data Areas

| Data | Purpose |
|---|---|
| `profiles` | User identity and authoritative application role |
| `service_requests` | Customer service requests |
| `service_assignments` | Agent offers and assignments |
| `agent_profiles` | Agent operational profile |
| `agent_locations` | Current agent location |
| `request_status_history` | Request lifecycle history |
| `payments` | Payment records for completed service workflows |

PostGIS spatial indexes and database functions support location-aware dispatch.

---

# 🔐 Security

QuickServe follows a **backend-enforced RBAC + RLS model**.

```text
User
 │
 ▼
Supabase Auth
 │
 ▼
Authenticated Session
 │
 ▼
Authoritative Profile Role
 │
 ▼
PostgreSQL RLS
 │
 ├── Customer Data
 ├── Agent Data
 └── Admin Operations
```

### Role Provisioning

```text
Public Registration
        │
        ▼
     CUSTOMER
        │
        ├───────────────┐
        │               │
        ▼               ▼
     AGENT            ADMIN
  provisioned       provisioned
   separately        separately
```

A client-side role switcher is not used to grant privileged access.

### Database Security Controls

- Supabase Authentication
- PostgreSQL Row Level Security
- Forced RLS on protected tables
- SECURITY DEFINER helper functions where required
- Controlled `search_path`
- Authenticated-only database access
- Server-side dispatch authorization
- Restricted agent-location visibility
- No service-role key in the Flutter client
- Secrets excluded from Git
- Sensitive values are not written to logs

### Protected Resources

```text
profiles
service_requests
service_assignments
agent_profiles
agent_locations
request_status_history
payments
```

---

# 📝 Logging & Error Handling

The system records meaningful operational events while avoiding sensitive information.

Examples include:

```text
LOGIN_SUCCESS
REQUEST_CREATED
REQUEST_ASSIGNED
REQUEST_UPDATED
AUTHORIZATION_FAILED
DATABASE_ERROR
```

Sensitive information such as passwords, authentication tokens, API keys and database secrets is not intended for application logs.

Application flows also handle:

- Invalid input
- Unauthorized actions
- Network failures
- Backend/database errors
- Session expiry
- Realtime interruptions

---

# 📱 Application Flows

## Customer

```text
Login / Register
       ↓
     Home
       ├── Services
       ├── Create Request
       └── My Requests
                ↓
          Request Details
                ↓
       Assignment / Location
                ↓
          Payment Record
```

## Agent

```text
Login
  ↓
Agent Home
  ├── Availability
  ├── Service Radius
  ├── Offers
  └── Active Job
          ↓
      Start Service
          ↓
       Complete
          ↓
    Record Payment
```

## Administrator

```text
Admin Login
     ↓
 Dashboard
     ├── Requests
     ├── Customers
     ├── Agents
     └── Payments
            ↓
      Request Details
       ├── Assign Agent
       ├── Update Status
       └── Track Agent
```

---

# 📂 Project Structure

```text
Quickserve/
├── android/
├── ios/
├── web/
├── lib/
│   ├── core/
│   ├── data/
│   ├── features/
│   │   ├── auth/
│   │   ├── customer/
│   │   ├── agent/
│   │   └── admin/
│   └── main.dart
├── supabase/
│   └── migrations/
├── test/
├── docs/
│   ├── assets/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
├── .env.example
├── .gitignore
├── firebase.json
├── pubspec.yaml
└── README.md
```

---

# ⚙️ Setup

## 1. Prerequisites

Install:

- Flutter
- Dart
- Android Studio / Android SDK
- Git
- A Supabase project

Verify Flutter:

```bash
flutter --version
flutter doctor
```

## 2. Clone Repository

```bash
git clone https://github.com/pranav122005/Quickserve.git
cd Quickserve
```

## 3. Install Dependencies

```bash
flutter pub get
```

## 4. Configure Environment

Create `.env` from `.env.example`:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_public_anon_or_publishable_key
```

> **Important:** Never place a `service_role` key, database password, or other secret inside the Flutter client.

## 5. Configure Database

Apply the project's Supabase migrations and ensure the required:

- PostgreSQL database
- PostGIS extension
- Authentication
- RLS policies
- Dispatch functions
- Indexes
- Realtime configuration

are available.

## 6. Run Web

```bash
flutter run -d chrome
```

## 7. Run Android

```bash
flutter devices
flutter run
```

---

# 🧪 Testing

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

### Current Baseline

```text
Flutter Analyze : 0 issues
Flutter Tests   : 83 / 83 passing
```

### End-to-End Validation Flow

```text
Customer Registration
        ↓
Customer Login
        ↓
Create Request
        ↓
Backend Dispatch
        ↓
Agent Offer
        ↓
Agent Accept
        ↓
Agent Start
        ↓
Agent Complete
        ↓
Payment Record
        ↓
Admin Verification
```

The project also includes authorization, dispatch-concurrency, location-privacy, authentication/session, network/realtime and regression coverage.

---

# 👥 Demo Accounts

> These accounts are intended for demonstration/testing. Replace them before public production use.

| Role | Email | Password |
|---|---|---|
| Customer | `customer@quickserve.com` | `QuickServe@123` |
| Agent | `agent@quickserve.com` | `QuickServe@123` |
| Admin | `admin@quickserve.com` | `QuickServe@123` |

---

# 📦 Release & Hosting

### Android

A release APK has been generated and validated as part of the project release process.

```text
Android Release APK
~57.9 MB
```

### Web

The project includes a Flutter Web release build and Firebase Hosting configuration.

Typical build:

```bash
flutter build web --release
```

Typical deployment:

```bash
firebase deploy --only hosting
```

> A public production URL is not listed here because the live deployment must be verified from the current hosting environment rather than assumed from configuration.

---

# 📚 Documentation

Detailed project documentation is available in:

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System architecture, components, data flow and design decisions |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Authentication, RBAC, RLS, authorization and location privacy |

---

# 🤝 Git Workflow

```text
Feature
  ↓
Feature Branch
  ↓
Implementation
  ↓
flutter analyze
  ↓
flutter test
  ↓
Manual E2E
  ↓
Pull Request
  ↓
Review
  ↓
main
```

Example commit style:

```text
feat: add agent offer workflow
fix: resolve RLS recursion
fix: repair agent availability
test: add authorization coverage
docs: update deployment guide
```

---

# 📸 Visual Assets

Recommended assets are stored under:

```text
docs/assets/
```

Example:

```text
docs/assets/
├── quickserve-hero.png
├── quickserve-logo.jpg
├── quickserve-preview.png
├── customer-dashboard.png
├── create-request.png
├── agent-dashboard.png
├── agent-offer.png
└── admin-dashboard.png
```

For a GitHub README, screenshots can be displayed using standard Markdown or HTML image blocks.

---

# 📌 Assignment Alignment

QuickServe covers the major SWASIQ technical assignment areas:

| Assignment Area | QuickServe Implementation |
|---|---|
| Flutter application | Flutter Android |
| Web administration | Flutter Web |
| Backend | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth |
| RBAC | Backend role + RLS |
| Customer workflow | Request creation & tracking |
| Agent workflow | Offer, accept, start, complete |
| Admin workflow | Dashboard, assignment & management |
| Spatial dispatch | PostGIS |
| Realtime | Supabase Realtime |
| Audit/history | Request status history + operational events |
| Error handling | Client/backend error handling |
| Testing | Automated + E2E validation |
| Documentation | README + architecture + security docs |

---

# 📄 License

This project was developed as a technical assignment for **SWASIQ**.

© 2026 QuickServe. All rights reserved.

---

<div align="center">

# ⚡ QuickServe

### Secure • Realtime • Location-Aware • Service Management

**Customer • Agent • Administrator**

</div>
