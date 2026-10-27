-- fitness_plan 000: baseline snapshot of the schema, generated from the live catalog on 2026-10-27
-- (the original migrations were applied outside this folder). Used to recreate the app in the
-- ca-central-1 project. Depends only on auth.users.

create schema fitness_plan;
comment on schema fitness_plan is 'Fitness plan app: API tables (exposed via the Data API).';
create schema fitness_plan_private;
comment on schema fitness_plan_private is 'Fitness plan app: functions and staging data (never exposed).';

create table fitness_plan.programs (
  id uuid default gen_random_uuid() not null,
  slug text not null,
  title text not null,
  subtitle text,
  coach text,
  start_date date,
  end_date date,
  source_file text,
  notes jsonb default '[]'::jsonb not null,
  created_at timestamp with time zone default now() not null
);
create table fitness_plan.program_days (
  id uuid default gen_random_uuid() not null,
  program_id uuid not null,
  "position" integer not null,
  title text not null,
  focus text,
  format text default 'circuit'::text not null,
  rounds integer default 1 not null,
  rest_min_seconds integer,
  rest_max_seconds integer,
  note text
);
create table fitness_plan.exercises (
  id uuid default gen_random_uuid() not null,
  slug text not null,
  code text,
  name text not null,
  equipment text,
  muscles text[] default '{}'::text[] not null,
  key_points text[] default '{}'::text[] not null,
  source_url text,
  media jsonb default '{}'::jsonb not null,
  media_fetched_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);
create table fitness_plan.day_exercises (
  id uuid default gen_random_uuid() not null,
  day_id uuid not null,
  exercise_id uuid not null,
  "position" integer not null,
  sets integer default 1 not null,
  target_type text default 'reps'::text not null,
  target_reps integer,
  target_seconds integer,
  measure text default 'weight_reps'::text not null,
  note text
);
create table fitness_plan.workout_sessions (
  id uuid default gen_random_uuid() not null,
  user_id uuid default auth.uid() not null,
  program_id uuid not null,
  day_id uuid not null,
  started_at timestamp with time zone default now() not null,
  finished_at timestamp with time zone,
  notes text
);
create table fitness_plan.set_logs (
  id uuid default gen_random_uuid() not null,
  user_id uuid default auth.uid() not null,
  session_id uuid not null,
  day_exercise_id uuid not null,
  exercise_id uuid not null,
  set_number integer not null,
  weight numeric(6,2),
  band text,
  reps integer,
  seconds integer,
  done_at timestamp with time zone default now() not null
);
create table fitness_plan.user_settings (
  user_id uuid default auth.uid() not null,
  active_program_id uuid,
  rest_seconds integer default 120 not null,
  updated_at timestamp with time zone default now() not null
);
create table fitness_plan_private.scraped_pages (
  url text not null,
  status integer,
  html text
);

alter table fitness_plan.programs add constraint programs_pkey PRIMARY KEY (id);
alter table fitness_plan.programs add constraint programs_slug_key UNIQUE (slug);
alter table fitness_plan.program_days add constraint program_days_pkey PRIMARY KEY (id);
alter table fitness_plan.program_days add constraint program_days_program_id_position_key UNIQUE (program_id, "position");
alter table fitness_plan.program_days add constraint program_days_format_check CHECK ((format = ANY (ARRAY['circuit'::text, 'straight'::text])));
alter table fitness_plan.exercises add constraint exercises_pkey PRIMARY KEY (id);
alter table fitness_plan.exercises add constraint exercises_slug_key UNIQUE (slug);
alter table fitness_plan.day_exercises add constraint day_exercises_pkey PRIMARY KEY (id);
alter table fitness_plan.day_exercises add constraint day_exercises_day_id_position_key UNIQUE (day_id, "position");
alter table fitness_plan.day_exercises add constraint day_exercises_measure_check CHECK ((measure = ANY (ARRAY['weight_reps'::text, 'band_reps'::text, 'reps'::text, 'time'::text])));
alter table fitness_plan.day_exercises add constraint day_exercises_target_type_check CHECK ((target_type = ANY (ARRAY['reps'::text, 'failure'::text, 'time'::text])));
alter table fitness_plan.workout_sessions add constraint workout_sessions_pkey PRIMARY KEY (id);
alter table fitness_plan.set_logs add constraint set_logs_pkey PRIMARY KEY (id);
alter table fitness_plan.set_logs add constraint set_logs_session_id_day_exercise_id_set_number_key UNIQUE (session_id, day_exercise_id, set_number);
alter table fitness_plan.user_settings add constraint user_settings_pkey PRIMARY KEY (user_id);
alter table fitness_plan_private.scraped_pages add constraint pages_pkey PRIMARY KEY (url);

