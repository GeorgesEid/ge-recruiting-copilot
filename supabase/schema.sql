-- =====================================================================
--  GE Recruiting Copilot - database (Supabase / Postgres)
--  Paste ALL of this into Supabase > SQL Editor > New query > Run.
--  Safe to run again: it only creates what is missing / replaces functions.
-- =====================================================================

-- Roles: one per client call. Nothing is shared until status = 'open' (recruiter approved).
create table if not exists roles (
  id           bigint generated always as identity primary key,
  client       text,
  title        text,
  transcript   text not null,
  jd           jsonb,                -- the structured job description
  jd_text      text,                 -- the same, as readable text
  search_query text,                 -- plain-English "who are we looking for", used to build the shortlist
  status       text not null default 'pending_approval',   -- pending_approval | open | rejected
  slack_ts     text,
  decided_by   text,
  decided_at   timestamptz,
  created_at   timestamptz not null default now()
);

-- Candidates: ONE row per person, always holding their newest CV.
create table if not exists candidates (
  id               bigint generated always as identity primary key,
  email            text unique,
  name             text not null,
  phone            text,
  location         text,
  headline         text,
  languages        text,
  skills           text,
  years_experience numeric,
  cv_date          text,             -- YYYY-MM: "last updated" on the CV (or newest job date)
  cv_file          text not null,    -- the file every recommendation cites
  cv_text          text not null,    -- full text read from the CV (also from scans)
  jobs             jsonb,            -- [{title, company, start, end, tools[]}]: code computes years per tool from these
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
alter table candidates add column if not exists jobs jsonb;

-- Every file ever received, and what happened to it. Nothing is silently skipped.
create table if not exists cv_files (
  id           bigint generated always as identity primary key,
  file_name    text not null,
  outcome      text not null,        -- new | updated | duplicate | older_ignored | unreadable
  candidate_id bigint references candidates(id),
  detail       text,
  received_at  timestamptz not null default now()
);

-- Shortlist per role: top 5 with score + reason + CV file. Recruiter approves each one.
create table if not exists shortlists (
  id           bigint generated always as identity primary key,
  role_id      bigint not null references roles(id),
  candidate_id bigint not null references candidates(id),
  rank         int,
  score        int,
  reason       text,
  cv_file      text,
  status       text not null default 'suggested',          -- suggested | approved | skipped
  decided_by   text,
  decided_at   timestamptz,
  created_at   timestamptz not null default now(),
  unique (role_id, candidate_id)
);

-- Results of the 10-question test page.
create table if not exists test_runs (
  id      bigint generated always as identity primary key,
  ran_at  timestamptz not null default now(),
  score   int not null,
  total   int not null,
  details jsonb not null
);

-- Settings read by n8n at run time (keeps the Slack signing secret out of the workflow files).
create table if not exists settings (
  key   text primary key,
  value text not null
);

-- Only the server (service_role key) may read or write. The browser never gets a key.
alter table settings   enable row level security;
alter table roles      enable row level security;
alter table candidates enable row level security;
alter table cv_files   enable row level security;
alter table shortlists enable row level security;
alter table test_runs  enable row level security;

-- ---------------------------------------------------------------------
-- ingest_cv: decides what a newly read CV means.
--   same email (or same name + phone) = same person
--   newer CV date  -> 'updated'       (replaces the old CV everywhere)
--   older CV date  -> 'older_ignored' (we keep the newer one)
--   same date      -> 'duplicate'     (kept once)
--   not readable   -> 'unreadable'    (logged + flagged in Slack by n8n)
-- ---------------------------------------------------------------------
create or replace function ingest_cv(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  c        candidates;
  v_email  text := nullif(lower(trim(coalesce(p->>'email', ''))), '');
  v_phone  text := regexp_replace(coalesce(p->>'phone', ''), '\D', '', 'g');
  v_date   text := coalesce(p->>'cv_date', '');
  v_out    text;
  v_id     bigint;
  v_detail text;
begin
  if coalesce((p->>'readable')::boolean, false) = false then
    insert into cv_files (file_name, outcome, detail) values (p->>'file_name', 'unreadable', p->>'reason');
    return jsonb_build_object('outcome', 'unreadable', 'file_name', p->>'file_name', 'reason', p->>'reason');
  end if;

  select * into c from candidates
   where (v_email is not null and email = v_email)
      or (length(v_phone) >= 7 and lower(name) = lower(p->>'name')
          and regexp_replace(coalesce(phone, ''), '\D', '', 'g') = v_phone)
   order by id limit 1;

  if not found then
    insert into candidates (email, name, phone, location, headline, languages, skills, years_experience, cv_date, cv_file, cv_text, jobs)
    values (v_email, p->>'name', p->>'phone', p->>'location', p->>'headline', p->>'languages', p->>'skills',
            nullif(p->>'years_experience', '')::numeric, v_date, p->>'file_name', p->>'full_text', p->'jobs')
    returning id into v_id;
    v_out := 'new'; v_detail := 'new candidate';
  elsif v_date > coalesce(c.cv_date, '') then
    update candidates set name = p->>'name', phone = p->>'phone', location = p->>'location', headline = p->>'headline',
           languages = p->>'languages', skills = p->>'skills', years_experience = nullif(p->>'years_experience', '')::numeric,
           cv_date = v_date, cv_file = p->>'file_name', cv_text = p->>'full_text', jobs = p->'jobs', updated_at = now()
     where id = c.id;
    v_id := c.id; v_out := 'updated'; v_detail := 'replaced older CV ' || c.cv_file || ' (' || coalesce(c.cv_date, '?') || ')';
  elsif v_date < coalesce(c.cv_date, '') then
    v_id := c.id; v_out := 'older_ignored'; v_detail := 'kept newer CV ' || c.cv_file || ' (' || c.cv_date || ')';
  else
    v_id := c.id; v_out := 'duplicate'; v_detail := 'same person as ' || c.cv_file || ', kept once';
  end if;

  insert into cv_files (file_name, outcome, candidate_id, detail) values (p->>'file_name', v_out, v_id, v_detail);
  return jsonb_build_object('outcome', v_out, 'candidate_id', v_id, 'name', p->>'name', 'detail', v_detail);
end $$;

-- Approve / reject a job description exactly once (a double click changes nothing).
create or replace function decide_role(p_role bigint, p_status text, p_by text) returns setof roles
language sql security definer set search_path = public as $$
  update roles set status = p_status, decided_by = p_by, decided_at = now()
   where id = p_role and status = 'pending_approval'
  returning *;
$$;

-- Approve / skip a shortlisted candidate exactly once.
create or replace function decide_candidate(p_role bigint, p_candidate bigint, p_status text, p_by text) returns jsonb
language sql security definer set search_path = public as $$
  with u as (
    update shortlists set status = p_status, decided_by = p_by, decided_at = now()
     where role_id = p_role and candidate_id = p_candidate and status = 'suggested'
    returning *)
  select jsonb_build_object('changed', u.id is not null, 'shortlist_id', s.id, 'status', s.status,
           'decided_by', coalesce(u.decided_by, s.decided_by), 'score', s.score, 'reason', s.reason, 'cv_file', s.cv_file,
           'candidate_id', c.id, 'name', c.name, 'email', c.email, 'role_id', r.id, 'role_title', r.title, 'client', r.client)
    from shortlists s join candidates c on c.id = s.candidate_id join roles r on r.id = s.role_id
    left join u on u.id = s.id
   where s.role_id = p_role and s.candidate_id = p_candidate;
$$;

-- Developer helper so Claude can apply later fixes without another copy-paste.
-- Only the service_role key can call it. Remove before handing over to a real client: drop function ge_exec_sql(text);
create or replace function ge_exec_sql(q text) returns void
language plpgsql security definer set search_path = public as $$ begin execute q; end $$;

revoke all on function ingest_cv(jsonb), decide_role(bigint, text, text), decide_candidate(bigint, bigint, text, text), ge_exec_sql(text) from public, anon, authenticated;
grant execute on function ingest_cv(jsonb), decide_role(bigint, text, text), decide_candidate(bigint, bigint, text, text), ge_exec_sql(text) to service_role;
