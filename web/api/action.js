// POST /api/action - anything that changes data or costs AI money needs the portal passcode.
import { sb, n8n, passcodeOk, send } from './_lib.js';
import tests from './test-questions.json' with { type: 'json' };

const norm = (s) => String(s).normalize('NFD').replace(/\p{Mn}/gu, '').toLowerCase().trim();

async function runTests() {
  const results = await Promise.all(tests.questions.map(async (t) => {
    const r = await n8n('ge-rc-search', { question: t.q });
    const got = (r.matches || []).map((m) => norm(m.name));
    const exp = t.expected.map(norm);
    const missing = exp.filter((x) => !got.includes(x));
    const extra = got.filter((x) => !exp.includes(x));
    const twice = new Set(got).size !== got.length;
    return { id: t.id, question: t.q, expected: t.expected, why: t.why, pass: !missing.length && !extra.length && !twice,
      bot: (r.matches || []).map((m) => ({ name: m.name, score: m.score, reason: m.reason, cv_file: m.cv_file })),
      bot_message: r.message, missing, extra };
  }));
  const run = { score: results.filter((x) => x.pass).length, total: results.length, details: results };
  await sb('test_runs', { method: 'POST', body: JSON.stringify(run) });
  return { ...run, ran_at: new Date().toISOString() };
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return send(res, 405, { error: 'POST only' });
  const b = req.body || {};
  if (!passcodeOk(b.passcode)) return send(res, 401, { error: 'Wrong passcode' });
  try {
    switch (b.action) {
      case 'check': return send(res, 200, { ok: true });
      case 'new_role':
        if (String(b.transcript || '').trim().length < 200) return send(res, 400, { error: 'Please paste the full call transcript (at least 200 characters).' });
        return send(res, 200, await n8n('ge-rc-new-role', { transcript: b.transcript }));
      case 'upload':
        if (!b.file_name || !b.data_base64) return send(res, 400, { error: 'No file' });
        return send(res, 200, await n8n('ge-rc-cv-intake', { file_name: b.file_name, data_base64: b.data_base64 }));
      case 'ask':
        if (!String(b.question || '').trim()) return send(res, 400, { error: 'Type a question first.' });
        return send(res, 200, await n8n('ge-rc-search', { question: b.question }));
      case 'run_tests': return send(res, 200, await runTests());
      default: return send(res, 400, { error: 'Unknown action' });
    }
  } catch (e) {
    return send(res, 502, { error: e.message });
  }
}
