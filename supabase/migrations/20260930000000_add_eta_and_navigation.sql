-- QuickServe Migration: Add Estimated Arrival (ETA) to Service Requests and Update RPC
-- Description:
-- 1. Adds `estimated_arrival` timestamptz column to `public.service_requests`
-- 2. Adds secure `update_service_request_eta` RPC with strict assignment and terminal state authorization checks
-- 3. Grants execute permissions only to authenticated users

--------------------------------------------------------------------------------
-- 1. ADD ESTIMATED_ARRIVAL COLUMN TO SERVICE_REQUESTS
--------------------------------------------------------------------------------
ALTER TABLE public.service_requests 
ADD COLUMN IF NOT EXISTS estimated_arrival timestamptz;

--------------------------------------------------------------------------------
-- 2. SECURE RPC TO UPDATE ETA
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_service_request_eta(
    p_request_id uuid,
    p_estimated_arrival timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role text;
    v_request record;
    v_is_assigned boolean;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
    END IF;

    -- Lock and verify service request
    SELECT * INTO v_request
    FROM public.service_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF v_request IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'request_not_found');
    END IF;

    -- Reject ETA update if request is in a terminal state (completed or cancelled)
    IF v_request.status IN ('completed', 'cancelled') THEN
        RETURN jsonb_build_object('success', false, 'reason', 'terminal_state', 'status', v_request.status);
    END IF;

    -- Fetch caller role
    SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;

    -- Verify caller is the assigned agent with accepted status
    SELECT EXISTS (
        SELECT 1 FROM public.service_assignments
        WHERE request_id = p_request_id
          AND agent_id = v_caller_id
          AND status = 'accepted'
    ) INTO v_is_assigned;

    IF NOT v_is_assigned AND v_caller_role != 'admin' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'unauthorized');
    END IF;

    -- Persist estimated arrival and updated_at
    UPDATE public.service_requests
    SET estimated_arrival = p_estimated_arrival,
        updated_at = now()
    WHERE id = p_request_id;

    -- Append audit note
    INSERT INTO public.request_status_history (
        request_id, old_status, new_status, changed_by, note
    ) VALUES (
        p_request_id, v_request.status, v_request.status, v_caller_id, 'Estimated arrival updated by service agent.'
    );

    RETURN jsonb_build_object('success', true);
END;
$$;

--------------------------------------------------------------------------------
-- 3. PERMISSIONS AND GRANTS
--------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.update_service_request_eta(uuid, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_service_request_eta(uuid, timestamptz) TO authenticated;
