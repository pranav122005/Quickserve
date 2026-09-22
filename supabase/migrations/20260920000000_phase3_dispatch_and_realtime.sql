-- QuickServe Phase 3 Migration: Automated Dispatch, PostGIS Hybrid Ranking, Offer Expiry, and Location Privacy
-- Description:
-- 1. Stale offer expiry function with 120s offer window
-- 2. Internal atomic dispatch algorithm with fair hybrid ranking (workload ASC, distance ASC)
-- 3. Public dispatch_service_request RPC (customer/admin access only)
-- 4. Public accept_service_offer RPC (assigned agent only, <120s validity check)
-- 5. Public reject_service_offer RPC (assigned agent only, triggers next candidate dispatch)
-- 6. Strict Location Privacy RLS on agent_locations
-- 7. Realtime publication integration for assignments, requests, and locations

-- Enable PostGIS if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA extensions;

--------------------------------------------------------------------------------
-- 1. STALE OFFER EXPIRY FUNCTION
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_stale_service_offers()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_expired_count integer := 0;
    v_assign record;
    c_offer_window constant interval := interval '120 seconds';
BEGIN
    -- Select and lock stale offered assignments older than 120 seconds
    FOR v_assign IN
        SELECT id, request_id, agent_id, offered_at
        FROM public.service_assignments
        WHERE status = 'offered'
          AND offered_at < (now() - c_offer_window)
        FOR UPDATE SKIP LOCKED
    LOOP
        -- Recheck criteria inside transaction before mutating state
        IF v_assign.offered_at < (now() - c_offer_window) THEN
            UPDATE public.service_assignments
            SET status = 'cancelled'
            WHERE id = v_assign.id
              AND status = 'offered';

            v_expired_count := v_expired_count + 1;
            -- Note: Per Phase 3 rule, expiry alone does NOT create fake request_status_history
        END IF;
    END LOOP;

    RETURN v_expired_count;
END;
$$;

