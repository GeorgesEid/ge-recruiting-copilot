// GE-RC-01 · The Slack message that asks the recruiter to approve the job description.
const role = $json;
// Slack allows 3000 characters per text block, so long JDs are split by paragraph.
const chunks = [];
for (const p of role.jd_text.split('\n\n')) {
  if (chunks.length && (chunks[chunks.length - 1] + '\n\n' + p).length < 2900) chunks[chunks.length - 1] += '\n\n' + p;
  else chunks.push(p.slice(0, 2900));
}
const blocks = [
  { type: 'header', text: { type: 'plain_text', text: `New job description to approve (role #${role.id})` } },
  ...chunks.map((c) => ({ type: 'section', text: { type: 'mrkdwn', text: c } })),
  { type: 'context', elements: [{ type: 'mrkdwn', text: 'Nothing goes to the client or to candidates until you approve. Approving also builds the shortlist.' }] },
  { type: 'actions', elements: [
    { type: 'button', style: 'primary', text: { type: 'plain_text', text: 'Approve' }, action_id: 'jd_approve', value: String(role.id) },
    { type: 'button', style: 'danger', text: { type: 'plain_text', text: 'Reject' }, action_id: 'jd_reject', value: String(role.id) },
  ] },
];
return [{ json: { role_id: role.id, slack: { channel: '@@SLACK_CHANNEL_ID@@', text: `New job description to approve: ${role.title}`, blocks } } }];
