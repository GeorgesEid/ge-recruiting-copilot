<#
  Builds the 5 GE-RC workflows into n8n\dist\ (the exported JSON you submit) and installs them in n8n.
  Code-node JavaScript comes from n8n\code\*.js. Keys are NEVER written into the workflows:
  they live in the n8n credentials (GE-RC OpenAI / Supabase / Slack Bot / Webhook Secret).
  Usage:  powershell -ExecutionPolicy Bypass -File scripts\deploy-n8n.ps1            (build + install + activate)
          powershell -ExecutionPolicy Bypass -File scripts\deploy-n8n.ps1 -BuildOnly
#>
param([switch]$BuildOnly)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envs = @{}
Get-Content (Join-Path $root '.env') | ? { $_ -match '^\s*([A-Z0-9_]+)=(.*)$' } | % { $envs[$Matches[1]] = $Matches[2].Trim() }
$SB = $envs.SUPABASE_URL; $N8N = $envs.N8N_BASE_URL.TrimEnd('/')
$subs = @{ OPENAI_MODEL = $envs.OPENAI_MODEL; SLACK_CHANNEL_ID = $envs.SLACK_CHANNEL_ID; SUPABASE_URL = $SB; N8N_BASE_URL = $N8N }

function Code([string[]]$files) {
  $s = ($files | % { Get-Content (Join-Path $root "n8n\code\$_") -Raw -Encoding UTF8 }) -join "`n"
  foreach ($k in $subs.Keys) { $s = $s.Replace("@@$k@@", $subs[$k]) }
  $s
}
function Guid-For([string]$t) { ([guid]::new([Security.Cryptography.MD5]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($t)))).ToString() }
$CREDS = @{
  openai   = @{ openAiApi = @{ id = $envs.N8N_CRED_OPENAI; name = 'GE-RC OpenAI' } }
  supabase = @{ supabaseApi = @{ id = $envs.N8N_CRED_SUPABASE; name = 'GE-RC Supabase' } }
  slack    = @{ httpHeaderAuth = @{ id = $envs.N8N_CRED_SLACK; name = 'GE-RC Slack Bot' } }
  secret   = @{ httpHeaderAuth = @{ id = $envs.N8N_CRED_SECRET; name = 'GE-RC Webhook Secret' } }
}

# ---------------- builder ----------------
function Start-Wf($name) { $script:wf = $name; $script:nodes = New-Object Collections.ArrayList; $script:conns = [ordered]@{}; $script:x = 0 }
function Node($name, $type, $ver, $params, $extra = @{}, [int]$y = 300) {
  $n = [ordered]@{ parameters = $params; id = (Guid-For "$script:wf|$name"); name = $name; type = $type; typeVersion = $ver; position = @($script:x, $y) }
  foreach ($k in $extra.Keys) { $n[$k] = $extra[$k] }
  [void]$script:nodes.Add($n); $script:x += 220
}
function Link($from, $to, [int]$out = 0) {
  if (-not $script:conns.Contains($from)) { $script:conns[$from] = [ordered]@{ main = (New-Object Collections.ArrayList) } }
  $m = $script:conns[$from].main
  while ($m.Count -le $out) { [void]$m.Add((New-Object Collections.ArrayList)) }
  [void]$m[$out].Add([ordered]@{ node = $to; type = 'main'; index = 0 })
}
function Chain([string[]]$names) { for ($i = 0; $i -lt $names.Count - 1; $i++) { Link $names[$i] $names[$i + 1] } }
function Save-Wf($file) {
  $names = $script:nodes | % { $_.name }
  foreach ($k in $script:conns.Keys) { foreach ($o in $script:conns[$k].main) { foreach ($c in $o) { if ($names -notcontains $c.node -or $names -notcontains $k) { throw "$($script:wf): bad link $k -> $($c.node)" } } } }
  $obj = [ordered]@{ name = $script:wf; nodes = $script:nodes; connections = $script:conns
    settings = [ordered]@{ executionOrder = 'v1'; saveDataErrorExecution = 'all'; saveDataSuccessExecution = 'all' } }
  $json = $obj | ConvertTo-Json -Depth 60
  [IO.File]::WriteAllText((Join-Path $root "n8n\dist\$file"), $json, (New-Object Text.UTF8Encoding $false))
  Write-Host ("  built {0,-34} {1,2} nodes" -f $file, $script:nodes.Count)
}