alter table fitness_plan.program_days add constraint program_days_program_id_fkey FOREIGN KEY (program_id) REFERENCES fitness_plan.programs(id) ON DELETE CASCADE;
alter table fitness_plan.day_exercises add constraint day_exercises_day_id_fkey FOREIGN KEY (day_id) REFERENCES fitness_plan.program_days(id) ON DELETE CASCADE;
alter table fitness_plan.day_exercises add constraint day_exercises_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES fitness_plan.exercises(id);
alter table fitness_plan.workout_sessions add constraint workout_sessions_day_id_fkey FOREIGN KEY (day_id) REFERENCES fitness_plan.program_days(id);
alter table fitness_plan.workout_sessions add constraint workout_sessions_program_id_fkey FOREIGN KEY (program_id) REFERENCES fitness_plan.programs(id);
alter table fitness_plan.workout_sessions add constraint workout_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table fitness_plan.set_logs add constraint set_logs_day_exercise_id_fkey FOREIGN KEY (day_exercise_id) REFERENCES fitness_plan.day_exercises(id);
alter table fitness_plan.set_logs add constraint set_logs_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES fitness_plan.exercises(id);
alter table fitness_plan.set_logs add constraint set_logs_session_id_fkey FOREIGN KEY (session_id) REFERENCES fitness_plan.workout_sessions(id) ON DELETE CASCADE;
alter table fitness_plan.set_logs add constraint set_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table fitness_plan.user_settings add constraint user_settings_active_program_id_fkey FOREIGN KEY (active_program_id) REFERENCES fitness_plan.programs(id) ON DELETE SET NULL;
alter table fitness_plan.user_settings add constraint user_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE INDEX day_exercises_exercise_id_idx ON fitness_plan.day_exercises USING btree (exercise_id);
CREATE INDEX set_logs_day_exercise_id_idx ON fitness_plan.set_logs USING btree (day_exercise_id);
CREATE INDEX set_logs_exercise_id_idx ON fitness_plan.set_logs USING btree (exercise_id);
CREATE INDEX set_logs_user_id_exercise_id_done_at_idx ON fitness_plan.set_logs USING btree (user_id, exercise_id, done_at DESC);
CREATE INDEX user_settings_active_program_id_idx ON fitness_plan.user_settings USING btree (active_program_id);
CREATE INDEX workout_sessions_day_id_idx ON fitness_plan.workout_sessions USING btree (day_id);
CREATE INDEX workout_sessions_program_id_idx ON fitness_plan.workout_sessions USING btree (program_id);
CREATE INDEX workout_sessions_user_id_started_at_idx ON fitness_plan.workout_sessions USING btree (user_id, started_at DESC);

