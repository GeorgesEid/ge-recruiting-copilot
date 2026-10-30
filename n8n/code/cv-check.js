// GE-RC-02 · Decides if the CV was really read. Anything doubtful becomes "unreadable" (flagged, never skipped).
const fileName = $('Build read request').first().json.file_name;
const r = $input.first().json;
let p = null;
let reason = '';

if (r.error) {
  const msg = String(r.error.message || r.error.description || r.error);
  // Only "bad request" means the FILE is the problem. Anything else (network, quota, outage) must not
  // label a good CV as unreadable: fail loudly so the upload can be retried.
  if (!/400|bad request|invalid|unsupported|could not/i.test(msg)) throw new Error('OpenAI could not be reached, try again: ' + msg.slice(0, 150));
  reason = 'The file could not be opened (' + msg.slice(0, 150) + ').';
} else {
  const msg = (r.output || []).find((o) => o.type === 'message');
  const txt = msg && (msg.content || []).find((c) => c.type === 'output_text');
  try { p = JSON.parse(txt.text); } catch (e) { reason = 'The AI answer could not be understood.'; }
}
if (p && p.readable && (!p.name || String(p.full_text || '').length < 150)) {
  p = { readable: false, reason: 'Too little text could be read to trust this CV.' };
}

const out = p && p.readable
  ? { ...p, readable: true, cv_date: /^\d{4}-\d{2}$/.test(p.cv_date) ? p.cv_date : '' }
  : { readable: false, reason: (p && p.reason) || reason || 'Unknown reason.' };
out.file_name = fileName;
return [{ json: { p: out } }];