# ---------------- node helpers ----------------
function Webhook($name, $path, [bool]$secret, [bool]$raw = $false) {
  $p = [ordered]@{ httpMethod = 'POST'; path = $path; responseMode = 'responseNode'; options = [ordered]@{} }
  if ($raw) { $p.options.rawBody = $true }
  $extra = @{ webhookId = (Guid-For "hook|$path") }
  if ($secret) { $p.authentication = 'headerAuth'; $extra.credentials = $CREDS.secret }
  Node $name 'n8n-nodes-base.webhook' 2 $p $extra
}
function CodeNode($name, [string[]]$files) { Node $name 'n8n-nodes-base.code' 2 ([ordered]@{ jsCode = (Code $files) }) }
function Http($name, $method, $url, $cred, $body = $null, $headers = @(), $extra = @{}, [int]$timeout = 60000) {
  $p = [ordered]@{ method = $method; url = $url; options = [ordered]@{ timeout = $timeout } }
  $c = if ($cred) { $CREDS[$cred] } else { $null }
  if ($cred -in 'openai', 'supabase') { $p.authentication = 'predefinedCredentialType'; $p.nodeCredentialType = @($c.Keys)[0] }
  elseif ($cred) { $p.authentication = 'genericCredentialType'; $p.genericAuthType = 'httpHeaderAuth' }
  if ($headers.Count) { $p.sendHeaders = $true; $p.headerParameters = @{ parameters = @($headers | % { [ordered]@{ name = $_[0]; value = $_[1] } }) } }
  if ($body) { $p.sendBody = $true; $p.specifyBody = 'json'; $p.jsonBody = $body }
  $e = @{}; if ($c) { $e.credentials = $c }; foreach ($k in $extra.Keys) { $e[$k] = $extra[$k] }
  Node $name 'n8n-nodes-base.httpRequest' 4.2 $p $e
}
function Respond($name, $body, $kind = 'json') { Node $name 'n8n-nodes-base.respondToWebhook' 1.1 ([ordered]@{ respondWith = $kind; responseBody = $body; options = [ordered]@{} }) }
function IfNode($name, $expr) {
  Node $name 'n8n-nodes-base.if' 2 ([ordered]@{ conditions = [ordered]@{
        options = [ordered]@{ caseSensitive = $true; leftValue = ''; typeValidation = 'loose' }
        conditions = @([ordered]@{ id = (Guid-For "$script:wf|$name|c"); leftValue = $expr; rightValue = $true; operator = [ordered]@{ type = 'boolean'; operation = 'true'; singleValue = $true } })
        combinator = 'and' }; options = [ordered]@{} })
}
$retry = @{ retryOnFail = $true; maxTries = 3; waitBetweenTries = 3000 }
$prefer = @(, @('Prefer', 'return=representation'))
$slackPost = 'https://slack.com/api/chat.postMessage'
New-Item -ItemType Directory -Force (Join-Path $root 'n8n\dist') | Out-Null
Write-Host 'Building workflows'

# ---------------- GE-RC-01 New Role: transcript -> job description -> Slack approval ----------------
Start-Wf 'GE-RC-01 New Role (transcript to JD)'
Webhook 'New role webhook' 'ge-rc-new-role' $true
CodeNode 'Build JD request' 'jd-build-request.js'
Http 'Write JD (OpenAI)' 'POST' 'https://api.openai.com/v1/chat/completions' 'openai' '={{ JSON.stringify($json.request) }}' @() $retry 120000
CodeNode 'Check JD' 'jd-check.js'
Http 'Save role' 'POST' "$SB/rest/v1/roles" 'supabase' '={{ JSON.stringify($json) }}' $prefer $retry
CodeNode 'Build Slack message' 'jd-slack-message.js'
Http 'Ask recruiter in Slack' 'POST' $slackPost 'slack' '={{ JSON.stringify($json.slack) }}' @() $retry
Http 'Remember Slack message' 'PATCH' "={{ '$SB/rest/v1/roles?id=eq.' + `$('Build Slack message').first().json.role_id }}" 'supabase' '={{ JSON.stringify({ slack_ts: $json.ts }) }}'
Respond 'Reply to portal' "={{ JSON.stringify({ ok: true, role_id: `$('Build Slack message').first().json.role_id, title: `$('Check JD').first().json.title, status: 'pending_approval' }) }}"
Chain @('New role webhook', 'Build JD request', 'Write JD (OpenAI)', 'Check JD', 'Save role', 'Build Slack message', 'Ask recruiter in Slack', 'Remember Slack message', 'Reply to portal')
Save-Wf 'GE-RC-01-new-role.json'

