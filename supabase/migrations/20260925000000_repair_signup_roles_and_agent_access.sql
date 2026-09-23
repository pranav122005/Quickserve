-- QuickServe role-signup repair.
-- This replaces conflicting old profile/agent RLS policies and the old trigger
-- that hard-coded every public signup as a customer.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS public.user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

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

CREATE OR REPLACE FUNCTION public.is_agent_assigned_to_customer(p_customer_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.service_assignments sa
    JOIN public.service_requests sr ON sr.id = sa.request_id
    WHERE sa.agent_id = auth.uid()
      AND sr.customer_id = p_customer_id
      AND sa.status IN ('offered'::public.assignment_status, 'accepted'::public.assignment_status)
  );
$$;

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
      AND sa.status = 'accepted'::public.assignment_status
      AND sr.status IN ('assigned'::public.request_status, 'in_progress'::public.request_status)
  );
$$;

REVOKE ALL ON FUNCTION public.get_current_user_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_request_customer(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_agent_assigned_to_request(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_agent_assigned_to_customer(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_customer_of_active_agent_location(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_request_customer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_agent_assigned_to_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_agent_assigned_to_customer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_customer_of_active_agent_location(uuid) TO authenticated;

-- Customer and agent are the only public choices. An auth metadata value of
-- admin is deliberately treated as customer, so a client cannot self-promote.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_role public.user_role := CASE
    WHEN new.raw_user_meta_data ->> 'requested_role' = 'agent'
      THEN 'agent'::public.user_role
    ELSE 'customer'::public.user_role
  END;
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data ->> 'full_name', 'New User'),
    new.raw_user_meta_data ->> 'phone',
    v_role
  );

  IF v_role = 'agent'::public.user_role THEN
    INSERT INTO public.agent_profiles (user_id, service_radius_km, availability, is_verified)
    VALUES (new.id, 15, 'offline'::public.agent_availability, false);
  END IF;

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Repair accounts already created from the updated Agent registration screen.
UPDATE public.profiles p
SET role = 'agent'::public.user_role
FROM auth.users u
WHERE u.id = p.id
  AND u.raw_user_meta_data ->> 'requested_role' = 'agent';

INSERT INTO public.agent_profiles (user_id, service_radius_km, availability, is_verified)
SELECT p.id, 15, 'offline'::public.agent_availability, false
FROM public.profiles p
WHERE p.role = 'agent'::public.user_role
ON CONFLICT (user_id) DO NOTHING;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.request_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_locations ENABLE ROW LEVEL SECURITY;

-- Remove every conflicting policy from the tables that govern login and agent access.
DO $$
DECLARE v_policy record;
BEGIN
  FOR v_policy IN
    SELECT tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN (
        'profiles', 'agent_profiles', 'service_requests', 'service_assignments',
        'request_status_history', 'agent_locations'
      )
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', v_policy.policyname, v_policy.tablename);
  END LOOP;
END;
$$;

-- Column privileges prevent users from changing their own role or verification.
REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (full_name, phone) ON TABLE public.profiles TO authenticated;
REVOKE UPDATE ON TABLE public.agent_profiles FROM authenticated;
GRANT UPDATE (availability, service_radius_km) ON TABLE public.agent_profiles TO authenticated;

CREATE POLICY profiles_select_self_or_authorized
ON public.profiles FOR SELECT TO authenticated
USING (
  id = auth.uid()
  OR public.get_current_user_role() = 'admin'::public.user_role
  OR public.is_agent_assigned_to_customer(id)
);

CREATE POLICY profiles_update_self_details
ON public.profiles FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

CREATE POLICY agent_profiles_select_self_or_admin
ON public.agent_profiles FOR SELECT TO authenticated
USING (
  user_id = auth.uid()
  OR public.get_current_user_role() = 'admin'::public.user_role
);

CREATE POLICY agent_profiles_update_self_operational_fields
ON public.agent_profiles FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY service_requests_customer_select
ON public.service_requests FOR SELECT TO authenticated
USING (customer_id = auth.uid());

CREATE POLICY service_requests_agent_select_assigned
ON public.service_requests FOR SELECT TO authenticated
USING (
  public.get_current_user_role() = 'agent'::public.user_role
  AND public.is_agent_assigned_to_request(id)
);

CREATE POLICY service_requests_admin_select
ON public.service_requests FOR SELECT TO authenticated
USING (public.get_current_user_role() = 'admin'::public.user_role);

CREATE POLICY service_requests_customer_insert
ON public.service_requests FOR INSERT TO authenticated
WITH CHECK (
  customer_id = auth.uid()
  AND public.get_current_user_role() = 'customer'::public.user_role
);

CREATE POLICY service_requests_customer_cancel
ON public.service_requests FOR UPDATE TO authenticated
USING (
  customer_id = auth.uid()
  AND status IN ('pending'::public.request_status, 'dispatching'::public.request_status)
)
WITH CHECK (
  customer_id = auth.uid()
  AND status = 'cancelled'::public.request_status
);

CREATE POLICY assignments_agent_select_own
ON public.service_assignments FOR SELECT TO authenticated
USING (agent_id = auth.uid());

CREATE POLICY assignments_customer_select_own_request
ON public.service_assignments FOR SELECT TO authenticated
USING (public.is_request_customer(request_id));

CREATE POLICY assignments_admin_select
ON public.service_assignments FOR SELECT TO authenticated
USING (public.get_current_user_role() = 'admin'::public.user_role);

CREATE POLICY request_history_customer_or_agent_or_admin_select
ON public.request_status_history FOR SELECT TO authenticated
USING (
  public.is_request_customer(request_id)
  OR public.is_agent_assigned_to_request(request_id)
  OR public.get_current_user_role() = 'admin'::public.user_role
);

CREATE POLICY agent_locations_agent_manage_own
ON public.agent_locations FOR ALL TO authenticated
USING (agent_id = auth.uid())
WITH CHECK (agent_id = auth.uid());

CREATE POLICY agent_locations_customer_select_active_assignment
ON public.agent_locations FOR SELECT TO authenticated
USING (public.is_customer_of_active_agent_location(agent_id));

CREATE POLICY agent_locations_admin_select
ON public.agent_locations FOR SELECT TO authenticated
USING (public.get_current_user_role() = 'admin'::public.user_role);

COMMIT;