--------------------------------------------------------------------------------
-- 2. INTERNAL ATOMIC DISPATCH ENGINE (TRUSTED)
--------------------------------------------------------------------------------
-- This internal function performs candidate selection, locking, and assignment creation.
-- It is called ONLY by trusted wrappers (dispatch_service_request, reject_service_offer).
CREATE OR REPLACE FUNCTION public._dispatch_service_request_internal(
    p_request_id uuid,
    p_caller_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_request record;
    v_candidate record;
    v_selected_agent_id uuid := NULL;
    v_selected_distance double precision := NULL;
    v_assignment_id uuid := NULL;
    v_now timestamp with time zone := now();
    c_offer_window constant interval := interval '120 seconds';
    v_recheck_valid boolean;
BEGIN
    -- 1. Lock the request row
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

    -- 2. Reject dispatch if request is in a terminal or already assigned state
    IF v_request.status NOT IN ('pending', 'dispatching') THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'not_dispatchable',
            'status', v_request.status
        );
    END IF;

    -- 3. Verify request has geographic coordinates
    IF v_request.service_location IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'missing_location'
        );
    END IF;

    -- 4. Clean up stale offers first
    PERFORM public.expire_stale_service_offers();

    -- 5. Atomic Candidate Search with Hybrid Ranking
    -- Ranks candidates by:
    --   a) active_workload ASC (accepted jobs + unexpired offers)
    --   b) distance_meters ASC (PostGIS geography distance)
    --   c) agent_id ASC (deterministic tie-breaker)
    FOR v_candidate IN
        WITH candidate_pool AS (
            SELECT
                ap.user_id AS agent_id,
                ap.service_radius_km,
                al.location AS agent_location,
                ST_Distance(al.location, v_request.service_location) AS distance_meters,
                (
                    SELECT COUNT(sa.id)
                    FROM public.service_assignments sa
                    WHERE sa.agent_id = ap.user_id
                      AND (
                          sa.status = 'accepted'
                          OR (sa.status = 'offered' AND sa.offered_at >= (v_now - c_offer_window))
                      )
                ) AS active_workload
            FROM public.agent_profiles ap
            JOIN public.agent_locations al ON al.agent_id = ap.user_id
            WHERE ap.availability = 'available'
              AND (ap.is_verified IS TRUE OR ap.is_verified IS NULL)
              AND al.location IS NOT NULL
              AND ST_DWithin(al.location, v_request.service_location, ap.service_radius_km * 1000)
              -- Exclude agents who have actively rejected this request or currently have an active offer for it
              AND NOT EXISTS (
                  SELECT 1
                  FROM public.service_assignments prev_sa
                  WHERE prev_sa.request_id = p_request_id
                    AND prev_sa.agent_id = ap.user_id
                    AND (
                        prev_sa.status = 'rejected'
                        OR (prev_sa.status = 'offered' AND prev_sa.offered_at >= (v_now - c_offer_window))
                    )
              )
        )
        SELECT *
        FROM candidate_pool
        WHERE active_workload = 0 -- Agent must not be currently engaged on another job or offer
        ORDER BY
            active_workload ASC,
            distance_meters ASC,
            agent_id ASC
    LOOP
        -- 6. Atomically lock candidate agent row
        PERFORM 1
        FROM public.agent_profiles
        WHERE user_id = v_candidate.agent_id
        FOR UPDATE SKIP LOCKED;

        IF FOUND THEN
            -- 7. RE-CHECK ALL ELIGIBILITY CRITERIA AFTER LOCK ACQUISITION
            SELECT EXISTS (
                SELECT 1
                FROM public.agent_profiles ap
                JOIN public.agent_locations al ON al.agent_id = ap.user_id
                WHERE ap.user_id = v_candidate.agent_id
                  AND ap.availability = 'available'
                  AND ST_DWithin(al.location, v_request.service_location, ap.service_radius_km * 1000)
                  -- Ensure no conflicting active assignment occurred
                  AND NOT EXISTS (
                      SELECT 1
                      FROM public.service_assignments sa
                      WHERE sa.agent_id = ap.user_id
                        AND (
                            sa.status = 'accepted'
                            OR (sa.status = 'offered' AND sa.offered_at >= (now() - c_offer_window))
                        )
                  )
                  -- Ensure no valid offer already exists for this exact request
                  AND NOT EXISTS (
                      SELECT 1
                      FROM public.service_assignments rsa
                      WHERE rsa.request_id = p_request_id
                        AND (
                            rsa.status = 'accepted'
                            OR (rsa.status = 'offered' AND rsa.offered_at >= (now() - c_offer_window))
                        )
                  )
            ) INTO v_recheck_valid;

            IF v_recheck_valid THEN
                v_selected_agent_id := v_candidate.agent_id;
                v_selected_distance := v_candidate.distance_meters;
                EXIT; -- Winner reserved successfully
            END IF;
        END IF;
    END LOOP;

    -- 8. If no eligible candidate found
    IF v_selected_agent_id IS NULL THEN
        -- Keep request in dispatching state
        IF v_request.status = 'pending' THEN
            UPDATE public.service_requests
            SET status = 'dispatching',
                updated_at = now()
            WHERE id = p_request_id;

            INSERT INTO public.request_status_history (
                request_id, old_status, new_status, changed_by, note
            ) VALUES (
                p_request_id, 'pending', 'dispatching', p_caller_id, 'Automated dispatch initiated; searching for available agent.'
            );
        END IF;

        RETURN jsonb_build_object(
            'success', false,
            'reason', 'no_available_agent'
        );
    END IF;

    -- 9. Create Service Assignment Offer
    INSERT INTO public.service_assignments (
        request_id,
        agent_id,
        status,
        offered_at,
        created_at
    ) VALUES (
        p_request_id,
        v_selected_agent_id,
        'offered',
        now(),
        now()
    )
    RETURNING id INTO v_assignment_id;

    -- 10. Update Request Status to dispatching
    UPDATE public.service_requests
    SET status = 'dispatching',
        updated_at = now()
    WHERE id = p_request_id;

    -- 11. Append to request_status_history
    IF v_request.status != 'dispatching' THEN
        INSERT INTO public.request_status_history (
            request_id, old_status, new_status, changed_by, note
        ) VALUES (
            p_request_id, v_request.status, 'dispatching', p_caller_id, 'Automated dispatch offered request to agent.'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'assignment_id', v_assignment_id,
        'agent_id', v_selected_agent_id,
        'distance_meters', round(v_selected_distance::numeric, 1)
    );