# ---------------- GE-RC-02 CV Intake: any CV file -> read (incl. scans) -> new / updated / duplicate / unreadable ----------------
Start-Wf 'GE-RC-02 CV Intake'
Webhook 'CV webhook' 'ge-rc-cv-intake' $true
CodeNode 'Build read request' 'cv-build-request.js'
Http 'Read CV (OpenAI)' 'POST' 'https://api.openai.com/v1/responses' 'openai' '={{ JSON.stringify($json.request) }}' @() @{ retryOnFail = $true; maxTries = 2; waitBetweenTries = 3000; onError = 'continueRegularOutput' } 180000
CodeNode 'Check what was read' 'cv-check.js'
Http 'Save CV' 'POST' "$SB/rest/v1/rpc/ingest_cv" 'supabase' '={{ JSON.stringify({ p: $json.p }) }}' @() $retry
Respond 'Reply to uploader' '={{ JSON.stringify($json) }}'
IfNode 'Unreadable?' "={{ `$json.outcome === 'unreadable' }}"
Http 'Flag in Slack' 'POST' $slackPost 'slack' "={{ JSON.stringify({ channel: '$($envs.SLACK_CHANNEL_ID)', text: ':warning: *CV could not be read:* ``' + `$json.file_name + '``\n' + `$json.reason + '\nIt is logged on the portal (CV log) and is NOT searchable. Please ask the candidate for a clear PDF or Word copy.' }) }}" @() $retry
Chain @('CV webhook', 'Build read request', 'Read CV (OpenAI)', 'Check what was read', 'Save CV', 'Reply to uploader', 'Unreadable?', 'Flag in Slack')
Save-Wf 'GE-RC-02-cv-intake.json'

# ---------------- GE-RC-03 Find Candidates: plain-English question -> top 5 (score, reason, CV file) ----------------
Start-Wf 'GE-RC-03 Find Candidates'
Webhook 'Search webhook' 'ge-rc-search' $true
Http 'Load candidate pool' 'GET' "$SB/rest/v1/candidates?select=id,name,email,cv_file,cv_text,jobs&order=id" 'supabase' $null @() ($retry + @{ alwaysOutputData = $true })
CodeNode 'Build search request' 'search-build-request.js'
Http 'Rank candidates (OpenAI)' 'POST' 'https://api.openai.com/v1/chat/completions' 'openai' '={{ JSON.stringify($json.request) }}' @() $retry 120000
CodeNode 'Check results' 'search-check.js'
IfNode 'For a role?' '={{ !!$json.role_id && $json.rows.length > 0 }}'
Http 'Save shortlist' 'POST' "$SB/rest/v1/shortlists?on_conflict=role_id,candidate_id" 'supabase' '={{ JSON.stringify($json.rows) }}' @(, @('Prefer', 'resolution=ignore-duplicates,return=minimal')) $retry
Respond 'Return results' "={{ JSON.stringify(`$('Check results').first().json) }}"
Chain @('Search webhook', 'Load candidate pool', 'Build search request', 'Rank candidates (OpenAI)', 'Check results', 'For a role?', 'Save shortlist', 'Return results')
Link 'For a role?' 'Return results' 1
Save-Wf 'GE-RC-03-find-candidates.json'

# ---------------- GE-RC-04 Slack /ge-find command ----------------
Start-Wf 'GE-RC-04 Slack Ask (/ge-find)'
Webhook 'Slack webhook' 'ge-rc-slack-command' $false $true
Respond 'Acknowledge' "={{ JSON.stringify({ response_type: 'ephemeral', text: ':hourglass_flowing_sand: Reading every CV for: ' + (`$json.body.text || '') }) }}"
Http 'Load settings' 'GET' "$SB/rest/v1/settings?select=key,value" 'supabase' $null @() $retry
CodeNode 'Read command' @('slack-verify.js', 'slack-command-read.js')
Http 'Search CVs' 'POST' "$N8N/webhook/ge-rc-search" 'secret' '={{ JSON.stringify({ question: $json.question }) }}' @() @{} 150000
CodeNode 'Format answer' 'slack-command-answer.js'
Http 'Answer in Slack' 'POST' '={{ $json.url }}' $null '={{ JSON.stringify($json.body) }}' @() $retry
Chain @('Slack webhook', 'Acknowledge', 'Load settings', 'Read command', 'Search CVs', 'Format answer', 'Answer in Slack')
Save-Wf 'GE-RC-04-slack-ask.json'

