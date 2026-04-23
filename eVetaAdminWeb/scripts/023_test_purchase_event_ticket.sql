-- 023_test_purchase_event_ticket.sql
-- Compra de prueba sin pago para QA en app cliente.

create or replace function public.test_purchase_event_ticket(
  p_ticket_type_id uuid,
  p_quantity integer default 1
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid;
  v_type record;
  v_ticket_id uuid;
  v_qty int;
  v_created int := 0;
  v_benefit jsonb;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Debes iniciar sesión.';
  end if;

  select *
  into v_type
  from public.event_ticket_types
  where id = p_ticket_type_id
    and is_active = true
  for update;

  if not found then
    raise exception 'Tipo de entrada no disponible.';
  end if;

  for v_qty in 1..greatest(coalesce(p_quantity, 1), 1) loop
    insert into public.event_tickets (
      event_id,
      ticket_type_id,
      user_id,
      qr_token,
      people_count,
      used_people,
      status
    ) values (
      v_type.event_id,
      v_type.id,
      v_user_id,
      md5(random()::text || clock_timestamp()::text || v_user_id::text || v_qty::text),
      v_type.people_count,
      0,
      'active'
    )
    returning id into v_ticket_id;

    for v_benefit in
      select * from jsonb_array_elements(coalesce(v_type.benefits, '[]'::jsonb))
    loop
      insert into public.ticket_benefits (
        ticket_id,
        benefit_type,
        total,
        used,
        state
      ) values (
        v_ticket_id,
        coalesce(v_benefit->>'type', 'beneficio'),
        greatest(coalesce((v_benefit->>'total')::int, 0), 0),
        0,
        'blocked'
      );
    end loop;

    perform public.event_set_benefits_state(v_ticket_id);
    v_created := v_created + 1;
  end loop;

  update public.event_ticket_types
  set sold_count = sold_count + v_created
  where id = v_type.id;

  return v_created;
end;
$$;

revoke all on function public.test_purchase_event_ticket(uuid, integer) from public;
grant execute on function public.test_purchase_event_ticket(uuid, integer) to authenticated;
