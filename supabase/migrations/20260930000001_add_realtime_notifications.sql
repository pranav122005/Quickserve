-- Migration: Add Realtime Notifications & Triggers
-- ------------------------------------------------------------
-- 1. NOTIFICATIONS TABLE
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

-- Indexes for fast queries & RLS
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(user_id, is_read);

-- Enable & Force RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications FORCE ROW LEVEL SECURITY;

-- ------------------------------------------------------------
-- 2. RLS POLICIES (PRIVATE TO USER)
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "notifications_select_self" ON public.notifications;
CREATE POLICY "notifications_select_self" ON public.notifications
    FOR SELECT TO authenticated USING (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_update_self" ON public.notifications;
CREATE POLICY "notifications_update_self" ON public.notifications
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "notifications_insert_authenticated" ON public.notifications;
CREATE POLICY "notifications_insert_authenticated" ON public.notifications
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- ------------------------------------------------------------
-- 3. HELPER FUNCTION TO SAFELY INSERT NOTIFICATIONS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_notification(
    p_user_id uuid,
    p_request_id uuid,
    p_type text,
    p_title text,
    p_body text
)
RETURNS uuid
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_id uuid;
BEGIN
    INSERT INTO public.notifications (user_id, request_id, type, title, body)
    VALUES (p_user_id, p_request_id, p_type, p_title, p_body)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

-- ------------------------------------------------------------
-- 4. AUTOMATIC DATABASE TRIGGERS FOR LIFECYCLE NOTIFICATIONS
-- ------------------------------------------------------------

-- Trigger on service_requests status & ETA changes
CREATE OR REPLACE FUNCTION public.trg_fn_service_request_notifications()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_agent_user_id uuid;
    v_admin_rec RECORD;
BEGIN
    -- 1. New Request Created -> Notify Admins
    IF (TG_OP = 'INSERT') THEN
        FOR v_admin_rec IN SELECT id FROM public.profiles WHERE role = 'admin' LOOP
            PERFORM public.create_notification(
                v_admin_rec.id,
                NEW.id,
                'new_request',
                'New Service Request',
                'New ' || COALESCE(NEW.category, 'service') || ' request created (' || NEW.formatted_id || ').'
            );
        END LOOP;
        RETURN NEW;
    END IF;

    IF (TG_OP = 'UPDATE') THEN
        -- Get assigned agent user ID if available
        SELECT agent_id INTO v_agent_user_id
        FROM public.service_assignments
        WHERE request_id = NEW.id AND status IN ('offered', 'accepted')
        ORDER BY created_at DESC LIMIT 1;

        -- ETA Changed -> Notify Customer
        IF (OLD.estimated_arrival IS DISTINCT FROM NEW.estimated_arrival AND NEW.estimated_arrival IS NOT NULL) THEN
            PERFORM public.create_notification(
                NEW.customer_id,
                NEW.id,
                'eta_updated',
                'ETA Updated',
                'Your service agent is estimated to arrive at ' || to_char(NEW.estimated_arrival, 'HH12:MI AM') || '.'
            );
        END IF;

        -- Status Changed Notifications
        IF (OLD.status IS DISTINCT FROM NEW.status) THEN
            -- Service Started -> Notify Customer
            IF (NEW.status = 'in_progress') THEN
                PERFORM public.create_notification(
                    NEW.customer_id,
                    NEW.id,
                    'service_started',
                    'Service Started',
                    'Your service agent has started the service for ' || NEW.title || '.'
                );
            END IF;

            -- Service Completed -> Notify Customer
            IF (NEW.status = 'completed') THEN
                PERFORM public.create_notification(
                    NEW.customer_id,
                    NEW.id,
                    'service_completed',
                    'Service Completed',
                    'Your service request (' || NEW.formatted_id || ') has been completed.'
                );
            END IF;

            -- Request Cancelled -> Notify Customer and Agent
            IF (NEW.status = 'cancelled') THEN
                PERFORM public.create_notification(
                    NEW.customer_id,
                    NEW.id,
                    'request_cancelled',
                    'Request Cancelled',
                    'Service request (' || NEW.formatted_id || ') has been cancelled.'
                );
                IF (v_agent_user_id IS NOT NULL) THEN
                    PERFORM public.create_notification(
                        v_agent_user_id,
                        NEW.id,
                        'request_cancelled',
                        'Request Cancelled',
                        'Customer cancelled service request (' || NEW.formatted_id || ').'
                    );
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_request_notifications ON public.service_requests;
CREATE TRIGGER trg_service_request_notifications
AFTER INSERT OR UPDATE ON public.service_requests
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_service_request_notifications();


-- Trigger on service_assignments (offers & acceptance & admin assignment)
CREATE OR REPLACE FUNCTION public.trg_fn_service_assignment_notifications()
RETURNS trigger
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id uuid;
    v_req_title text;
    v_agent_name text;
BEGIN
    SELECT customer_id, title INTO v_customer_id, v_req_title
    FROM public.service_requests
    WHERE id = NEW.request_id;

    SELECT full_name INTO v_agent_name
    FROM public.profiles
    WHERE id = NEW.agent_id;

    -- New Offer -> Notify Agent
    IF (TG_OP = 'INSERT' AND NEW.status = 'offered') THEN
        PERFORM public.create_notification(
            NEW.agent_id,
            NEW.request_id,
            'new_offer',
            'New Service Offer',
            'You have a new service offer for ' || COALESCE(v_req_title, 'a request') || '.'
        );
        PERFORM public.create_notification(
            v_customer_id,
            NEW.request_id,
            'agent_assigned',
            'Agent Assigned',
            'Service agent ' || COALESCE(v_agent_name, 'an agent') || ' has been assigned to your request.'
        );
    END IF;

    -- Agent Accepted -> Notify Customer
    IF (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted') THEN
        PERFORM public.create_notification(
            v_customer_id,
            NEW.request_id,
            'agent_accepted',
            'Agent Accepted',
            'Service agent ' || COALESCE(v_agent_name, 'an agent') || ' accepted your service request!'
        );
        PERFORM public.create_notification(
            NEW.agent_id,
            NEW.request_id,
            'request_assigned',
            'Job Confirmed',
            'Service request ' || COALESCE(v_req_title, '') || ' confirmed. Tap to view navigation map.'
        );
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_service_assignment_notifications ON public.service_assignments;
CREATE TRIGGER trg_service_assignment_notifications
AFTER INSERT OR UPDATE ON public.service_assignments
FOR EACH ROW EXECUTE FUNCTION public.trg_fn_service_assignment_notifications();
