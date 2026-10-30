# Step 3 - GoHighLevel: candidate pipeline + outreach emails (about 25 minutes)

Why by hand: the course GHL key can only READ. So GHL builds its own records with a form + a workflow
(free features). n8n and the portal only read GHL. Everything you create starts with **GE-RC**.

## 1. Custom fields (Settings → Custom Fields → Add Field → Single Line, object = Contact)
Create these 4 (exact names):
- `GE-RC Role`
- `GE-RC Score`
- `GE-RC CV File`
- `GE-RC Ref`

## 2. Pipeline (Opportunities → Pipelines → Create new pipeline)
Name: **GE-RC Candidates**. Stages in this order:
1. `Outreach Sent`
2. `Replied`
3. `Interview`
4. `Submitted to Client`
5. `Hired`
6. `No Reply / Not Interested`

## 3. Form (Sites → Forms → Builder → + Add Form → Blank)
Name: **GE-RC Confirm Candidate**
- Fields: **First Name, Last Name, Email**, then the 4 custom fields above (drag them in from "Custom Fields").
- Remove the Phone field if it is there. Do **not** add a captcha.
- Click each GE-RC field → in its settings find **Query Key** and type exactly: `gerc_role`, `gerc_score`,
  `gerc_cv_file`, `gerc_ref` (one per field). This lets the Slack "Approve" link fill them in.
- Click the Submit button → change its text to **Confirm & start outreach**.
- Form **Options/Settings** → On submit: *Message* → `Outreach started. You can close this tab.`
- **Save**. Then click **Integrate / Share** → copy the **Link** (looks like `https://api.leadconnectorhq.com/widget/form/XXXX`) and paste it to Claude.

## 4. Workflow 1: the email sequence (Automation → Workflows → Create Workflow → Start from scratch)
Name: **GE-RC Candidate Outreach**
- **Trigger:** *Form Submitted* → filter: Form is `GE-RC Confirm Candidate`.
- **Action 1:** *Add Contact Tag* → `ge-rc-candidate`
- **Action 2:** *Create/Update Opportunity* → pipeline `GE-RC Candidates`, stage `Outreach Sent`,
  opportunity name `{{contact.name}} - {{contact.gerc_role}}` (use the "custom values" picker for the role field).
- **Action 3:** *Send Email* (email 1, text below)
- **Action 4:** *Wait* → **3 minutes** (demo speed; for a real client: 2 days)
- **Action 5:** *Send Email* (email 2)
- **Action 6:** *Wait* → **3 minutes** (real: 3 days)
- **Action 7:** *Send Email* (email 3)
- **Settings tab** (top): turn **Stop on response** ON. Allow re-entry: OFF.
- **Save** and switch from Draft to **Publish**.

**Email 1** - Subject: `A remote role that fits your experience`
> Hi {{contact.first_name}},
> I'm Beth from GE Staffing. We place remote professionals with US companies, and your CV stood out for a
> **{{contact.gerc_role}}** position we're filling now. Would you be open to a short call this week?
> Just reply to this email and I'll send the details.
> Beth, GE Staffing

**Email 2** - Subject: `Re: A remote role that fits your experience`
> Hi {{contact.first_name}}, just following up on the {{contact.gerc_role}} role. It's full-time and remote
> with a US client, and we're shortlisting this week. Interested? A one-line reply is enough.

**Email 3** - Subject: `Should I close your file?`
> Hi {{contact.first_name}}, I haven't heard back, so I'll assume the timing isn't right and close this for now.
> If you'd like to hear about the {{contact.gerc_role}} role, just reply any time.

## 5. Workflow 2: mark replies (Create Workflow → Start from scratch)
Name: **GE-RC Candidate Replied**
- **Trigger:** *Customer Replied* → filter: Reply channel = Email; add filter **Contact Tag** includes `ge-rc-candidate`.
- **Action:** *Create/Update Opportunity* → pipeline `GE-RC Candidates`, stage **Replied** (turn on "allow backward/any stage" if asked).
- **Save** → **Publish**.

When finished, paste the **form link** to Claude.
