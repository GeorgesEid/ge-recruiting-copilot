// GE Recruiting Copilot portal. Talks only to /api/* (no keys in the browser).
const $ = (s) => document.querySelector(s);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const when = (d) => (d ? new Date(d).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '');
const slack = (s) => esc(s).replace(/\*([^*\n]+)\*/g, '<b>$1</b>');   // Slack-style *bold* in job descriptions
let DATA = null;

// ---------- tabs (remembered per browser) ----------
function show(tab) {
  document.querySelectorAll('nav button').forEach((b) => b.classList.toggle('on', b.dataset.tab === tab));
  document.querySelectorAll('.tab').forEach((s) => s.classList.toggle('on', s.id === tab));
  try { localStorage.setItem('ge-rc-tab', tab); } catch (e) { /* private mode */ }
}
document.querySelectorAll('nav button').forEach((b) => b.addEventListener('click', () => show(b.dataset.tab)));
try { const t = localStorage.getItem('ge-rc-tab'); if (t && document.getElementById(t)) show(t); } catch (e) { /* private mode */ }

// ---------- passcode for actions that change data or cost AI money ----------
async function act(action, extra = {}) {
  let pass = sessionStorage.getItem('ge-rc-pass');
  if (!pass) { pass = prompt('Recruiter passcode:'); if (!pass) throw new Error('Passcode needed.'); }
  const r = await fetch('/api/action', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action, passcode: pass, ...extra }) });
  const j = await r.json().catch(() => ({ error: 'Unexpected answer from server' }));
  if (r.status === 401) sessionStorage.removeItem('ge-rc-pass'); else sessionStorage.setItem('ge-rc-pass', pass);
  if (!r.ok) throw new Error(j.error || 'Something went wrong');
  return j;
}

// ---------- shared pieces ----------
const scoreCell = (s) => `<span class="score">${s}</span>/100<div class="bar"><i style="width:${s}%"></i></div>`;
function matchTable(matches) {
  return `<div class="tablewrap"><table><thead><tr><th>#</th><th>Candidate</th><th>Score</th><th>Why</th><th>CV it came from</th></tr></thead><tbody>${
    matches.map((m) => `<tr><td>${m.rank}</td><td><b>${esc(m.name)}</b></td><td>${scoreCell(m.score)}</td><td>${esc(m.reason)}</td><td class="file">${esc(m.cv_file)}</td></tr>`).join('')
  }</tbody></table></div>`;
}
const STATUS = {
  pending_approval: ['Waiting for approval in Slack', 'warn'], open: ['Open', 'ok'], rejected: ['Rejected', 'bad'],
  suggested: ['Waiting for recruiter', ''], approved: ['Approved → outreach', 'ok'], skipped: ['Skipped', 'bad'],
};
const badge = (k) => `<span class="badge ${(STATUS[k] || [])[1] || ''}">${esc((STATUS[k] || [k])[0])}</span>`;

// ---------- renderers ----------
function renderRoles() {
  const roles = DATA.roles;
  if (!roles.length) { $('#roleList').innerHTML = '<div class="empty">No roles yet. Add one from a client call transcript in "Add role / CVs".</div>'; return; }
  $('#roleList').innerHTML = roles.map((r) => `
    <div class="card">
      <div class="role-head"><div><h2>${esc(r.title || 'Untitled role')} · ${esc(r.client || '')}</h2>
        <small>Role #${r.id} · created ${when(r.created_at)}${r.decided_by ? ` · ${r.status === 'open' ? 'approved' : 'decided'} by ${esc(r.decided_by)} ${when(r.decided_at)}` : ''}</small></div>${badge(r.status)}</div>
      <details><summary>Job description</summary><div class="jd">${slack(r.jd_text)}</div></details>
      ${r.status !== 'open' ? '' : r.shortlist.length ? `<div class="tablewrap"><table><thead><tr><th>#</th><th>Candidate</th><th>Score</th><th>Why</th><th>CV it came from</th><th>Status</th></tr></thead><tbody>${
        r.shortlist.map((s) => `<tr><td>${s.rank}</td><td><b>${esc(s.candidate && s.candidate.name)}</b><br><small class="why">${esc(s.candidate && s.candidate.location)}</small></td><td>${scoreCell(s.score)}</td><td>${esc(s.reason)}</td><td class="file">${esc(s.cv_file)}</td><td>${badge(s.status)}${s.decided_by ? `<br><small class="why">by ${esc(s.decided_by)}</small>` : ''}</td></tr>`).join('')
      }</tbody></table></div>` : '<div class="empty">No good match in the CV pool for this role. The bot did not invent anyone.</div>'}
    </div>`).join('');
}

