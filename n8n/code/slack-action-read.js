// GE-RC-05 · (after slack-verify.js) Reads which button was clicked.
const payload = JSON.parse(form.payload || '{}');
const a = (payload.actions || [])[0];
if (!a) return [];
const user = (payload.user && (payload.user.username || payload.user.name)) || 'recruiter';
const [kind, verb] = String(a.action_id).split('_');            // jd_approve, jd_reject, cand_approve, cand_skip
if (!['jd', 'cand'].includes(kind)) return [];
const [roleId, candidateId] = String(a.value).split(':').map(Number);
return [{ json: {
  kind, user, role_id: roleId, candidate_id: candidateId || null,
  status: kind === 'jd' ? (verb === 'approve' ? 'open' : 'rejected') : (verb === 'approve' ? 'approved' : 'skipped'),
  channel: payload.channel && payload.channel.id, message_ts: payload.message && payload.message.ts,
  settings: Object.fromEntries($('Load settings').all().map((i) => [i.json.key, i.json.value])),
} }];
