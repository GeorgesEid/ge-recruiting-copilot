// GE-RC-05 · Replaces the job description message: buttons removed, decision + who + when shown.
const act = $('Read button').first().json;
const role = $json;
const approved = role.status === 'open';
const when = new Date().toLocaleString('en-US', { timeZone: 'America/New_York', dateStyle: 'medium', timeStyle: 'short' });
const blocks = [
  { type: 'header', text: { type: 'plain_text', text: `${approved ? 'Approved' : 'Rejected'}: ${role.title} (role #${role.id})` } },
  { type: 'section', text: { type: 'mrkdwn', text: role.jd_text.slice(0, 2900) } },
  { type: 'context', elements: [{ type: 'mrkdwn', text: `${approved ? ':white_check_mark: Approved' : ':x: Rejected'} by *${act.user}* · ${when} ET${approved ? ' · building the shortlist now…' : ''}` }] },
];
return [{ json: { role, approved, update: { channel: act.channel, ts: act.message_ts, text: `${approved ? 'Approved' : 'Rejected'}: ${role.title}`, blocks } } }];