END;
$$;

--------------------------------------------------------------------------------
-- 3. PUBLIC DISPATCH RPC (CUSTOMER & ADMIN ACCESS ONLY)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_service_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_caller_role text;
    v_request_customer_id uuid;
BEGIN
    -- Verify request existence and customer ownership
    SELECT customer_id INTO v_request_customer_id
    FROM public.service_requests
    WHERE id = p_request_id;

    IF v_request_customer_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'reason', 'request_not_found'
        );
    END IF;

    -- Authorization check: Caller must be the request owner, an admin, or internal background workflow
    IF v_caller_id IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.profiles WHERE id = v_caller_id;

        IF v_caller_id != v_request_customer_id AND v_caller_role != 'admin' THEN
            RETURN jsonb_build_object(
                'success', false,
                'reason', 'unauthorized'
            );
        END IF;
    END IF;

    -- Call internal dispatch logic
    RETURN public._dispatch_service_request_internal(p_request_id, v_caller_id);
END;
$$;

--------------------------------------------------------------------------------
-- 4. PUBLIC AGENT ACCEPT OFFER RPC
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.accept_service_offer(p_assignment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_assignment record;
    v_request record;
    c_offer_window constant interval := interval '120 seconds';
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
    END IF;

    -- 1. Lock the assignment row
    SELECT * INTO v_assignment
    FROM public.service_assignments
    WHERE id = p_assignment_id
    FOR UPDATE;

    IF v_assignment IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'assignment_not_found');
    END IF;

    -- 2. Verify caller is the assigned agent
    IF v_assignment.agent_id != v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'reason', 'unauthorized');
    END IF;

    -- 3. Verify status is still 'offered'
    IF v_assignment.status != 'offered' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'offer_already_processed', 'status', v_assignment.status);
    END IF;

    -- 4. Verify offer is not expired (< 120s)
    IF v_assignment.offered_at < (now() - c_offer_window) THEN
        -- Mark as cancelled due to expiry
        UPDATE public.service_assignments
        SET status = 'cancelled'
        WHERE id = p_assignment_id;

        RETURN jsonb_build_object('success', false, 'reason', 'offer_expired');
    END IF;

    -- 5. Lock and verify associated request
    SELECT * INTO v_request
    FROM public.service_requests
    WHERE id = v_assignment.request_id
    FOR UPDATE;

    IF v_request.status != 'dispatching' AND v_request.status != 'pending' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'request_not_available', 'status', v_request.status);
    END IF;

    -- 6. Mutate assignment status to 'accepted'
    UPDATE public.service_assignments
    SET status = 'accepted',
        accepted_at = now()
    WHERE id = p_assignment_id;

    -- 7. Mutate request status to 'assigned'
    UPDATE public.service_requests
    SET status = 'assigned',
        updated_at = now()
    WHERE id = v_assignment.request_id;

    -- 8. Append audit history
    INSERT INTO public.request_status_history (
        request_id, old_status, new_status, changed_by, note
    ) VALUES (
        v_assignment.request_id, 'dispatching', 'assigned', v_caller_id, 'Offer accepted by service agent.'
    );

    RETURN jsonb_build_object('success', true);
END;
$$;