function renderPipeline() {
  const p = DATA.pipeline;
  if (!p.ready) { $('#board').innerHTML = `<div class="empty">The GHL pipeline "GE-RC Candidates" was not found yet.${p.error ? ' (' + esc(p.error) + ')' : ''}</div>`; return; }
  $('#board').innerHTML = p.stages.map((s) => `<div class="col"><h3>${esc(s.name)} <span class="badge brand">${s.people.length}</span></h3>${
    s.people.map((x) => `<div class="person"><b>${esc(x.name)}</b><small>${esc(x.deal)}</small><small>${when(x.since)}</small></div>`).join('') || '<small class="why">Nobody yet</small>'
  }</div>`).join('');
}

function renderTest(t) {
  if (!t) { $('#testOut').innerHTML = '<div class="empty">No test run yet.</div><button class="btn" id="runTests">Run the 10 questions now</button>'; }
  else {
    $('#testOut').innerHTML = `
      <div class="kpis"><div class="kpi"><span>Bot score</span><b class="big">${t.score}/${t.total}</b></div>
        <div class="kpi"><span>Last run</span><b style="font-size:16px">${when(t.ran_at)}</b></div></div>
      <p class="hint">PASS = the bot returned exactly the right people, each once. For "no match" questions it must return nobody.</p>
      <button class="btn" id="runTests">Run the 10 questions again</button>
      <div class="tablewrap card" style="margin-top:16px"><table><thead><tr><th>#</th><th>Question</th><th>Right answer</th><th>Bot's answer</th><th>Result</th></tr></thead><tbody>${
        t.details.map((d) => `<tr><td>${d.id}</td><td><b>${esc(d.question)}</b><br><small class="why">${esc(d.why)}</small></td>
          <td>${d.expected.length ? d.expected.map(esc).join('<br>') : '<i>No match: nobody</i>'}</td>
          <td>${d.bot.length ? d.bot.map((b) => `${esc(b.name)} <small class="why">(${b.score}) · ${esc(b.cv_file)}</small>`).join('<br>') : `<i>${esc(d.bot_message || 'Nobody')}</i>`}</td>
          <td>${d.pass ? '<span class="badge ok">PASS</span>' : `<span class="badge bad">FAIL</span>${d.missing.length ? `<br><small class="why">missing: ${esc(d.missing.join(', '))}</small>` : ''}${d.extra.length ? `<br><small class="why">extra: ${esc(d.extra.join(', '))}</small>` : ''}`}</td></tr>`).join('')
      }</tbody></table></div>`;
  }
  $('#runTests').onclick = async (e) => {
    e.target.disabled = true; e.target.textContent = 'Asking the bot 10 questions… (about 30 seconds)';
    try { renderTest(await act('run_tests')); } catch (err) { alert(err.message); e.target.disabled = false; }
  };
}

function renderCvs() {
  const log = DATA.cvLog;
  const count = (o) => log.filter((x) => x.outcome === o).length;
  const flagged = log.filter((x) => x.outcome === 'unreadable');
  const OUT = { new: ['New', 'ok'], updated: ['Updated: replaced older CV', 'brand'], duplicate: ['Duplicate: kept once', ''], older_ignored: ['Older version: newer CV kept', ''], unreadable: ['UNREADABLE: flagged', 'bad'] };
  $('#cvOut').innerHTML = `
    <div class="kpis">
      <div class="kpi"><b>${log.length}</b><span>files received</span></div>
      <div class="kpi"><b>${DATA.candidates.length}</b><span>searchable candidates</span></div>
      <div class="kpi"><b>${count('duplicate')}</b><span>duplicates merged</span></div>
      <div class="kpi"><b>${count('updated') + count('older_ignored')}</b><span>CV updates handled</span></div>
      <div class="kpi"><b style="color:var(--bad)">${flagged.length}</b><span>unreadable, flagged</span></div>
    </div>
    ${flagged.length ? `<div class="card" style="border-color:var(--bad)"><h2>Needs attention: CVs we could not read</h2>${flagged.map((f) => `<p><b class="file">${esc(f.file_name)}</b><br>${esc(f.detail)}</p>`).join('')}</div>` : ''}
    <div class="card"><h2>CV log: every file and what happened to it</h2><div class="tablewrap"><table><thead><tr><th>File</th><th>Result</th><th>Details</th><th>When</th></tr></thead><tbody>${
      log.map((f) => `<tr><td class="file">${esc(f.file_name)}</td><td><span class="badge ${(OUT[f.outcome] || [])[1] || ''}">${esc((OUT[f.outcome] || [f.outcome])[0])}</span></td><td>${esc(f.detail)}</td><td>${when(f.received_at)}</td></tr>`).join('')
    }</tbody></table></div></div>
    <div class="card"><h2>Searchable candidates (newest CV per person)</h2><div class="tablewrap"><table><thead><tr><th>Name</th><th>Headline</th><th>Languages</th><th>Current CV</th></tr></thead><tbody>${
      DATA.candidates.map((c) => `<tr><td><b>${esc(c.name)}</b><br><small class="why">${esc(c.location)}</small></td><td>${esc(c.headline)}</td><td>${esc(c.languages)}</td><td class="file">${esc(c.cv_file)}<br>${esc(c.cv_date)}</td></tr>`).join('')
    }</tbody></table></div></div>`;
}

