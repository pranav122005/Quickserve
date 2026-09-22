<div align="center">

<img src="docs/assets/quickserve-hero.gif" alt="QuickServe animated hero" width="100%">

# ⚡ QuickServe

### Smart Local Service Request & Dispatch Platform

<p>
  <strong>Book. Dispatch. Track. Complete.</strong><br>
  A realtime service-management platform connecting customers, service agents and administrators.
</p>

<p>
  <img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?style=for-the-badge&logo=flutter&logoColor=white">
  <img src="https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white">
  <img src="https://img.shields.io/badge/PostGIS-Spatial_Dispatch-336791?style=for-the-badge&logo=postgresql&logoColor=white">
  <img src="https://img.shields.io/badge/Riverpod-State_Management-6C63FF?style=for-the-badge">
  <img src="https://img.shields.io/badge/Tests-83%2F83-success?style=for-the-badge">
</p>

</div>

---

## ✦ Executive Summary

QuickServe is a full-stack service request platform for **AC servicing, plumbing, electrical work and cleaning**.

Customers create service requests. The backend performs spatial dispatch using **PostgreSQL + PostGIS**, eligible agents receive time-bound offers, accepted jobs become trackable active services, and administrators get an operational web dashboard.

<table>
<tr>
<td align="center"><b>👤 CUSTOMER</b><br><sub>Request • Track • Pay</sub></td>
<td align="center">→</td>
<td align="center"><b>🧠 DISPATCH</b><br><sub>Radius • Availability • Workload</sub></td>
<td align="center">→</td>
<td align="center"><b>🛠️ AGENT</b><br><sub>Accept • Start • Complete</sub></td>
<td align="center">→</td>
<td align="center"><b>🧑‍💼 ADMIN</b><br><sub>Monitor • Assign • Manage</sub></td>
</tr>
</table>

---

## ✦ Product Experience

<p align="center">
  <img src="docs/assets/customer-dashboard.png" width="30%" alt="Customer dashboard">
  <img src="docs/assets/create-request.png" width="30%" alt="Create request">
  <img src="docs/assets/agent-dashboard.png" width="30%" alt="Agent dashboard">
</p>

<p align="center">
  <sub>Customer request creation • Agent operations • Service lifecycle</sub>
</p>

<p align="center">
  <img src="docs/assets/admin-dashboard.png" width="90%" alt="Admin dashboard">
</p>

---

## ✦ Core Capabilities

<table>
<tr>
<td width="33%" valign="top">

### 👤 Customer

- Secure registration/login
- Service browsing
- Request creation
- Address & priority
- Preferred date/time
- Live request status
- Status history
- Assigned-agent visibility
- Active-job location
- Payment tracking
- Eligible cancellation

</td>
<td width="33%" valign="top">

### 🛠️ Agent

- Secure authentication
- Online/offline availability
- 10–20 km service radius
- Job offers
- 120-second offer window
- Accept/reject
- Start service
- Work notes
- Complete service
- Payment recording
- Active-job GPS

</td>
<td width="33%" valign="top">

### 🧑‍💼 Admin

- Operational dashboard
- Customers
- Agents
- Requests
- Manual assignment
- Status management
- Agent locations
- Payment records
- Request inspection
- Operational visibility

</td>
</tr>
</table>

---

## ✦ Smart Dispatch Engine

```text
                    SERVICE REQUEST
                           │
                           ▼
                 ┌───────────────────┐
                 │  ELIGIBLE AGENTS  │
                 └─────────┬─────────┘
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
          Radius       Available      Verified
             │             │             │
             └─────────────┼─────────────┘
                           ▼
                 Workload + Distance
                           │
                           ▼
                 FOR UPDATE SKIP LOCKED
                           │
                           ▼
                  120s Agent Offer
                     ┌─────┴─────┐
                     ▼           ▼
                  ACCEPT     REJECT/EXPIRE
                     │           │
                     ▼           ▼
                  ASSIGNED   NEXT CANDIDATE
```

### Dispatch ordering

1. Lowest active workload
2. Shortest eligible distance
3. Deterministic agent-ID tie-breaker

