-- 021_events_qr_business_functions.sql
-- Lógica transaccional para emisión de tickets y escaneo de entradas/beneficios.

create or replace function public.event_set_benefits_state(p_ticket_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_people_count int;
  v_used_people int;
  v_state public.ticket_benefit_state;
begin
  select people_count, used_people
  into v_people_count, v_used_people
  from public.event_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'Ticket no encontrado';
  end if;

  if v_used_people < v_people_count then
    v_state := 'blocked';
  elsif exists (
    select 1
    from public.ticket_benefits b
    where b.ticket_id = p_ticket_id
      and b.used < b.total
  ) then
    v_state := 'active';
  else
    v_state := 'complete';
  end if;

  update public.ticket_benefits
  set state = case
    when used >= total then 'complete'
    else v_state
  end
  where ticket_id = p_ticket_id;
end;
$$;

create or replace function public.issue_tickets_on_order_paid(p_order_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_item record;
  v_ticket_type record;
  v_ticket_id uuid;
  v_qty int;
  v_issued int := 0;
  v_benefit jsonb;
begin
  select id, buyer_id
  into v_order
  from public.orders
  where id = p_order_id;

  if not found then
    raise exception 'Orden no encontrada';
  end if;

  for v_item in
    select oi.id, oi.quantity, oi.product_id, p.event_ticket_type_id
    from public.order_items oi
    join public.products p on p.id = oi.product_id
    where oi.order_id = p_order_id
      and p.event_ticket_type_id is not null
  loop
    select *
    into v_ticket_type
    from public.event_ticket_types
    where id = v_item.event_ticket_type_id
      and is_active = true
    for update;

    if not found then
      raise exception 'Tipo de ticket no válido';
    end if;

    for v_qty in 1..greatest(v_item.quantity, 0) loop
      insert into public.event_tickets (
        event_id,
        ticket_type_id,
        user_id,
        order_id,
        qr_token,
        people_count,
        used_people,
        status
      ) values (
        v_ticket_type.event_id,
        v_ticket_type.id,
        v_order.buyer_id,
        p_order_id,
        md5(
          random()::text
          || clock_timestamp()::text
          || v_order.buyer_id::text
          || p_order_id::text
          || v_qty::text
        ),
        v_ticket_type.people_count,
        0,
        'active'
      )
      returning id into v_ticket_id;

      for v_benefit in
        select * from jsonb_array_elements(coalesce(v_ticket_type.benefits, '[]'::jsonb))
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
      v_issued := v_issued + 1;
    end loop;

    update public.event_ticket_types
    set sold_count = sold_count + v_item.quantity
    where id = v_ticket_type.id;
  end loop;

  return v_issued;
end;
$$;

create or replace function public.consume_ticket_entry(
  p_qr_token text,
  p_quantity integer default 1
)
returns table (
  ticket_id uuid,
  used_people integer,
  people_count integer,
  benefits_state text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket record;
  v_add int;
begin
  if not public.profile_is_staff() then
    raise exception 'Sin permiso para escaneo';
  end if;

  v_add := greatest(coalesce(p_quantity, 1), 1);

  select *
  into v_ticket
  from public.event_tickets
  where qr_token = p_qr_token
    and status = 'active'
  for update;

  if not found then
    raise exception 'Ticket inválido o inactivo';
  end if;

  if v_ticket.used_people + v_add > v_ticket.people_count then
    raise exception 'El escaneo excede el cupo de personas';
  end if;

  update public.event_tickets
  set used_people = used_people + v_add,
      status = case when used_people + v_add >= people_count then 'completed' else status end
  where id = v_ticket.id;

  insert into public.ticket_action_logs (
    ticket_id,
    action_type,
    quantity,
    actor_user_id,
    action_meta
  ) values (
    v_ticket.id,
    'entry',
    v_add,
    auth.uid(),
    jsonb_build_object('source', 'scanner')
  );

  perform public.event_set_benefits_state(v_ticket.id);

  return query
  select
    t.id,
    t.used_people,
    t.people_count,
    (
      select case
        when count(*) filter (where b.state = 'active') > 0 then 'active'
        when count(*) filter (where b.state = 'blocked') > 0 then 'blocked'
        else 'complete'
      end
      from public.ticket_benefits b
      where b.ticket_id = t.id
    ) as benefits_state
  from public.event_tickets t
  where t.id = v_ticket.id;
end;
$$;

create or replace function public.consume_ticket_benefit(
  p_qr_token text,
  p_benefit_type text,
  p_quantity integer default 1
)
returns table (
  ticket_id uuid,
  benefit_type text,
  used integer,
  total integer,
  state text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ticket record;
  v_benefit record;
  v_add int;
begin
  if not public.profile_is_staff() then
    raise exception 'Sin permiso para canje';
  end if;

  v_add := greatest(coalesce(p_quantity, 1), 1);

  select *
  into v_ticket
  from public.event_tickets
  where qr_token = p_qr_token
  for update;

  if not found then
    raise exception 'Ticket inválido';
  end if;

  select *
  into v_benefit
  from public.ticket_benefits
  where ticket_id = v_ticket.id
    and benefit_type = p_benefit_type
  for update;

  if not found then
    raise exception 'Beneficio no encontrado';
  end if;

  if v_benefit.state = 'blocked' then
    raise exception 'Beneficio bloqueado hasta ingreso completo';
  end if;

  if v_benefit.used + v_add > v_benefit.total then
    raise exception 'Canje excede total permitido';
  end if;

  update public.ticket_benefits
  set used = used + v_add,
      state = case when used + v_add >= total then 'complete' else state end
  where id = v_benefit.id;

  insert into public.ticket_action_logs (
    ticket_id,
    action_type,
    benefit_type,
    quantity,
    actor_user_id,
    action_meta
  ) values (
    v_ticket.id,
    'benefit',
    v_benefit.benefit_type,
    v_add,
    auth.uid(),
    jsonb_build_object('source', 'scanner')
  );

  perform public.event_set_benefits_state(v_ticket.id);

  return query
  select
    b.ticket_id,
    b.benefit_type,
    b.used,
    b.total,
    b.state::text
  from public.ticket_benefits b
  where b.id = v_benefit.id;
end;
$$;

create or replace function public.get_ticket_scan_state(
  p_qr_token text
)
returns table (
  ticket_id uuid,
  event_name text,
  owner_name text,
  people_count integer,
  used_people integer,
  benefits jsonb
)
language sql
security definer
set search_path = public
stable
as $$
  select
    t.id as ticket_id,
    e.name as event_name,
    coalesce(p.full_name, p.username, p.email, 'Usuario') as owner_name,
    t.people_count,
    t.used_people,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', b.id,
            'type', b.benefit_type,
            'total', b.total,
            'used', b.used,
            'state', b.state
          )
          order by b.created_at
        )
        from public.ticket_benefits b
        where b.ticket_id = t.id
      ),
      '[]'::jsonb
    ) as benefits
  from public.event_tickets t
  join public.events e on e.id = t.event_id
  left join public.profiles p on p.id = t.user_id
  where t.qr_token = p_qr_token;
$$;

revoke all on function public.event_set_benefits_state(uuid) from public;
revoke all on function public.issue_tickets_on_order_paid(uuid) from public;
revoke all on function public.consume_ticket_entry(text, integer) from public;
revoke all on function public.consume_ticket_benefit(text, text, integer) from public;
revoke all on function public.get_ticket_scan_state(text) from public;

grant execute on function public.issue_tickets_on_order_paid(uuid) to authenticated;
grant execute on function public.consume_ticket_entry(text, integer) to authenticated;
grant execute on function public.consume_ticket_benefit(text, text, integer) to authenticated;
grant execute on function public.get_ticket_scan_state(text) to authenticated;
