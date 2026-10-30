// GE-RC-03 · Code has the last word over the AI: unknown ids are dropped (no invented people), anyone with a
// failed requirement check is removed, each person appears once, max 5, and the CV file comes from the database.
const hook = $('Search webhook').first().json.body || {};
const pool = $('Load candidate pool').all().map((i) => i.json).filter((c) => c && c.id);
const byId = new Map(pool.map((c) => [Number(c.id), c]));
const ai = JSON.parse($input.first().json.choices[0].message.content);

const seen = new Set();
const dropped = [];
const matches = [];
const nReq = (ai.requirements || []).length;
for (const m of ai.candidates || []) {
  const c = byId.get(Number(m.candidate_id));
  if (!c) { dropped.push(m.candidate_id); continue; }
  const checks = m.checks || [];
  const meetsAll = checks.length >= nReq && checks.every((k) => k.met === true);
  if (seen.has(c.id) || !meetsAll || m.score < 60) continue;
  seen.add(c.id);
  matches.push({ candidate_id: c.id, name: c.name, email: c.email, score: Math.min(100, Math.round(m.score)),
                 reason: String(m.reason || '').slice(0, 240), cv_file: c.cv_file });
}
matches.sort((a, b) => b.score - a.score);
const top = matches.slice(0, 5).map((m, i) => ({ rank: i + 1, ...m }));
const roleId = Number(hook.role_id) || null;

return [{ json: {
  question: hook.question, role_id: roleId, pool_size: pool.length, matches: top,
  message: top.length ? `Top ${top.length} of ${pool.length} CVs.` : `No good match among ${pool.length} CVs. ${ai.note}`.trim(),
  note: ai.note, requirements: ai.requirements || [], dropped_unknown_ids: dropped,
  rows: top.map((m) => ({ role_id: roleId, candidate_id: m.candidate_id, rank: m.rank, score: m.score, reason: m.reason, cv_file: m.cv_file })),
} }];