The reservation is performed server-side to prevent competing requests from claiming the same agent simultaneously.

---

## ✦ Request Lifecycle

<div align="center">

```text
PENDING  →  DISPATCHING  →  ASSIGNED  →  IN_PROGRESS  →  COMPLETED
    │
    └──────────────────────────────→  CANCELLED
```

</div>

---

## ✦ Architecture

```text
                         QUICK SERVE
                              │
             ┌────────────────┴────────────────┐
             │                                 │
      Flutter Android                    Flutter Web
       Customer/Agent                    Admin Portal
             │                                 │
             └────────────────┬────────────────┘
                              │
                     Riverpod + go_router
                              │
                              ▼
                       Supabase Client
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
     Supabase Auth        PostgreSQL           Realtime
                              │
                           PostGIS
                              │
                         RLS Policies
                              │
                      Dispatch Functions
                              │
                              ▼
                       Service Assignment
```

---

## ✦ Security Model

```text
PUBLIC SIGNUP
      │
      ▼
 CUSTOMER ROLE ONLY
      │
      ├──────────────► AGENT
      │                separately provisioned
      │
      └──────────────► ADMIN
                       separately provisioned
```

Protected resources use PostgreSQL RLS. Security-sensitive helper functions use `SECURITY DEFINER` with a controlled `search_path`.

Location visibility is deliberately restricted:

| Actor | Location visibility |
|---|---|
| Customer | Assigned agent during active service |
| Agent | Own current location |
| Administrator | Operational agent visibility |
| Other customers | ❌ |
| Anonymous users | ❌ |

---

## ✦ Technology

| Layer | Technology |
|---|---|
| Mobile | Flutter |
| Admin Web | Flutter Web |
| Language | Dart |
| State | Riverpod |
| Navigation | go_router |
| Backend | Supabase |
| Database | PostgreSQL |
| Spatial | PostGIS |
| Auth | Supabase Auth |
| Authorization | PostgreSQL RLS |
| Realtime | Supabase Realtime |
| Maps | flutter_map + OpenStreetMap |
| GPS | geolocator |
| Testing | Flutter test |
| Source Control | Git + GitHub |

---

## ✦ Project Structure

```text
quickserve/
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
│   └── assets/
├── .env.example
├── .gitignore
├── pubspec.yaml
└── README.md
```

---

## ✦ Quick Start

### 1. Clone

```bash
git clone https://github.com/pranav122005/Quickserve.git
cd Quickserve
```

### 2. Install

```bash
flutter pub get
```

### 3. Configure

Create `.env` from `.env.example`:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_public_anon_or_publishable_key
```

> Never place a `service_role` key, database password or other secret in the Flutter client.

### 4. Run

```bash
flutter run -d chrome
```

For Android:

```bash
flutter devices
flutter run
```

---

## ✦ Quality Gate

```bash
flutter analyze
flutter test
```

Current project baseline:

```text
✓ Flutter Analyze     0 issues
✓ Flutter Tests       83 / 83 passing
✓ RLS                 Enabled + Forced
✓ Spatial Dispatch    PostGIS
✓ Realtime            Enabled
```

---

## ✦ Recommended Screenshots

Put your screenshots in:

```text
docs/assets/
├── quickserve-hero.gif
├── quickserve-hero.png
├── customer-dashboard.png
├── create-request.png
├── agent-dashboard.png
├── agent-offer.png
└── admin-dashboard.png
```

The hero GIF is the animated visual at the top of this README.

---

## ✦ Roadmap

- [x] Authentication
- [x] Role-based access
- [x] Customer workflow
- [x] Agent workflow
- [x] Admin portal
- [x] PostGIS dispatch
- [x] Realtime updates
- [x] Active-job location
- [x] Payment recording
- [x] RLS hardening
- [x] Android release build
- [ ] Production deployment
- [ ] Push notifications
- [ ] Advanced analytics
- [ ] Extended CI/CD

---

<div align="center">

## ⚡ QuickServe

**Book. Dispatch. Track. Complete.**

<sub>Secure • Realtime • Location-Aware • Service Management</sub>

</div>