--------------------------------------------------------------------------------
-- 5. PUBLIC AGENT REJECT OFFER RPC (TRIGGERS NEXT CANDIDATE DISPATCH)
--------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_service_offer(p_assignment_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    v_caller_id uuid := auth.uid();
    v_assignment record;
    v_dispatch_result jsonb;
BEGIN
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'unauthenticated');
    END IF;

    -- 1. Lock the assignment row
    SELECT * INTO v_assignment
    FROM public.service_assignments
    WHERE id = p_assignment_id
    FOR UPDATE;

    IF v_assignment IS NULL THEN
        RETURN jsonb_build_object('success', false, 'reason', 'assignment_not_found');
    END IF;

    -- 2. Verify caller is the assigned agent
    IF v_assignment.agent_id != v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'reason', 'unauthorized');
    END IF;

    -- 3. Verify status is 'offered'
    IF v_assignment.status != 'offered' THEN
        RETURN jsonb_build_object('success', false, 'reason', 'offer_already_processed');
    END IF;

    -- 4. Mark assignment rejected
    UPDATE public.service_assignments
    SET status = 'rejected',
        rejected_at = now()
    WHERE id = p_assignment_id;

    -- 5. Log history note
    INSERT INTO public.request_status_history (
        request_id, old_status, new_status, changed_by, note
    ) VALUES (
        v_assignment.request_id, 'dispatching', 'dispatching', v_caller_id, 'Offer declined by agent. Retrying dispatch for next candidate.'
    );

    -- 6. Trigger internal dispatch immediately for next candidate
    v_dispatch_result := public._dispatch_service_request_internal(v_assignment.request_id, v_caller_id);

    RETURN jsonb_build_object(
        'success', true,
        'next_dispatch', v_dispatch_result
    );
END;
$$;

--------------------------------------------------------------------------------
-- 6. LOCATION PRIVACY RLS POLICIES ON agent_locations
--------------------------------------------------------------------------------
ALTER TABLE public.agent_locations ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Customers can view assigned agent location" ON public.agent_locations;
DROP POLICY IF EXISTS "Agents can view own location" ON public.agent_locations;
DROP POLICY IF EXISTS "Agents can upsert own location" ON public.agent_locations;
DROP POLICY IF EXISTS "Admins can view all agent locations" ON public.agent_locations;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.agent_locations;

-- Policy A: Customer can view location ONLY for actively assigned agent on current request
CREATE POLICY "Customers can view assigned agent location"
ON public.agent_locations
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.service_requests sr
        JOIN public.service_assignments sa ON sa.request_id = sr.id
        WHERE sr.customer_id = auth.uid()
          AND sa.agent_id = agent_locations.agent_id
          AND sa.status = 'accepted'
          AND sr.status IN ('assigned', 'in_progress')
    )
);

-- Policy B: Agent can view own location
CREATE POLICY "Agents can view own location"
ON public.agent_locations
FOR SELECT
TO authenticated
USING (agent_id = auth.uid());

-- Policy C: Agent can insert or update own location
CREATE POLICY "Agents can upsert own location"
ON public.agent_locations
FOR ALL
TO authenticated
USING (agent_id = auth.uid())
WITH CHECK (agent_id = auth.uid());

-- Policy D: Admins can view all agent locations
CREATE POLICY "Admins can view all agent locations"
ON public.agent_locations
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);

--------------------------------------------------------------------------------
-- 7. REALTIME PUBLICATION CONFIGURATION
--------------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'service_assignments'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.service_assignments;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'service_requests'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.service_requests;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'agent_locations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.agent_locations;
    END IF;
END $$;

--------------------------------------------------------------------------------
-- 8. EXECUTE GRANTS AND SECURITY RESTRICTIONS
--------------------------------------------------------------------------------
-- Revoke all permissions from anon and public on sensitive dispatch functions
REVOKE ALL ON FUNCTION public._dispatch_service_request_internal(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.dispatch_service_request(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_service_offer(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_service_offer(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.expire_stale_service_offers() FROM PUBLIC, anon;

-- Grant EXECUTE only to authenticated users on public RPC endpoints
GRANT EXECUTE ON FUNCTION public.dispatch_service_request(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_service_offer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_service_offer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expire_stale_service_offers() TO authenticated;
