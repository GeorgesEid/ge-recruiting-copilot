// GE-RC-01 · Reads the AI's job description and turns it into a database row + readable text.
const jd = JSON.parse($json.choices[0].message.content);
const bullets = (a) => (a || []).map((x) => `• ${x}`).join('\n');
const parts = [
  `*${jd.title}* · ${jd.client}`,
  jd.summary,
  `*What you'll do*\n${bullets(jd.responsibilities)}`,
  `*Must have*\n${bullets(jd.must_have)}`,
  jd.nice_to_have.length ? `*Nice to have*\n${bullets(jd.nice_to_have)}` : '',
  `*Schedule:* ${jd.schedule}\n*Pay:* ${jd.compensation}\n*Start:* ${jd.start_date}\n*Type:* ${jd.employment_type}`,
  jd.to_confirm.length ? `*To confirm with the client before posting*\n${bullets(jd.to_confirm)}` : '',
].filter(Boolean);

return [{ json: {
  client: jd.client, title: jd.title, transcript: $('Build JD request').first().json.transcript,
  jd, jd_text: parts.join('\n\n'), search_query: jd.search_query, status: 'pending_approval',
} }];
