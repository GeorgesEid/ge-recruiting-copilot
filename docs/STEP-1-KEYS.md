# Step 1 - Create this project's own keys (about 30 minutes)

**The rule:** every project gets brand-new keys, and they are all saved in one file on your computer:
`C:\Users\User\Documents\GE-Recruiting-Copilot\.env`

Open it with Notepad:
```
notepad C:\Users\User\Documents\GE-Recruiting-Copilot\.env
```
Paste each key after the `=` sign (no spaces, no quotes), then save. **Do not paste keys into the chat.** Just tell
Claude "keys are in .env" and Claude reads the file itself.

Why this is safe: `.env` is listed in `.gitignore`, so it can never be uploaded to GitHub. When we go live, the same
values are copied into n8n's **Credentials** and Vercel's **Environment Variables**. Both are locked vaults, never code.
If a key ever leaks, you delete only that project's key and nothing else breaks.

---

## 1. OpenAI (the AI brain)
1. Go to **platform.openai.com**, click the project name at the top left, then **Create project** and name it `GE-Recruiting-Copilot`.
2. In that project: **Settings → Limits → set a monthly budget of $5** (this whole project should cost under $1).
3. **API keys → Create new secret key** → name `ge-rc-n8n`, project `GE-Recruiting-Copilot` → copy it.
4. Paste into `.env` → `OPENAI_API_KEY=`
   (Your account needs a few dollars of credit under Billing.)

## 2. Supabase (the database that stores every CV)
1. **supabase.com → New project** → name `ge-recruiting-copilot`, region *East US*, generate a password and save it somewhere safe.
   (The free plan allows 2 active projects. If it refuses, pause an old project first.)
2. When it's ready: **Project Settings → API Keys**. Use the "Legacy API keys" tab if you see one.
3. Copy the **Project URL** into `SUPABASE_URL=` and the **service_role** key (starts with `eyJ`) into `SUPABASE_SERVICE_ROLE_KEY=`.

## 3. Slack (where the recruiter talks to the bot)
1. Create a free workspace at **slack.com/get-started**, e.g. `GE Recruiting Demo` (or use one you already own).
2. Create a channel called `#ge-rc-recruiting`.
3. Go to **api.slack.com/apps → Create New App → From scratch** → name `GE Recruiting Copilot` → pick your workspace.
4. **OAuth & Permissions → Bot Token Scopes → Add:** `chat:write`, `commands`, `chat:write.public`.
5. Scroll up → **Install to Workspace** → Allow → copy the **Bot User OAuth Token** (starts with `xoxb-`) into `SLACK_BOT_TOKEN=`.
6. **Basic Information → App Credentials → Signing Secret → Show** → copy into `SLACK_SIGNING_SECRET=`.
7. In Slack, right-click `#ge-rc-recruiting` → **View channel details** → copy the **Channel ID** at the bottom (starts with `C`) into `SLACK_CHANNEL_ID=`.
8. In the channel, type `/invite @GE Recruiting Copilot`.
   (The slash command and button settings come later, once the n8n links exist.)

## 4. n8n (the automations)
1. Log in to **n8ndemo.remotelyx.com → Settings → n8n API → Create an API key** → label `GE-RC` → copy into `N8N_API_KEY=`.
   With this key Claude can install and test the workflows for you, so you don't have to rebuild them by hand.

## 5. Already done for you
- `GHL_LOCATION_ID`, `GHL_API_KEY`: from the course (read-only key)
- `N8N_WEBHOOK_SECRET`: a random password Claude made, so strangers can't call our n8n webhooks
- `TEST_INBOX`: your Gmail. Every candidate email in testing goes to you, never to the fake people.

When finished, say **"keys are in .env"**.
