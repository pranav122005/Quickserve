-- ============================================================
-- QUICKSERVE COMPLETE MIGRATION & RLS REPAIR SCRIPT (V2)
-- Includes explicit DROP POLICY IF EXISTS for every policy name
-- Target Project: qlnonehymdltnuoappyh.supabase.co
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. EXTENSIONS & ENUMS
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('customer', 'agent', 'admin');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'agent_availability') THEN
        CREATE TYPE public.agent_availability AS ENUM ('offline', 'available', 'busy');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_priority') THEN
        CREATE TYPE public.request_priority AS ENUM ('low', 'normal', 'high', 'urgent');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'request_status') THEN
        CREATE TYPE public.request_status AS ENUM ('pending', 'dispatching', 'assigned', 'in_progress', 'completed', 'cancelled');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'assignment_status') THEN
        CREATE TYPE public.assignment_status AS ENUM ('offered', 'accepted', 'rejected', 'cancelled', 'completed');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
        CREATE TYPE public.payment_method AS ENUM ('cash', 'upi', 'other');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE public.payment_status AS ENUM ('pending', 'paid', 'failed');
    END IF;
END $$;

-- ------------------------------------------------------------
-- 2. NON-RECURSIVE SECURITY DEFINER HELPERS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;

CREATE OR REPLACE FUNCTION public.is_request_customer(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.service_requests
    WHERE id = p_request_id AND customer_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_request_customer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_request_customer(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_agent_assigned_to_request(p_request_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.service_assignments
    WHERE request_id = p_request_id AND agent_id = auth.uid()
  );
$$;

REVOKE ALL ON FUNCTION public.is_agent_assigned_to_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_agent_assigned_to_request(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.is_customer_of_active_agent_location(p_agent_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.service_requests sr
    JOIN public.service_assignments sa ON sa.request_id = sr.id
    WHERE sr.customer_id = auth.uid()
      AND sa.agent_id = p_agent_id
      AND sa.status = 'accepted'
      AND sr.status IN ('assigned', 'in_progress')
  );
$$;

REVOKE ALL ON FUNCTION public.is_customer_of_active_agent_location(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_customer_of_active_agent_location(uuid) TO authenticated;

-- ------------------------------------------------------------
-- 3. PROFILES TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text NOT NULL,
    phone text,
    role public.user_role NOT NULL DEFAULT 'customer',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "authenticated_select_profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can update profiles" ON public.profiles;
CREATE POLICY "authenticated_select_profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);
CREATE POLICY "Admins can update profiles" ON public.profiles FOR UPDATE TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role) WITH CHECK (public.get_current_user_role() = 'admin'::public.user_role);

-- ------------------------------------------------------------
-- 4. AGENT PROFILES TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.agent_profiles (
    user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    service_radius_km numeric(6,2) NOT NULL DEFAULT 15 CHECK (service_radius_km > 0 AND service_radius_km <= 100),
    availability public.agent_availability NOT NULL DEFAULT 'offline',
    is_verified boolean NOT NULL DEFAULT false,
    last_assigned_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "agent_profiles_select_authenticated" ON public.agent_profiles;
DROP POLICY IF EXISTS "agent_profiles_update_self" ON public.agent_profiles;
DROP POLICY IF EXISTS "agents_view_own" ON public.agent_profiles;
DROP POLICY IF EXISTS "agents_update_own" ON public.agent_profiles;
DROP POLICY IF EXISTS "admins_view_all_agents" ON public.agent_profiles;
DROP POLICY IF EXISTS "Agents can view own profile" ON public.agent_profiles;
DROP POLICY IF EXISTS "Agents can update own profile" ON public.agent_profiles;
DROP POLICY IF EXISTS "Admins can view all agent profiles" ON public.agent_profiles;

CREATE POLICY "agents_view_own" ON public.agent_profiles FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "agents_update_own" ON public.agent_profiles FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "admins_view_all_agents" ON public.agent_profiles FOR SELECT TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);

-- ------------------------------------------------------------
-- 5. SERVICE REQUESTS TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    category text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    priority public.request_priority NOT NULL DEFAULT 'normal',
    service_address text,
    service_location extensions.geography(Point, 4326) NOT NULL,
    status public.request_status NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz
);

DROP POLICY IF EXISTS "service_requests_customer_select" ON public.service_requests;
DROP POLICY IF EXISTS "service_requests_customer_insert" ON public.service_requests;
DROP POLICY IF EXISTS "customer_select_own" ON public.service_requests;
DROP POLICY IF EXISTS "customer_insert_own" ON public.service_requests;
DROP POLICY IF EXISTS "customer_cancel_own" ON public.service_requests;
DROP POLICY IF EXISTS "agent_select_assigned" ON public.service_requests;
DROP POLICY IF EXISTS "admin_select_all" ON public.service_requests;
DROP POLICY IF EXISTS "Customers can view own requests" ON public.service_requests;
DROP POLICY IF EXISTS "Customers can create requests" ON public.service_requests;
DROP POLICY IF EXISTS "Customers can update own requests" ON public.service_requests;
DROP POLICY IF EXISTS "Agents can view assigned or pending requests" ON public.service_requests;
DROP POLICY IF EXISTS "Agents can view assigned requests" ON public.service_requests;
DROP POLICY IF EXISTS "Admins can view all service requests" ON public.service_requests;
DROP POLICY IF EXISTS "admin_all_requests" ON public.service_requests;
DROP POLICY IF EXISTS "agent_update_requests" ON public.service_requests;

CREATE POLICY "customer_select_own" ON public.service_requests FOR SELECT TO authenticated USING (customer_id = auth.uid());
CREATE POLICY "customer_insert_own" ON public.service_requests FOR INSERT TO authenticated WITH CHECK (customer_id = auth.uid() AND public.get_current_user_role() = 'customer'::public.user_role);
CREATE POLICY "customer_cancel_own" ON public.service_requests FOR UPDATE TO authenticated USING (customer_id = auth.uid() AND status IN ('pending'::public.request_status, 'dispatching'::public.request_status)) WITH CHECK (customer_id = auth.uid());
CREATE POLICY "Agents can view assigned or pending requests" ON public.service_requests FOR SELECT TO authenticated USING (public.get_current_user_role() = 'agent'::public.user_role AND (status IN ('pending'::public.request_status, 'dispatching'::public.request_status) OR public.is_agent_assigned_to_request(id)));
CREATE POLICY "agent_update_requests" ON public.service_requests FOR UPDATE TO authenticated USING (public.get_current_user_role() = 'agent'::public.user_role);
CREATE POLICY "admin_all_requests" ON public.service_requests FOR ALL TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);

-- ------------------------------------------------------------
-- 6. SERVICE ASSIGNMENTS TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.service_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    agent_id uuid NOT NULL REFERENCES public.agent_profiles(user_id) ON DELETE RESTRICT,
    status public.assignment_status NOT NULL DEFAULT 'offered',
    offered_at timestamptz,
    assigned_at timestamptz NOT NULL DEFAULT now(),
    accepted_at timestamptz,
    rejected_at timestamptz,
    completed_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "assignments_select_related" ON public.service_assignments;
DROP POLICY IF EXISTS "agents_select_assigned" ON public.service_assignments;
DROP POLICY IF EXISTS "agents_update_assigned" ON public.service_assignments;
DROP POLICY IF EXISTS "agents_insert_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "customers_select_assigned_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "admin_select_all_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "admin_all_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "Agents can view own assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "Agents can update own assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "Customers can view assignments for their requests" ON public.service_assignments;
DROP POLICY IF EXISTS "Admins can view all assignments" ON public.service_assignments;

CREATE POLICY "agents_select_assigned" ON public.service_assignments FOR SELECT TO authenticated USING (agent_id = auth.uid());
CREATE POLICY "agents_insert_assignments" ON public.service_assignments FOR INSERT TO authenticated WITH CHECK (agent_id = auth.uid() AND public.get_current_user_role() = 'agent'::public.user_role);
CREATE POLICY "agents_update_assigned" ON public.service_assignments FOR UPDATE TO authenticated USING (agent_id = auth.uid()) WITH CHECK (agent_id = auth.uid());
CREATE POLICY "customers_select_assigned_assignments" ON public.service_assignments FOR SELECT TO authenticated USING (public.is_request_customer(request_id));
CREATE POLICY "admin_all_assignments" ON public.service_assignments FOR ALL TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);

