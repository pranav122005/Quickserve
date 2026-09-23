-- QuickServe: preserve backend authority for authentication and agent jobs.
-- Apply through Supabase migrations / SQL editor before releasing this client.
BEGIN;

-- A customer can edit profile details but can never promote their own role.
REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
GRANT UPDATE (full_name, phone) ON TABLE public.profiles TO authenticated;

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Direct client writes cannot bypass the dispatch and assignment RPCs.
DROP POLICY IF EXISTS "agents_insert_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "agents_update_assigned" ON public.service_assignments;
DROP POLICY IF EXISTS "agent_update_requests" ON public.service_requests;
DROP POLICY IF EXISTS "admin_all_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "admin_all_requests" ON public.service_requests;
DROP POLICY IF EXISTS "admin_select_all_assignments" ON public.service_assignments;
DROP POLICY IF EXISTS "admin_select_all_requests" ON public.service_requests;
DROP POLICY IF EXISTS "admin_select_all" ON public.service_requests;

CREATE POLICY "admin_select_all_assignments"
ON public.service_assignments FOR SELECT TO authenticated
USING (public.get_current_user_role() = 'admin'::public.user_role);

CREATE POLICY "admin_select_all_requests"
ON public.service_requests FOR SELECT TO authenticated
USING (public.get_current_user_role() = 'admin'::public.user_role);

-- A cancellation policy must only allow the cancellation state, never an
-- arbitrary lifecycle transition submitted from the client.
DROP POLICY IF EXISTS "customer_cancel_own" ON public.service_requests;
CREATE POLICY "customer_cancel_own"
ON public.service_requests FOR UPDATE TO authenticated
USING (
  customer_id = auth.uid()
  AND status IN ('pending'::public.request_status, 'dispatching'::public.request_status)
)
WITH CHECK (
  customer_id = auth.uid()
  AND status = 'cancelled'::public.request_status
);

CREATE OR REPLACE FUNCTION public.start_service_assignment(
  p_assignment_id uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_assignment public.service_assignments%ROWTYPE;
  v_request public.service_requests%ROWTYPE;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
  END IF;

  SELECT * INTO v_assignment FROM public.service_assignments
  WHERE id = p_assignment_id FOR UPDATE;
  IF v_assignment IS NULL OR v_assignment.agent_id <> v_caller_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthorized');
  END IF;
  IF v_assignment.status <> 'accepted'::public.assignment_status THEN
    RETURN jsonb_build_object('success', false, 'reason', 'assignment_not_accepted');
  END IF;

  SELECT * INTO v_request FROM public.service_requests
  WHERE id = v_assignment.request_id FOR UPDATE;
  IF v_request.status <> 'assigned'::public.request_status THEN
    RETURN jsonb_build_object('success', false, 'reason', 'request_not_assigned');
  END IF;

  UPDATE public.service_requests
  SET status = 'in_progress', updated_at = now()
  WHERE id = v_request.id;

  INSERT INTO public.request_status_history
    (request_id, old_status, new_status, changed_by, note)
  VALUES
    (v_request.id, 'assigned', 'in_progress', v_caller_id,
     COALESCE(NULLIF(trim(p_note), ''), 'Service started by assigned agent.'));

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_service_assignment(
  p_assignment_id uuid,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_assignment public.service_assignments%ROWTYPE;
  v_request public.service_requests%ROWTYPE;
BEGIN
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
  END IF;

  SELECT * INTO v_assignment FROM public.service_assignments
  WHERE id = p_assignment_id FOR UPDATE;
  IF v_assignment IS NULL OR v_assignment.agent_id <> v_caller_id THEN
    RETURN jsonb_build_object('success', false, 'reason', 'unauthorized');
  END IF;
  IF v_assignment.status <> 'accepted'::public.assignment_status THEN
    RETURN jsonb_build_object('success', false, 'reason', 'assignment_not_accepted');
  END IF;

  SELECT * INTO v_request FROM public.service_requests
  WHERE id = v_assignment.request_id FOR UPDATE;
  IF v_request.status <> 'in_progress'::public.request_status THEN
    RETURN jsonb_build_object('success', false, 'reason', 'request_not_in_progress');
  END IF;

  UPDATE public.service_assignments
  SET status = 'completed', completed_at = now()
  WHERE id = v_assignment.id;
  UPDATE public.service_requests
  SET status = 'completed', completed_at = now(), updated_at = now()
  WHERE id = v_request.id;

  INSERT INTO public.request_status_history
    (request_id, old_status, new_status, changed_by, note)
  VALUES
    (v_request.id, 'in_progress', 'completed', v_caller_id,
     COALESCE(NULLIF(trim(p_note), ''), 'Service completed by assigned agent.'));

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.start_service_assignment(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.complete_service_assignment(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_service_assignment(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_service_assignment(uuid, text) TO authenticated;

COMMIT;