# ---------------- GE-RC-05 Slack buttons: approve/reject JD, approve/skip candidate ----------------
Start-Wf 'GE-RC-05 Slack Buttons (approvals)'
Webhook 'Slack webhook' 'ge-rc-slack-actions' $false $true
Respond 'Acknowledge' '' 'text'
Http 'Load settings' 'GET' "$SB/rest/v1/settings?select=key,value" 'supabase' $null @() $retry
CodeNode 'Read button' @('slack-verify.js', 'slack-action-read.js')
IfNode 'Job description?' "={{ `$json.kind === 'jd' }}"
Http 'Decide JD' 'POST' "$SB/rest/v1/rpc/decide_role" 'supabase' '={{ JSON.stringify({ p_role: $json.role_id, p_status: $json.status, p_by: $json.user }) }}' @() $retry
CodeNode 'JD decision message' 'jd-decision-message.js'
Http 'Update JD message' 'POST' 'https://slack.com/api/chat.update' 'slack' '={{ JSON.stringify($json.update) }}' @() $retry
IfNode 'Approved?' "={{ `$('JD decision message').first().json.approved }}"
Http 'Build shortlist' 'POST' "$N8N/webhook/ge-rc-search" 'secret' "={{ JSON.stringify({ question: `$('JD decision message').first().json.role.search_query, role_id: `$('JD decision message').first().json.role.id }) }}" @() @{} 150000
CodeNode 'Shortlist message' 'shortlist-message.js'
Http 'Post shortlist' 'POST' $slackPost 'slack' '={{ JSON.stringify($json) }}' @() $retry
Http 'Decide candidate' 'POST' "$SB/rest/v1/rpc/decide_candidate" 'supabase' '={{ JSON.stringify({ p_role: $json.role_id, p_candidate: $json.candidate_id, p_status: $json.status, p_by: $json.user }) }}' @() $retry
CodeNode 'Candidate message' 'cand-decision-message.js'
Http 'Reply in thread' 'POST' $slackPost 'slack' '={{ JSON.stringify($json) }}' @() $retry
Chain @('Slack webhook', 'Acknowledge', 'Load settings', 'Read button', 'Job description?', 'Decide JD', 'JD decision message', 'Update JD message', 'Approved?', 'Build shortlist', 'Shortlist message', 'Post shortlist')
Link 'Job description?' 'Decide candidate' 1
Chain @('Decide candidate', 'Candidate message', 'Reply in thread')
Save-Wf 'GE-RC-05-slack-buttons.json'

if ($BuildOnly) { return }

# ---------------- install in n8n (update by name, then activate) ----------------
Write-Host 'Installing in n8n'
$H = @{ 'X-N8N-API-KEY' = $envs.N8N_API_KEY }; $B = "$N8N/api/v1"
$existing = @{}; (Invoke-RestMethod "$B/workflows?limit=250" -Headers $H).data | % { $existing[$_.name] = $_ }
foreach ($f in (Get-ChildItem (Join-Path $root 'n8n\dist') -Filter 'GE-RC-*.json' | Sort-Object Name)) {
  $wf = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  $bytes = [Text.Encoding]::UTF8.GetBytes(([ordered]@{ name = $wf.name; nodes = $wf.nodes; connections = $wf.connections; settings = $wf.settings } | ConvertTo-Json -Depth 60))
  try {
    if ($existing.Contains($wf.name)) { $id = $existing[$wf.name].id; $null = Invoke-RestMethod -Method Put "$B/workflows/$id" -Headers $H -ContentType 'application/json; charset=utf-8' -Body $bytes; $what = 'updated' }
    else { $id = (Invoke-RestMethod -Method Post "$B/workflows" -Headers $H -ContentType 'application/json; charset=utf-8' -Body $bytes).id; $what = 'created' }
    $null = Invoke-RestMethod -Method Post "$B/workflows/$id/activate" -Headers $H -ContentType 'application/json' -Body '{}'
    Write-Host ("  {0} + active  {1,-36} {2}" -f $what, $wf.name, $id)
  } catch { Write-Host ("  FAILED  {0,-36} {1}" -f $wf.name, $_.ErrorDetails.Message) -ForegroundColor Red }
}
Write-Host "`nWebhook links (for Slack app settings):"
Write-Host "  Slash command /ge-find : $N8N/webhook/ge-rc-slack-command"
Write-Host "  Interactivity          : $N8N/webhook/ge-rc-slack-actions"
