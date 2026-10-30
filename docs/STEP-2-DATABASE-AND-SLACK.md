# Step 2 - Create the database and connect Slack (about 10 minutes)

## A. Create the database tables (Supabase)
1. Open `C:\Users\User\Documents\GE-Recruiting-Copilot\supabase\schema.sql` in Notepad → **Ctrl+A**, **Ctrl+C**.
   ```
   notepad C:\Users\User\Documents\GE-Recruiting-Copilot\supabase\schema.sql
   ```
2. **supabase.com** → your project `ge-recruiting-copilot` → **SQL Editor** (left menu) → **New query**.
3. Paste (**Ctrl+V**) → click **Run**. You should see *"Success. No rows returned"*.
   (If Supabase warns about "destructive operations" or RLS, click **Run this query** to confirm.)

## B. Connect the Slack bot to n8n
Go to **api.slack.com/apps** → **GE Recruiting Copilot**.

**1. Slash command**: left menu **Slash Commands → Create New Command**
| Field | Value |
|---|---|
| Command | `/ge-find` |
| Request URL | `https://n8ndemo.remotelyx.com/webhook/ge-rc-slack-command` |
| Short Description | `Find the best candidates in our CVs` |
| Usage Hint | `who has 3+ years of GHL and speaks Arabic?` |

→ **Save**.

**2. Buttons**: left menu **Interactivity & Shortcuts** → turn **On** →
Request URL: `https://n8ndemo.remotelyx.com/webhook/ge-rc-slack-actions` → **Save Changes**.

**3.** Slack shows a yellow banner *"reinstall your app"* → click it → **Allow**.
(If the bot token changes after reinstalling, paste the new `xoxb-...` into `.env` and tell Claude.)

When finished, say **"database and Slack done"**.
