// GE-RC-04 · (after slack-verify.js) Reads the /ge-find command.
const question = String(form.text || '').trim();
if (!question) return [];
return [{ json: { question, user_id: form.user_id, channel: form.channel_id, response_url: form.response_url } }];
