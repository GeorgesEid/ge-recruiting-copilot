// GE-RC-05 · The shortlist for an approved role. "Approve" opens the pre-filled GHL form
// (the course GHL key is read-only, so GHL itself creates the contact, the deal and the outreach).
const act = $('Read button').first().json;
const role = $('JD decision message').first().json.role;
const r = $input.first().json;
const s = act.settings;

// Test mode: outreach goes to the tester's own inbox, never to the made-up person. It must be the EXACT address
// the tester replies from: GHL matches a reply to a contact by the sender's address, so aliases (dots, "+")
// make the reply land on another contact and "stop on reply" never fires. Test one candidate at a time.
function ghlLink(m) {
  if (!s.ghl_form_url) return null;
  const parts = m.name.split(' ');
  const q = {
    first_name: parts[0], last_name: parts.slice(1).join(' '),
    email: s.test_inbox || m.email,
    gerc_role: `${role.title} - ${role.client}`, gerc_score: String(m.score), gerc_cv_file: m.cv_file,
    gerc_ref: `${role.id}:${m.candidate_id}`,
  };
  return s.ghl_form_url + '?' + Object.entries(q).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
}

const blocks = [
  { type: 'header', text: { type: 'plain_text', text: `Shortlist: ${role.title} · ${role.client}`.slice(0, 150) } },
  { type: 'context', elements: [{ type: 'mrkdwn', text: `Role #${role.id} · searched all ${r.pool_size} current CVs for: _${role.search_query}_` }] },
];
if (!r.matches.length) {
  blocks.push({ type: 'section', text: { type: 'mrkdwn', text: `*No good match in our CV pool.* ${r.note}\nI will not suggest people who don't fit. Options: relax a must-have, or upload more CVs and approve the role again.` } });
}
for (const m of r.matches) {
  const approve = { type: 'button', style: 'primary', text: { type: 'plain_text', text: 'Approve → start outreach' },
                    action_id: 'cand_approve', value: `${role.id}:${m.candidate_id}` };
  const link = ghlLink(m);
  if (link) approve.url = link;
  blocks.push({ type: 'section', text: { type: 'mrkdwn', text: `*${m.rank}. ${m.name}*  ·  score *${m.score}/100*\n${m.reason}\n:page_facing_up: CV: \`${m.cv_file}\`` } });
  blocks.push({ type: 'actions', elements: [approve,
    { type: 'button', text: { type: 'plain_text', text: 'Skip' }, action_id: 'cand_skip', value: `${role.id}:${m.candidate_id}` }] });
}
if (r.matches.length) {
  blocks.push({ type: 'context', elements: [{ type: 'mrkdwn', text: 'Approve opens GoHighLevel with the candidate filled in: press *Confirm & start outreach* there. Emails stop automatically when the candidate replies.' }] });
}
return [{ json: { channel: act.channel, text: `Shortlist: ${role.title}`, blocks } }];
