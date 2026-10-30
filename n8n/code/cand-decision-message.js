// GE-RC-05 · Confirms a candidate decision in the shortlist's thread (a second click changes nothing).
const act = $('Read button').first().json;
const d = $json;
if (!d.changed) return [];
const text = d.status === 'approved'
  ? `:white_check_mark: *${d.name}* approved by *${act.user}* for ${d.role_title}. GoHighLevel opened with their details: press *Confirm & start outreach* there. Emails stop as soon as ${d.name.split(' ')[0]} replies.`
  : `:fast_forward: *${d.name}* skipped by *${act.user}*.`;
return [{ json: { channel: act.channel, thread_ts: act.message_ts, text } }];
