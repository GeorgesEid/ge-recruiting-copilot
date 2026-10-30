// GE-RC-04 · Formats the top 5 for Slack: score, 2-line reason and the CV file each answer came from.
const cmd = $('Read command').first().json;
const r = $input.first().json;
const blocks = [{ type: 'section', text: { type: 'mrkdwn', text: `:mag: <@${cmd.user_id}> asked: *${cmd.question}*` } }];
if (r.matches.length) {
  for (const m of r.matches) {
    blocks.push({ type: 'section', text: { type: 'mrkdwn',
      text: `*${m.rank}. ${m.name}*  ·  score *${m.score}/100*\n${m.reason}\n:page_facing_up: CV: \`${m.cv_file}\`` } });
  }
} else {
  blocks.push({ type: 'section', text: { type: 'mrkdwn',
    text: `*No good match.* ${r.note || ''}\nI only suggest real people from our CV pool, so I am not suggesting anyone for this.` } });
}
blocks.push({ type: 'context', elements: [{ type: 'mrkdwn',
  text: `Searched all ${r.pool_size} current CVs (duplicates merged, newest CV per person). Score = how well the CV meets the request.` }] });
return [{ json: { url: cmd.response_url, body: { response_type: 'in_channel', text: `Answer: ${cmd.question}`, blocks } } }];
