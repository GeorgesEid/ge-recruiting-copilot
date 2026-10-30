// Shared server helpers. Every key comes from Vercel Environment Variables, never from the browser.
const E = (k) => process.env[k] || '';

export async function sb(path, init = {}) {
  const r = await fetch(`${E('SUPABASE_URL')}/rest/v1/${path}`, {
    ...init,
    headers: { apikey: E('SUPABASE_SERVICE_ROLE_KEY'), Authorization: `Bearer ${E('SUPABASE_SERVICE_ROLE_KEY')}`,
               'Content-Type': 'application/json', ...(init.headers || {}) },
  });
  if (!r.ok) throw new Error(`Database error ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const t = await r.text();
  return t ? JSON.parse(t) : null;
}

export async function n8n(hook, body) {
  const r = await fetch(`${E('N8N_BASE_URL').replace(/\/$/, '')}/webhook/${hook}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'x-ge-rc-secret': E('N8N_WEBHOOK_SECRET') },
    body: JSON.stringify(body),
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`Automation error ${r.status}: ${t.slice(0, 200)}`);
  return t ? JSON.parse(t) : {};
}

export async function ghl(path) {
  const r = await fetch(`https://services.leadconnectorhq.com${path}`, {
    headers: { Authorization: `Bearer ${E('GHL_API_KEY')}`, Version: '2021-07-28', Accept: 'application/json' },
  });
  if (!r.ok) throw new Error(`GHL error ${r.status}`);
  return r.json();
}

export const ghlLocation = () => E('GHL_LOCATION_ID');
export const passcodeOk = (p) => !!E('PORTAL_PASSCODE') && p === E('PORTAL_PASSCODE');
export function send(res, status, data) {
  res.status(status).setHeader('Content-Type', 'application/json');
  res.setHeader('Cache-Control', 'no-store');
  res.end(JSON.stringify(data));
}
