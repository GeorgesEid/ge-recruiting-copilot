# GE Recruiting Copilot

An AI copilot for a remote-staffing agency: it turns client call notes into a job description, finds the best
5 candidates in 60 CVs with a score and a reason, and runs outreach. **A recruiter approves every step in Slack.**

All people, companies and CVs are made up. Everything created in shared tools starts with **GE-RC**.

| | Link |
|---|---|
| Recruiter portal | https://ge-recruiting-copilot.vercel.app (actions need the passcode in the submission) |
| Code | this repo |
| n8n workflows (exported JSON) | [`n8n/dist/`](n8n/dist) |
| Slack | workspace *GE Recruiting Demo*, channel `#ge-rc-recruiting`, command `/ge-find` |
| Loom | https://www.loom.com/share/03fe10cb467f48d58e55e9c57ea3a26c |

## How it works

```
Client call transcript ─► portal ─► n8n GE-RC-01 ─► OpenAI writes the JD ─► Slack: [Approve] [Reject]
                                                                               │ Approve
                                       n8n GE-RC-05 ◄──────────────────────────┘
                                       └─► GE-RC-03 finds the top 5 ─► Slack shortlist: [Approve → start outreach] [Skip]
                                                                               │ Approve
          GHL form opens pre-filled ◄──────────────────────────────────────────┘
          recruiter confirms ─► GHL workflow: candidate + deal in pipeline "GE-RC Candidates" ─► 3 emails, stop on reply

CV files (PDF / Word / scan) ─► portal or loader ─► n8n GE-RC-02 ─► OpenAI reads the file (also scans)
                                                   └─► database: new / updated (replaces) / duplicate / unreadable (flagged in Slack)
Slack /ge-find <question> ─► n8n GE-RC-04 ─► GE-RC-03 ─► top 5 with score, 2-line reason and the CV file
```

