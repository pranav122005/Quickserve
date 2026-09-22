# QuickServe — On-Demand Hyperlocal Service Platform

QuickServe is an enterprise-grade, real-time on-demand hyperlocal service dispatch platform built with **Flutter** (Web & Android) and **Supabase** (PostgreSQL + PostGIS + Row-Level Security + Realtime).

The system seamlessly connects customers needing immediate services (e.g., plumbing, electrical, cleaning, maintenance) with verified, nearby service agents using geospatial dispatching and real-time live location tracking.

---

## Key Features & Highlights

- **Multi-Platform Support**: Responsive Flutter Web dashboard & modern Flutter Android mobile client with Material 3 Navigation.
- **Strict Role-Based Access Control**:
  - **Customer**: Request creation, address geocoding, live agent tracking, service history, and payment summary.
  - **Agent**: Real-time foreground GPS tracking, availability toggle, 120-second dispatch offer acceptance/rejection, navigation status updates, and authoritative 10–20 km service radius management.
  - **Admin**: System-wide analytics, request tracking, agent overview, and platform administration.
- **Geospatial Dispatch Engine**: PostGIS spatial indexing (`ST_DWithin`, `ST_Distance`) with PostgreSQL row-level locks (`FOR UPDATE`) to prevent double-dispatch races.
- **Strict Privacy Architecture**: Customers can *only* view an agent's coordinates while an assignment is active (`accepted` status and `assigned`/`in_progress` request status).
- **Production Truth (No Fake Data)**:
  - 100% genuine GPS: Device GPS on Android, HTML5 Geolocation on Web. Zero simulated or placeholder fallback coordinates in production code.
  - Authoritative backend validation: 10–20 km service radius enforced at both client and database levels.
  - No background service bloat: Uses clean foreground GPS tracking during active shifts only.
- **Robust Security**: `SECURITY DEFINER` database RPCs with pinned `search_path`, strict RLS policies on all tables, and client-side router guards preventing deep-link privilege escalation.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Frontend Framework** | Flutter 3.47.5 (Dart 3.13.4) |
| **State Management** | Riverpod 2.x (`StateNotifierProvider`, `Provider`, `FutureProvider`) |
| **Routing** | GoRouter with dynamic declarative `redirect` guards |
| **Design System** | Material 3 with adaptive form factor support |
| **Backend & DB** | Supabase (PostgreSQL 15+ with PostGIS extension) |
| **Realtime** | Supabase Realtime Channels (Postgres changes & broadcast) |
| **Geospatial** | PostGIS `geography(Point, 4326)` & `geolocator` |
| **Maps** | `flutter_map` + OpenStreetMap (OSM) / Leaflet tiles |

---

## Architecture Overview

```
               ┌────────────────────────────────────────────────────────┐
               │              Flutter Application Layer                 │
               │   (Customer Web/App, Agent Web/App, Admin Portal)      │
               └──────────────────────────┬─────────────────────────────┘
                                          │
                               Riverpod Controllers
                                          │
                           Repositories & Service Layer
                                          │
                     ┌────────────────────┴────────────────────┐
                     │                                         │
               Supabase Client                         Geolocator API
           (Auth, PostgREST, Realtime)              (Device GPS / Web Geo)
                     │                                         │
        ┌────────────┴───────────────────────────┐             │
        │             Supabase Backend           │             │
        │  ┌──────────────────────────────────┐  │             │
        │  │       Row-Level Security         │  │             │
        │  ├──────────────────────────────────┤  │             │
        │  │ PostGIS Spatial Dispatch Engine  │◄─┼─────────────┘
        │  ├──────────────────────────────────┤  │
        │  │  120s Concurrency & Locks (RPC)  │  │
        │  └──────────────────────────────────┘  │
        └────────────────────────────────────────┘
```

---

## Prerequisites

1. **Flutter SDK**: `>= 3.47.0` (Dart `>= 3.13.0`)
2. **Android SDK**: `compileSdk 36`, `targetSdk 36`, `minSdk 24`, JDK 17+
3. **Supabase Project**: A hosted Supabase project or local Supabase CLI environment with PostGIS enabled.
4. **Google Chrome**: For Web debugging and testing.

---

## Environment Setup

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Populate your Supabase project credentials in `.env`:
   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
   > **Note**: Never commit your `.env` file or include service-role keys.

