# Step 4 - Two tokens so Claude can publish the portal and the code (about 5 minutes)

The brief needs a **live link** (Vercel) and a **repo** (GitHub). With these two tokens Claude publishes
both for you, now and after every fix. Both are only for this project and can be deleted after grading.

## 1. GitHub
1. **github.com → + (top right) → New repository** → name `ge-recruiting-copilot` → **Public** →
   leave "Add a README" unticked → **Create repository**.
2. Make a token: **github.com/settings/personal-access-tokens/new** (Fine-grained token)
   - Token name: `ge-recruiting-copilot` · Expiration: 30 days
   - Repository access: **Only select repositories** → `ge-recruiting-copilot`
   - Permissions → Repository permissions → **Contents: Read and write**
   - **Generate token** → copy it (starts with `github_pat_`).
3. Add to `.env`:
   ```
   GITHUB_USER=your-github-username
   GITHUB_TOKEN=github_pat_...
   ```

## 2. Vercel
1. **vercel.com → click your avatar (top right) → Account Settings → Tokens**
   (or go straight to **vercel.com/account/settings/tokens**).
2. Token name `ge-recruiting-copilot`, scope = your personal account, expiration 30 days → **Create** → copy.
3. Add to `.env`:
   ```
   VERCEL_TOKEN=...
   PORTAL_PASSCODE=pick-a-passcode-for-the-portal
   ```
   (The passcode protects the buttons that add roles, upload CVs and run tests. Give it to your instructor.)

Then tell Claude **"tokens are in .env"**.