-- ------------------------------------------------------------
-- 7. REQUEST STATUS HISTORY TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.request_status_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL REFERENCES public.service_requests(id) ON DELETE CASCADE,
    changed_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    old_status public.request_status,
    new_status public.request_status NOT NULL,
    note text,
    created_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "status_history_select_related" ON public.request_status_history;
DROP POLICY IF EXISTS "users_view_accessible_history" ON public.request_status_history;
DROP POLICY IF EXISTS "customers_view_history" ON public.request_status_history;
DROP POLICY IF EXISTS "agents_view_history" ON public.request_status_history;
DROP POLICY IF EXISTS "admins_view_history" ON public.request_status_history;
DROP POLICY IF EXISTS "Customers can view history for own requests" ON public.request_status_history;
DROP POLICY IF EXISTS "Agents can view history for assigned requests" ON public.request_status_history;
DROP POLICY IF EXISTS "Admins can view all status history" ON public.request_status_history;

DROP POLICY IF EXISTS "users_insert_status_history" ON public.request_status_history;

CREATE POLICY "customers_view_history" ON public.request_status_history FOR SELECT TO authenticated USING (public.is_request_customer(request_id));
CREATE POLICY "agents_view_history" ON public.request_status_history FOR SELECT TO authenticated USING (public.is_agent_assigned_to_request(request_id));
CREATE POLICY "admins_view_history" ON public.request_status_history FOR SELECT TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);
CREATE POLICY "users_insert_status_history" ON public.request_status_history FOR INSERT TO authenticated WITH CHECK (changed_by = auth.uid());