| Workflow | What it does |
|---|---|
| **GE-RC-01 New Role** | Transcript → structured job description → saved as *pending* → Slack message with Approve / Reject |
| **GE-RC-02 CV Intake** | Any CV file → OpenAI reads it (text, Word or scanned image) → `ingest_cv` decides new / updated / duplicate / older / unreadable → unreadable is flagged in Slack |
| **GE-RC-03 Find Candidates** | Question → AI lists the requirements → code checks tools + years on every CV → AI checks the rest → code scores → top 5 with score, reason, CV file (saved as the role's shortlist when asked for a role) |
| **GE-RC-04 Slack Ask** | `/ge-find who has 3+ years of GHL and speaks Arabic?` → answer in the channel |
| **GE-RC-05 Slack Buttons** | Approve/Reject JD (once only, who + when recorded), builds the shortlist, Approve/Skip candidates |

## The hard cases

| Requirement | How |
|---|---|
| Nothing reaches a candidate or client until a recruiter clicks Approve | Roles start as `pending_approval`; the shortlist is only built after Approve; outreach only starts from the recruiter's Approve → GHL confirm. Approvals are "once only" in the database, so a double click does nothing. |
| No good match → the bot says so, never invents | The AI must only return people who meet every hard requirement; then **code** drops any id that is not in the database, removes duplicates and scores under 60. Empty list → "No good match" with what was missing. |
| Every recommendation names its CV | The CV file name is taken from the database (not from the AI) and shown in Slack and the portal. |
| Unreadable CVs flagged, never skipped | Every file gets a row in the CV log. Blank, blurry or corrupted files are logged as `unreadable` and posted to Slack. A network error is never mislabelled as an unreadable CV: it fails loudly so the upload can be retried. |
| Same person twice | Same email (or same name + phone) = same person: kept once, logged as `duplicate`. |
| Updated CV replaces the old one | The date on the CV decides: newer → replaces everywhere (`updated`), older → ignored (`older_ignored`), whatever order they arrive in. |
| Scanned image-only CV | The file itself is sent to OpenAI, which reads images. Joy Villanueva's scan is found by test question 8. |

## Decisions and why (one line each)

### Stack
- **n8n for the automations:** required by the brief, and the recruiter's team can see every run step by step.
- **Supabase (Postgres) as the database:** the "same person / newer CV" rules need one atomic decision per file, which a sheet cannot give.
- **OpenAI `gpt-4.1-mini`:** cheap (the whole project costs under $1), fast, reads PDF, Word and images, and supports strict JSON answers.
- **Search in 4 steps, code and AI each doing what they are good at:** (1) a cheap AI call splits the question into requirements (tool + minimum years, language, certificate…) and preferences; (2) code checks tools and years against the dated jobs of ALL 55 CVs; (3) a stronger AI (`gpt-4.1`) checks languages, certificates, experience type and preferences for EVERY CV that passed; (4) code removes anyone with a failed check and computes the score. No embeddings needed at 55 CVs; with thousands, a vector pre-filter (pgvector) would come before step 2.
- **`gpt-4.1-mini` to read CVs and write JDs, `gpt-4.1` only for the final candidate check:** the small model was inconsistent when judging many CVs at once (it listed someone without Zapier, and skipped a qualified person); the strong model reads only the CVs that passed the code check, so a search still costs a few cents.
- **The AI reads the files directly:** one step for PDF, Word and scans, with no extra OCR service to break.
- **Slack slash command + buttons:** the recruiter asks and approves where they already work, in one click.
- **Plain HTML portal on Vercel, no framework:** nothing to build or break; server functions keep every key out of the browser.

### Job description
- **Format: title, summary, responsibilities, must-have, nice-to-have, schedule, pay, start, type, "to confirm with client":** exactly what a recruiter checks before posting.
- **Only facts from the call; gaps become "To confirm with client":** a JD that invents pay or hours is worse than an incomplete one.
- **The client's final answer wins** (e.g. "4 years… make it 5" → 5+).
- **No private client details in the JD:** one client complained that an agency posted her phone number.
- **The JD includes a one-sentence `search_query`:** approving the JD builds the shortlist automatically from it.

### Scoring
- **Hard requirements filter, preferences rank:** "3+ years, Arabic required" removes people; "Arabic preferred" only raises the score.
- **Every requirement is checked separately (met / not met + evidence) and code keeps only "all met":** the first version let the AI give one overall score and it padded lists to 5 with people it had itself called unqualified (test score 2/10).
- **Code does the date math:** when a CV is read, the AI lists every job with its dates and tools; code adds up years per tool (overlapping jobs counted once). AI arithmetic once missed Sara's 1.5 + 1.8 years.
- **A number of years applies only to the tool it is written next to:** "3+ years of GHL, comfortable with Zapier" asks years for GHL only. The AI once invented "3+ years of Zapier" and cut two good candidates.
- **Score = 70 for meeting every must-have + up to 25 for the client's preferred extras proven in the CV + up to 5 for depth:** computed by code, so it is explainable; for Crescent Smile Dental the Arabic-speaking dental specialists rank first, as the client asked.
- **Things no CV can prove (hours, availability, "no agencies") are not used to filter:** the recruiter checks them in the interview instead of the AI guessing.
- **Years are counted to today and added across jobs:** Rania's two GHL jobs add up to 4.7 years.
- **Result: 10/10 on the test page, twice in a row; the same question gives the same shortlist every time.**
- **Same tool, different spelling counts; a different product does not:** GHL = HighLevel, but Azure is not AWS.

### Pipeline (GHL "GE-RC Candidates")
- **Stages: Outreach Sent → Replied → Interview → Submitted to Client → Hired / No Reply-Not Interested:** the real steps after a recruiter approves someone.
- **GHL creates its own contact, deal and emails (form + workflow):** the course GHL key is read-only and API form submits are blocked by CAPTCHA, so the recruiter's Approve opens a pre-filled GHL form and one more click confirms. With a write-enabled key, n8n would create the deal directly (one HTTP step).
- **3 emails, "Stop on response" on, replies move the deal to Replied:** the sequence stops the moment the candidate answers.
- **Demo waits are 3 minutes (real: 2 and 3 days):** so the Loom can show the stop-on-reply.

### Safety and data
- **Every Slack request is verified with the signing secret (Slack's official method):** nobody can fake an approval. The secret is read from the database at run time, so it is not in the workflow files.
- **Webhooks for the portal require a secret header; portal actions require a passcode:** viewing is open (made-up data), changing is not.
- **No key in any workflow file, repo, browser or screenshot:** keys live in `.env` (git-ignored), n8n credentials and Vercel environment variables.
- **Testing never emails a fake person:** in test mode every outreach goes to the tester's own inbox (`test_inbox` setting); one candidate at a time.
- **The test inbox is the exact address the tester replies from, no Gmail aliases:** GHL matches a reply to a contact by the sender's address; with a "dot" alias the reply landed on another contact and email 3 was still sent. With the exact inbox the reply stopped the sequence and moved the deal to Replied.
- **No "run any SQL" back door:** a temporary helper used during the build was dropped; the database only exposes the 3 decision functions, to the server key only.
- **CV text and transcripts are treated as data:** the prompts tell the AI to ignore instructions hidden inside them.

## Test page
10 questions with known answers (`data/test-questions.json`), each aimed at a trap: duplicates, updated CVs, the
scanned CV, years added across jobs, look-alike tools, and a question with no right answer. PASS = exactly the right
people, each once. The portal shows the latest score and can re-run it.

## Files

| Path | What |
|---|---|
| `data/transcripts/` | 7 messy client call transcripts (06 and 07 were written for the Loom) |
| `data/cvs/` · `data/hard-cases/` | 60 CVs (PDF + Word, 1 scan, 3 duplicates, 2 updates) · 2 unreadable files |
| `data/cv-source.txt` · `scripts/generate-cvs.ps1` | The made-up people · builds the CV files |
| `supabase/schema.sql` | Tables and the decision rules (new / updated / duplicate, approve once) |
| `n8n/code/*.js` · `n8n/dist/*.json` | The code of every n8n step · the importable workflows |
| `scripts/deploy-n8n.ps1` · `load-cvs.ps1` · `run-tests.ps1` · `publish.ps1` | Install workflows · load CVs · run the 10 tests · publish |
| `web/` | Recruiter portal (Vercel) |
| `docs/STEP-*.md` · `docs/LOOM-SCRIPT.md` | Setup, step by step · the demo script |
