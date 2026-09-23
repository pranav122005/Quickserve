-- Public registration supports Customer and Agent only. Admin is never a
-- client-selectable role and must continue to be provisioned by an operator.
BEGIN;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
SECURITY DEFINER
SET search_path = public, extensions
LANGUAGE plpgsql
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
    INSERT INTO public.agent_profiles (
      user_id, service_radius_km, availability, is_verified
    ) VALUES (
      new.id, 15, 'offline'::public.agent_availability, false
    );
  END IF;

  RETURN new;
END;
$$;

COMMIT;