-- ------------------------------------------------------------
-- 8. AGENT LOCATIONS TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.agent_locations (
    agent_id uuid PRIMARY KEY REFERENCES public.agent_profiles(user_id) ON DELETE CASCADE,
    location extensions.geography(Point, 4326) NOT NULL,
    accuracy_m numeric(8,2),
    updated_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "agent_locations_select" ON public.agent_locations;
DROP POLICY IF EXISTS "agent_locations_update_self" ON public.agent_locations;
DROP POLICY IF EXISTS "agent_locations_update_self_update" ON public.agent_locations;
DROP POLICY IF EXISTS "Customers can view assigned agent location" ON public.agent_locations;
DROP POLICY IF EXISTS "Agents can view own location" ON public.agent_locations;
DROP POLICY IF EXISTS "Agents can upsert own location" ON public.agent_locations;
DROP POLICY IF EXISTS "Admins can view all agent locations" ON public.agent_locations;

CREATE POLICY "Agents can view own location" ON public.agent_locations FOR SELECT TO authenticated USING (agent_id = auth.uid());
CREATE POLICY "Agents can upsert own location" ON public.agent_locations FOR ALL TO authenticated USING (agent_id = auth.uid()) WITH CHECK (agent_id = auth.uid());
CREATE POLICY "Customers can view assigned agent location" ON public.agent_locations FOR SELECT TO authenticated USING (public.is_customer_of_active_agent_location(agent_id));
CREATE POLICY "Admins can view all agent locations" ON public.agent_locations FOR SELECT TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);

-- ------------------------------------------------------------
-- 9. PAYMENTS TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid NOT NULL UNIQUE REFERENCES public.service_requests(id) ON DELETE RESTRICT,
    customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    agent_id uuid NOT NULL REFERENCES public.agent_profiles(user_id) ON DELETE RESTRICT,
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    currency text NOT NULL DEFAULT 'INR',
    method public.payment_method,
    status public.payment_status NOT NULL DEFAULT 'pending',
    paid_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "payments_select_related" ON public.payments;
DROP POLICY IF EXISTS "payments_customer_select" ON public.payments;
DROP POLICY IF EXISTS "payments_agent_select" ON public.payments;
DROP POLICY IF EXISTS "payments_admin_select" ON public.payments;
DROP POLICY IF EXISTS "Customers can view own payments" ON public.payments;
DROP POLICY IF EXISTS "Agents can view own payments" ON public.payments;
DROP POLICY IF EXISTS "Admins can view all payments" ON public.payments;

CREATE POLICY "payments_customer_select" ON public.payments FOR SELECT TO authenticated USING (customer_id = auth.uid());
CREATE POLICY "payments_agent_select" ON public.payments FOR SELECT TO authenticated USING (agent_id = auth.uid());
CREATE POLICY "payments_admin_select" ON public.payments FOR SELECT TO authenticated USING (public.get_current_user_role() = 'admin'::public.user_role);

-- ------------------------------------------------------------
-- 10. NOTIFICATIONS TABLE & POLICIES
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    request_id uuid REFERENCES public.service_requests(id) ON DELETE CASCADE,
    type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

DROP POLICY IF EXISTS "notifications_select_self" ON public.notifications;
CREATE POLICY "notifications_select_self" ON public.notifications FOR SELECT TO authenticated USING (user_id = auth.uid());

-- ------------------------------------------------------------
-- 11. PROFILE CREATION TRIGGER (AUTOMATIC NEW SIGNUPS)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, phone, role)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data ->> 'full_name', 'New User'),
        new.raw_user_meta_data ->> 'phone',
        'customer'::public.user_role
    );
    RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------
