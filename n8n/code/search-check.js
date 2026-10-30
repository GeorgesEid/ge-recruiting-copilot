// GE-RC-03 · Step 4: code has the last word. Unknown ids are dropped (no invented people), anyone with a failed
// check is removed, each person appears once, max 5, and the CV file always comes from the database.
const hook = $('Search webhook').first().json.body || {};
const meta = $('Build search request').first().json.meta;
const pool = $('Load candidate pool').all().map((i) => i.json).filter((c) => c && c.id);
const byId = new Map(pool.map((c) => [Number(c.id), c]));
const ai = JSON.parse($input.first().json.choices[0].message.content);
const nReq = meta.ai_requirements.length;
const nPref = meta.preferred.length;

const seen = new Set();
const dropped = [];
const matches = [];
for (const m of ai.candidates || []) {
  const c = byId.get(Number(m.candidate_id));
  if (!c) { dropped.push(m.candidate_id); continue; }
  const checks = m.checks || [];
  if (seen.has(c.id) || checks.length < nReq || !checks.every((k) => k.met === true)) continue;
  seen.add(c.id);
  // Score, computed by code so it can be explained: meets every must-have = 70,
  // the client's preferred extras proven in the CV add up to 25, depth of experience adds up to 5.
  const prefShare = nPref ? (m.preferred_checks || []).slice(0, nPref).filter((p) => p.met === true).length / nPref : 1;
  const depth = Math.max(0, Math.min(10, Number(m.depth) || 0)) / 10;
  matches.push({ candidate_id: c.id, name: c.name, email: c.email, score: Math.round(70 + 25 * prefShare + 5 * depth),
                 reason: String(m.reason || '').slice(0, 240), cv_file: c.cv_file });
}
matches.sort((a, b) => b.score - a.score);
const top = matches.slice(0, 5).map((m, i) => ({ rank: i + 1, ...m }));
const roleId = Number(hook.role_id) || null;
const note = ai.note || (meta.passed_code_check ? '' : `Nobody has the required tools and years (${meta.code_requirements.join(', ')}).`);

return [{ json: {
  question: hook.question, role_id: roleId, pool_size: pool.length, matches: top,
  message: top.length ? `Top ${top.length} of ${pool.length} CVs.` : `No good match among ${pool.length} CVs. ${note}`.trim(),
  note, requirements: meta.requirements, preferred: meta.preferred, passed_code_check: meta.passed_code_check, dropped_unknown_ids: dropped,
  rows: top.map((m) => ({ role_id: roleId, candidate_id: m.candidate_id, rank: m.rank, score: m.score, reason: m.reason, cv_file: m.cv_file })),
} }];
