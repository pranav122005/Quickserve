# QuickServe Database Schema & PostGIS Specifications

This document describes the PostgreSQL database schema, PostGIS geospatial functions, table definitions, and triggers for the **QuickServe** platform.

---

## 1. Schema Diagram

```
+-------------------+       +-----------------------+       +-------------------------+
|     profiles      |       |    agent_profiles     |       |     agent_locations     |
+-------------------+       +-----------------------+       +-------------------------+
| id (PK, auth.users|◄──────| user_id (PK, FK)      |◄──────| agent_id (PK, FK)       |
| full_name         |       | service_radius_km     |       | location (Geography)    |
| phone             |       | availability (Enum)   |       | accuracy_m              |
| role (UserRole)   |       | is_verified (Boolean) |       | updated_at              |
| created_at        |       | last_assigned_at      |       +-------------------------+
| updated_at        |       | created_at, updated_at|
+---------┬---------+       +-----------┬-----------+
          │                             │
          │ customer_id                 │ agent_id
          ▼                             ▼
+-------------------+       +-----------------------+       +-------------------------+
| service_requests  |       |  service_assignments  |       | request_status_history  |
+-------------------+       +-----------------------+       +-------------------------+
| id (PK)           |◄──────| id (PK)               |       | id (PK)                 |
| customer_id (FK)  |       | request_id (FK)       |◄──────| request_id (FK)         |
| category          |       | agent_id (FK)         |       | changed_by (FK)         |
| title, description|       | status (AssignStatus) |       | old_status, new_status  |
| service_address   |       | offered_at            |       | note, created_at        |
| service_location  |       | assigned_at           |       +-------------------------+
| priority, status  |       | accepted_at, rejected |
| created_at, etc.  |       | completed_at          |
+-------------------+       +-----------------------+
```

---

## 2. Core Tables

### `public.profiles`
Primary user profile table synced automatically with `auth.users` via database trigger.
- **`id`** (`uuid`, PK): Foreign key to `auth.users(id)` ON DELETE CASCADE.
- **`full_name`** (`text`): User's full display name.
- **`phone`** (`text`): Contact phone number.
- **`role`** (`public.user_role` ENUM): Role assignment (`customer`, `agent`, `admin`).
- **`created_at`**, **`updated_at`** (`timestamptz`).

### `public.agent_profiles`
Extended profile attributes for service agents.
- **`user_id`** (`uuid`, PK): References `public.profiles(id)` ON DELETE CASCADE.
- **`service_radius_km`** (`numeric(6,2)`): Coverage radius constraint (10.0 to 20.0 km).
- **`availability`** (`public.agent_availability` ENUM): `'offline'`, `'available'`, `'busy'`.
- **`is_verified`** (`boolean`): Platform verification flag.
- **`last_assigned_at`** (`timestamptz`): Timestamp of most recent job offer.

### `public.service_requests`
Stores customer service bookings.
- **`id`** (`uuid`, PK): Auto-generated UUID.
- **`customer_id`** (`uuid`): References `public.profiles(id)`.
- **`category`** (`text`): Service domain (e.g. `'Plumbing'`, `'AC Repair'`).
- **`title`**, **`description`** (`text`).
- **`service_address`** (`text`): Street/locality address.
- **`service_location`** (`geography(Point, 4326)`): PostGIS geography point.
- **`priority`** (`public.request_priority` ENUM): `'low'`, `'normal'`, `'high'`, `'urgent'`.
- **`status`** (`public.request_status` ENUM): `'pending'`, `'dispatching'`, `'assigned'`, `'in_progress'`, `'completed'`, `'cancelled'`.

### `public.service_assignments`
Atomic dispatch assignments pairing requests with agents.
- **`id`** (`uuid`, PK).
- **`request_id`** (`uuid`): References `public.service_requests(id)`.
- **`agent_id`** (`uuid`): References `public.agent_profiles(user_id)`.
- **`status`** (`public.assignment_status` ENUM): `'offered'`, `'accepted'`, `'rejected'`, `'cancelled'`, `'completed'`.
- **`offered_at`**, **`assigned_at`**, **`accepted_at`**, **`rejected_at`**, **`completed_at`** (`timestamptz`).

---

## 3. Database Functions & Triggers

### `handle_new_user()`
Automated trigger function executing `AFTER INSERT ON auth.users`.
- Extracts user metadata (`full_name`, `phone`, `role`) passed during `signUp()`.
- Inserts a corresponding row into `public.profiles`.
- If `role = 'agent'`, automatically creates an initial `public.agent_profiles` record with `is_verified = true`.

### `_dispatch_service_request_internal(p_request_id uuid, p_caller_id uuid)`
Atomic backend dispatch engine function.
- Locks candidate request row.
- Cleans up stale offers.
- Finds eligible available agents.
- Creates `service_assignments` record with `status = 'offered'`.
- Updates `service_requests.status = 'dispatching'`.

### `trigger_auto_dispatch_service_request()`
Automated trigger executing `AFTER INSERT ON public.service_requests` when `status = 'pending'`, ensuring instant automated dispatch.