CREATE OR REPLACE FUNCTION fitness_plan_private.import_program(doc jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_program_id uuid;
  v_day_id uuid;
  v_day jsonb;
  v_ex jsonb;
  v_day_pos int := 0;
  v_ex_pos int;
begin
  insert into fitness_plan.programs (slug, title, subtitle, coach, start_date, end_date, source_file, notes)
  values (doc->>'slug', doc->>'title', doc->>'subtitle', doc->>'coach',
          (doc->>'start_date')::date, (doc->>'end_date')::date, doc->>'source_file',
          coalesce(doc->'notes', '[]'::jsonb))
  on conflict (slug) do update set title = excluded.title, subtitle = excluded.subtitle, coach = excluded.coach,
    start_date = excluded.start_date, end_date = excluded.end_date, source_file = excluded.source_file, notes = excluded.notes
  returning id into v_program_id;

  for v_day in select value from jsonb_array_elements(doc->'days') loop
    v_day_pos := v_day_pos + 1;
    insert into fitness_plan.program_days (program_id, position, title, focus, format, rounds, rest_min_seconds, rest_max_seconds, note)
    values (v_program_id, v_day_pos, v_day->>'title', v_day->>'focus', coalesce(v_day->>'format', 'circuit'),
            coalesce((v_day->>'rounds')::int, 1), (v_day->>'rest_min_seconds')::int, (v_day->>'rest_max_seconds')::int, v_day->>'note')
    on conflict (program_id, position) do update set title = excluded.title, focus = excluded.focus, format = excluded.format,
      rounds = excluded.rounds, rest_min_seconds = excluded.rest_min_seconds, rest_max_seconds = excluded.rest_max_seconds, note = excluded.note
    returning id into v_day_id;

    v_ex_pos := 0;
    for v_ex in select value from jsonb_array_elements(v_day->'exercises') loop
      v_ex_pos := v_ex_pos + 1;
      insert into fitness_plan.exercises (slug, code, name, equipment, muscles, key_points, source_url)
      values (v_ex->>'slug', v_ex->>'code', v_ex->>'name', v_ex->>'equipment',
              coalesce(array(select jsonb_array_elements_text(v_ex->'muscles')), '{}'),
              coalesce(array(select jsonb_array_elements_text(v_ex->'key_points')), '{}'),
              v_ex->>'url')
      on conflict (slug) do update set code = excluded.code, name = excluded.name, equipment = excluded.equipment,
        muscles = excluded.muscles, key_points = excluded.key_points, source_url = excluded.source_url;

      insert into fitness_plan.day_exercises (day_id, exercise_id, position, sets, target_type, target_reps, target_seconds, measure, note)
      select v_day_id, e.id, v_ex_pos, coalesce((v_ex->>'sets')::int, (v_day->>'rounds')::int, 1),
             coalesce(v_ex->>'target_type', 'reps'), (v_ex->>'target_reps')::int, (v_ex->>'target_seconds')::int,
             coalesce(v_ex->>'measure', 'weight_reps'), v_ex->>'note'
      from fitness_plan.exercises e where e.slug = v_ex->>'slug'
      on conflict (day_id, position) do update set exercise_id = excluded.exercise_id, sets = excluded.sets,
        target_type = excluded.target_type, target_reps = excluded.target_reps, target_seconds = excluded.target_seconds,
        measure = excluded.measure, note = excluded.note;
    end loop;
  end loop;

  return v_program_id;
end;
$function$;

alter table fitness_plan.programs enable row level security;
alter table fitness_plan.program_days enable row level security;
alter table fitness_plan.exercises enable row level security;
alter table fitness_plan.day_exercises enable row level security;
alter table fitness_plan.workout_sessions enable row level security;
alter table fitness_plan.set_logs enable row level security;
alter table fitness_plan.user_settings enable row level security;
alter table fitness_plan_private.scraped_pages enable row level security;

create policy "catalog readable" on fitness_plan.programs for select to authenticated using (true);
create policy "catalog readable" on fitness_plan.program_days for select to authenticated using (true);
create policy "catalog readable" on fitness_plan.exercises for select to authenticated using (true);
create policy "catalog readable" on fitness_plan.day_exercises for select to authenticated using (true);
create policy "own sessions" on fitness_plan.workout_sessions for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own sets" on fitness_plan.set_logs for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "own settings" on fitness_plan.user_settings for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

revoke all on schema fitness_plan_private from public;
revoke execute on function fitness_plan_private.import_program(jsonb) from public;
grant usage on schema fitness_plan to authenticated, service_role;
grant select on fitness_plan.programs, fitness_plan.program_days, fitness_plan.exercises, fitness_plan.day_exercises to authenticated;
grant select, insert, update, delete on fitness_plan.workout_sessions, fitness_plan.set_logs, fitness_plan.user_settings to authenticated;
grant all on all tables in schema fitness_plan to service_role;
