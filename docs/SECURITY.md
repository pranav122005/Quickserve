# QuickServe Security Architecture & Access Controls

This document details the security model, authentication flows, Row-Level Security (RLS) policies, and role-based access control (RBAC) enforced by **QuickServe**.

---

## 1. Security Architecture Principles

1. **Backend Authority**: Authorization, state transitions, dispatch candidate selection, and role validation are enforced strictly on PostgreSQL and Supabase. The Flutter client acts as a presentation tier and does not possess authority to modify roles or override RLS rules.
2. **Security Definer Functions**: Role checking functions (`get_current_user_role()`, `get_my_role()`) execute with `SECURITY DEFINER` and fixed `search_path = public`, eliminating potential infinite RLS recursion and preventing search_path manipulation attacks.
3. **Explicit Row-Level Security**: Every table in the `public` schema has Row-Level Security enabled (`ENABLE ROW LEVEL SECURITY`). Access is denied by default unless explicitly granted by a policy.

---

## 2. Authentication & Role Model

Authentication is powered by **Supabase Auth (GoTrue)** issuing JSON Web Tokens (JWT).

### User Roles (`public.user_role` ENUM)
- **`customer`**: Can create service requests, view own requests, cancel pending/dispatching requests, and track assigned agent locations during active service.
- **`agent`**: Can manage personal availability status (`offline`, `available`), view assigned job offers, accept/reject offers, update job state (`in_progress`, `completed`), and publish live location during active jobs.
- **`admin`**: System administrator with full access to view, edit, reassign, and audit all requests, profiles, assignments, and payments across the platform.

---

## 3. Key Row-Level Security Policies

### `public.profiles`
- **SELECT**: Users can view their own profile (`id = auth.uid()`) OR administrators (`get_current_user_role() = 'admin'`).
- **UPDATE**: Users can update their own profile (`id = auth.uid()`).

### `public.agent_profiles`
- **SELECT**: Authenticated users can view agent profiles.
- **INSERT / UPDATE**: Agents can update their own profile (`user_id = auth.uid()`) or admins.

### `public.service_requests`
- **SELECT**: Customers can view requests where `customer_id = auth.uid()`. Assigned agents can view requests assigned to them. Admins can view all requests.
- **INSERT**: Customers can insert requests where `customer_id = auth.uid()`.

### `public.service_assignments`
- **SELECT**: Assigned agents (`agent_id = auth.uid()`), request customers, and admins can view assignments.
- **UPDATE**: Agents can update their assigned offer state (`agent_id = auth.uid()`).

### `public.agent_locations`
- **SELECT**: Customers can view live location ONLY if an active accepted assignment exists with the agent for their ongoing job. Agents can view their own location.
- **INSERT / UPDATE**: Agents can insert/update their own location (`agent_id = auth.uid()`).