-- 11b. ADMIN MANUAL ASSIGNMENT RPC
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_assign_service_request(
    p_request_id uuid,
    p_agent_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role public.user_role;
    v_request record;
    v_agent record;
    v_assignment_id uuid;
    v_now timestamptz := now();
BEGIN
    -- 1. Verify caller is an authenticated Admin
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'unauthenticated'
        );
    END IF;

    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = v_caller_id;

    IF v_caller_role IS NULL OR v_caller_role != 'admin'::public.user_role THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'unauthorized_not_admin'
        );
    END IF;

    -- 2. Verify request exists and lock row
    SELECT * INTO v_request
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'request_not_found'
        );
    END IF;

    -- 3. LIFECYCLE CHECK: Only pending or dispatching requests can be assigned.
    -- Cancelled or Completed requests MUST be rejected cleanly!
    IF v_request.status IN ('completed'::public.request_status, 'cancelled'::public.request_status) THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'request_lifecycle_closed',
            'status', v_request.status,
            'message', 'This request is cancelled or completed and can no longer be assigned.'
        );
    END IF;

    -- 4. Verify agent exists
    SELECT ap.*, p.role INTO v_agent
    FROM public.agent_profiles ap
    JOIN public.profiles p ON p.id = ap.user_id
    WHERE ap.user_id = p_agent_id;

    IF v_agent IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'agent_not_found'
        );
    END IF;

    -- 5. Create Service Assignment Offer
    INSERT INTO public.service_assignments (
        request_id,
        agent_id,
        status,
        offered_at,
        created_at
    ) VALUES (
        p_request_id,
        p_agent_id,
        'offered'::public.assignment_status,
        v_now,
        v_now
    )
    RETURNING id INTO v_assignment_id;

    -- 6. Update Request Status to dispatching
    UPDATE public.service_requests
    SET status = 'dispatching'::public.request_status,
        updated_at = v_now
    WHERE id = p_request_id;

    -- 7. Record status history
    INSERT INTO public.request_status_history (
        request_id,
        old_status,
        new_status,
        changed_by,
        note
    ) VALUES (
        p_request_id,
        v_request.status,
        'dispatching'::public.request_status,
        v_caller_id,
        'Admin manually assigned request to agent.'
    );

    RETURN jsonb_build_object(
        'success', true,
        'assignment_id', v_assignment_id,
        'request_id', p_request_id,
        'agent_id', p_agent_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_assign_service_request(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_assign_service_request(uuid, uuid) TO authenticated;

-- ------------------------------------------------------------
-- 12. DEMO ACCOUNTS PROVISIONING & CONFIRMATION
-- ------------------------------------------------------------

-- 12a. Confirm emails in auth.users
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
    updated_at = now()
WHERE email IN ('customer@quickserve.com', 'agent@quickserve.com', 'admin@quickserve.com');

-- 12b. Upsert Customer Profile
INSERT INTO public.profiles (id, full_name, role, phone, updated_at)
SELECT id, 'Demo Customer', 'customer'::public.user_role, '+91 9876543210', now()
FROM auth.users WHERE email = 'customer@quickserve.com'
ON CONFLICT (id) DO UPDATE SET updated_at = now();

-- 12c. Upsert Agent Profile
INSERT INTO public.profiles (id, full_name, role, phone, updated_at)
SELECT id, 'Demo Service Agent', 'agent'::public.user_role, '+91 9876543211', now()
FROM auth.users WHERE email = 'agent@quickserve.com'
ON CONFLICT (id) DO UPDATE SET role = 'agent'::public.user_role, updated_at = now();

INSERT INTO public.agent_profiles (user_id, service_radius_km, availability, is_verified, updated_at)
SELECT u.id, 15.0, 'offline', true, now()
FROM auth.users u WHERE u.email = 'agent@quickserve.com'
ON CONFLICT (user_id) DO UPDATE SET service_radius_km = 15.0, availability = 'offline', is_verified = true, updated_at = now();

-- 12d. Upsert Admin Profile
INSERT INTO public.profiles (id, full_name, role, phone, updated_at)
SELECT id, 'Platform Administrator', 'admin'::public.user_role, '+91 9876543212', now()
FROM auth.users WHERE email = 'admin@quickserve.com'
ON CONFLICT (id) DO UPDATE SET role = 'admin'::public.user_role, updated_at = now();

-- ------------------------------------------------------------
-- 13. ENABLE AND FORCE ROW LEVEL SECURITY (RLS)
-- ------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests FORCE ROW LEVEL SECURITY;

ALTER TABLE public.service_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_assignments FORCE ROW LEVEL SECURITY;

ALTER TABLE public.agent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_profiles FORCE ROW LEVEL SECURITY;

ALTER TABLE public.agent_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_locations FORCE ROW LEVEL SECURITY;

ALTER TABLE public.request_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_status_history FORCE ROW LEVEL SECURITY;

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments FORCE ROW LEVEL SECURITY;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;

COMMIT;