async function load() {
  try {
    const r = await fetch('/api/data');
    DATA = await r.json();
    if (!r.ok) throw new Error(DATA.error);
    renderRoles(); renderPipeline(); renderTest(DATA.test); renderCvs();
    $('#status').textContent = `${DATA.roles.filter((r) => r.status === 'open').length} open roles · ${DATA.candidates.length} candidates · updated ${when(new Date())}`;
  } catch (e) { $('#status').textContent = 'Could not load: ' + e.message; }
}

// ---------- forms ----------
$('#askForm').onsubmit = async (e) => {
  e.preventDefault();
  const q = $('#question').value.trim(); if (!q) return;
  const btn = e.target.querySelector('button'); btn.disabled = true;
  $('#askOut').innerHTML = '<p class="hint">Reading every CV…</p>';
  try {
    const r = await act('ask', { question: q });
    $('#askOut').innerHTML = r.matches.length ? `<div class="card"><p class="hint">${esc(r.message)}</p>${matchTable(r.matches)}</div>`
      : `<div class="empty"><b>No good match.</b> ${esc(r.note)}<br>The bot only suggests real people from the CV pool.</div>`;
  } catch (err) { $('#askOut').innerHTML = `<div class="empty">${esc(err.message)}</div>`; }
  btn.disabled = false;
};

$('#roleForm').onsubmit = async (e) => {
  e.preventDefault();
  const btn = e.target.querySelector('button'); btn.disabled = true; $('#roleMsg').textContent = 'Writing the job description… (about 15 seconds)';
  try {
    const r = await act('new_role', { transcript: $('#transcript').value });
    $('#roleMsg').innerHTML = `Done: <b>${esc(r.title)}</b> (role #${r.role_id}) was sent to Slack for approval.`;
    $('#transcript').value = ''; load();
  } catch (err) { $('#roleMsg').textContent = err.message; }
  btn.disabled = false;
};

const toBase64 = (file) => new Promise((ok, bad) => { const fr = new FileReader(); fr.onload = () => ok(String(fr.result).split(',')[1]); fr.onerror = bad; fr.readAsDataURL(file); });
$('#cvForm').onsubmit = async (e) => {
  e.preventDefault();
  const files = [...$('#files').files]; if (!files.length) return;
  const btn = e.target.querySelector('button'); btn.disabled = true; $('#cvMsg').innerHTML = '';
  for (const f of files) {   // one at a time, so the same person in two files is recognised
    const li = document.createElement('li'); li.textContent = `${f.name}: reading…`; $('#cvMsg').appendChild(li);
    try {
      if (f.size > 4 * 1024 * 1024) throw new Error('file is larger than 4 MB');
      const r = await act('upload', { file_name: f.name, data_base64: await toBase64(f) });
      li.innerHTML = `<b>${esc(f.name)}</b>: ${r.outcome === 'unreadable' ? `<span class="badge bad">UNREADABLE</span> ${esc(r.reason)}` : `<span class="badge ok">${esc(r.outcome)}</span> ${esc(r.name)} · ${esc(r.detail)}`}`;
    } catch (err) { li.innerHTML = `<b>${esc(f.name)}</b>: <span class="badge bad">error</span> ${esc(err.message)}`; }
  }
  btn.disabled = false; load();
};

load();
setInterval(load, 30000);   // Slack approvals show up here without refreshing
