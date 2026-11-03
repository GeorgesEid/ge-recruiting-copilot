# Loom script (under 3 minutes)

About 380 spoken words, roughly 2 min 40 s at a calm pace. **Bold** = what you click. *Italic* = what you say.

## Before you press Record (10 minutes)

1. Open these tabs, in this order:
   - Portal https://ge-recruiting-copilot.vercel.app (type the passcode **before** recording, so it never shows on screen)
   - Slack, channel `#ge-rc-recruiting`
   - GHL > Opportunities > pipeline **GE-RC Candidates**
   - Gmail for **layal.nohra137@gmail.com**
2. Have `data/transcripts/05-northfield-cpa.txt` open in Notepad (the role we create live).
3. **Never show:** the `.env` file, n8n Credentials, Vercel Settings > Environment Variables, or the passcode.
4. Close other tabs and notifications. Loom: "Screen + Camera", English.

The 3-minute email wait doesn't fit in the video. So you reply while recording and show the result later in the
recording, or you cut the wait out with Loom's **Trim**. Andrea Ruiz's deal is already in **Replied** as proof.

---

## 0:00 – 0:15 · Intro (portal, Roles tab)
*"Hi, I'm George. This is my AI Recruiting Copilot, built with n8n, GoHighLevel, Slack and OpenAI. I'll take one
role from a client call to outreach, and show how it handles the messy cases. Nothing reaches a candidate or client
until a recruiter clicks Approve."*

## 0:15 – 0:45 · Call notes → job description
**Add role / CVs** tab → paste the Northfield CPA transcript → **Create role**.
*"I paste the notes from a messy client call. The AI writes a job description using only facts from the call.
Anything missing, like pay, goes under 'To confirm with client'. When the client changed their mind, the final
answer wins."*
Switch to **Slack**: the JD appears with Approve / Reject.
*"It comes to Slack for approval. Nothing has gone to the client or to any candidate yet."*

## 0:45 – 1:20 · Approve → shortlist
**Approve** in Slack. Point at "Approved by … at …", then at the shortlist that appears.
*"One click approves it, and it records who approved and when. Clicking again does nothing, because each decision
can only be made once. The bot then searches all 55 current CVs. Code checks tools and years from the dated jobs,
and the AI checks things like languages and certificates. I get the top matches, each with a score, a two-line
reason and the CV file it came from. It can't invent anyone: code removes any person who isn't in the database."*

## 1:20 – 1:55 · Outreach and stop-on-reply
**Approve → start outreach** on the first candidate → the GHL form opens pre-filled → **Confirm & start outreach**.
*"Approving opens GoHighLevel with the candidate filled in. One more click creates the deal in the candidate
pipeline and starts a 3-email sequence. While testing, every email goes to my own inbox, never to a made-up person."*
Gmail: open email 1 → reply "Yes, interested". GHL pipeline: show **Andrea Ruiz in Replied**.
*"When the candidate replies, the emails stop and the deal moves to Replied, as you can see here."*

## 1:55 – 2:30 · The hard cases
**CVs** tab (the CV log):
*"Every CV is searchable: PDF, Word, and even this scanned photo-only CV from Joy Villanueva. Three people sent
their CV twice, and they're kept once, marked duplicate. Two sent an updated CV: the newer date replaces the old one,
whatever order they arrive in. Unreadable files are never skipped silently. They're logged and flagged in Slack."*
(Optional: show the Slack "unreadable CV" message.)
Slack: type `/ge-find registered nurse licensed in Texas`
*"And when nobody fits, the bot says so instead of inventing a candidate."*

## 2:30 – 2:50 · Pipeline + test page
**Pipeline** tab → then **Test page** tab (10/10).
*"The portal shows open roles with their shortlists, candidates at each pipeline stage, and a test page: 10
questions with known right answers, aimed at the traps. The bot scores 10 out of 10."*

## 2:50 – 3:00 · Close
*"Keys never touch the browser or the repo. They live in an env file, n8n credentials and Vercel. The README
explains every decision in one line. Thanks for watching!"*

---

### If something goes wrong while recording
- Slack is slow: say *"it's reading every CV, about 15 seconds"* and wait. It always answers.
- The email lands in spam: show it there. That's normal for a new sender.
- If you approve the wrong candidate, just keep going. Only test mode emails reach your inbox.
