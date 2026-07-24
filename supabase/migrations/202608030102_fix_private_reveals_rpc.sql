CREATE OR REPLACE FUNCTION public.get_my_active_private_reveals(p_match_id uuid)
RETURNS SETOF public.match_private_reveals
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid := auth.uid();
BEGIN
    RETURN QUERY
    SELECT r.* FROM public.match_private_reveals r
    WHERE r.match_id = p_match_id AND r.user_id = v_user_id
    ORDER BY r.revealed_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_my_active_private_reveals(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_active_private_reveals(uuid) TO anon;