---

## Database Setup & Migrations

Execute the SQL migrations located in `supabase/migrations/` in chronological order:

1. `supabase/migrations/20260918000000_phase1_initial_schema.sql`
   - Sets up PostGIS extension, custom enums (`user_role`, `request_status`, etc.).
   - Creates `profiles`, `agent_profiles`, `service_requests`, `service_assignments`, `agent_locations`, `payments`.
   - Establishes base RLS policies.
2. `supabase/migrations/20260920000000_phase3_dispatch_and_realtime.sql`
   - Hardens RLS policies for real-time location visibility.
   - Creates `expire_stale_service_offers()` for the 120-second offer timeout.
   - Creates `_dispatch_service_request_internal()` with `FOR UPDATE SKIP LOCKED` logic.
   - Creates atomic RPCs: `dispatch_service_request()`, `accept_service_offer()`, `reject_service_offer()`.
   - Sets `SECURITY DEFINER` and pins `search_path = public, extensions`.

---

## Running the Application

### 1. Flutter Web (Chrome)
Run the web app using the environment variables:
```bash
flutter run -d chrome --dart-define-from-file=.env
```
Default URL: `http://localhost:24004` (or allocated local port).

### 2. Flutter Android (Emulator / Physical Device)
Ensure an emulator or device is running (e.g., Pixel 8 API 36):
```bash
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=.env
```

---

## Quality Assurance & Verification

### Static Analysis
Ensure zero lint or type errors:
```bash
flutter analyze
```

### Test Suite
Run the full test suite (unit tests, router guards, models, hardening tests):
```bash
flutter test
```
*Current test baseline: 79/79 tests passing.*

### Release Builds
Build production-ready artifacts:
```bash
# Android Release APK
flutter build apk --release

# Production Web Build
flutter build web
```

---

## Role Workflows & Demo Sequence

### A. Customer Flow
1. **Login/Register**: Sign in as a customer (`role: customer`).
2. **Create Request**: Select category (e.g., plumbing), enter title, address, and coordinates.
3. **Dispatch**: The system invokes `dispatch_service_request` to locate the nearest available agent within their configured service radius (10–20 km).
4. **Live Tracking**: Once an agent accepts, view real-time location updates on the map.
5. **Completion & Payment**: View finalized request details and payment status.

### B. Agent Flow
1. **Login**: Sign in as an agent (`role: agent`).
2. **Go Online**: Toggle status to `available` and start foreground GPS publishing.
3. **Incoming Offer**: Receive real-time service offer alert with a 120-second countdown timer.
4. **Accept / Reject**:
   - Accepting updates request status to `assigned` and starts active navigation.
   - Rejecting releases the offer and re-dispatches to the next eligible agent.
5. **Manage Service Radius**: Set authoritative radius strictly between 10 km and 20 km.

### C. Admin Flow
1. **Login**: Sign in with administrative credentials (`role: admin`).
2. **Dashboard Overview**: Monitor all live requests, active agents, and assignment metrics.
3. **Audit Logs & System Monitoring**: Review real-time audit event logs (LOGIN_SUCCESS, REQUEST_CREATED, REQUEST_ASSIGNED, REQUEST_UPDATED, AUTHORIZATION_FAILED, DATABASE_ERROR) with sensitive data automatically masked.

---

## Test Credentials & Demo Accounts

The following demo accounts are provisioned for evaluation across all roles:

| Role | Email | Password | Allowed Access |
| :--- | :--- | :--- | :--- |
| **Customer** | `customer@quickserve.com` | `QuickServe@123` | Customer Mobile Shell / Web Portal (`/customer`) |
| **Agent** | `agent@quickserve.com` | `QuickServe@123` | Agent Mobile Shell / Web Dashboard (`/agent`) |
| **Admin** | `admin@quickserve.com` | `QuickServe@123` | Web Administration Portal (`/admin`) |

> [!NOTE]
> - Self-registration is enabled on both Web and Mobile for Customer and Agent roles.
> - Password reset via email is supported from the login screen.
> - Role-based route guards strictly prevent unauthorized cross-role access (e.g., Customer accessing Admin routes triggers `AUTHORIZATION_FAILED` audit events and redirects to `/unauthorized`).

