<#
  1) Saves the run-time settings n8n needs into Supabase (Slack signing secret, test inbox, GHL form link).
  2) Sends every CV file through the real n8n intake (GE-RC-02), one at a time, and prints what happened to each.
  Usage:  powershell -ExecutionPolicy Bypass -File scripts\load-cvs.ps1                     (data\cvs + data\hard-cases)
          powershell -ExecutionPolicy Bypass -File scripts\load-cvs.ps1 -SettingsOnly [-GhlFormUrl <link>]
#>
param([switch]$SettingsOnly, [string]$GhlFormUrl = '', [string[]]$Folders = @('data\cvs', 'data\hard-cases'))
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envs = @{}
Get-Content (Join-Path $root '.env') | ? { $_ -match '^\s*([A-Z0-9_]+)=(.*)$' } | % { $envs[$Matches[1]] = $Matches[2].Trim() }

$sb = @{ apikey = $envs.SUPABASE_SERVICE_ROLE_KEY; Authorization = "Bearer $($envs.SUPABASE_SERVICE_ROLE_KEY)"; Prefer = 'resolution=merge-duplicates' }
$rows = @(@{ key = 'slack_signing_secret'; value = $envs.SLACK_SIGNING_SECRET }, @{ key = 'test_inbox'; value = $envs.TEST_INBOX })
if ($GhlFormUrl) { $rows += @{ key = 'ghl_form_url'; value = $GhlFormUrl } }
Invoke-RestMethod -Method Post "$($envs.SUPABASE_URL)/rest/v1/settings?on_conflict=key" -Headers $sb -ContentType 'application/json' -Body (ConvertTo-Json $rows) | Out-Null
Write-Host "Settings saved: $(($rows | % { $_.key }) -join ', ')"
if ($SettingsOnly) { return }

$url = "$($envs.N8N_BASE_URL.TrimEnd('/'))/webhook/ge-rc-cv-intake"
$hdr = @{ 'x-ge-rc-secret' = $envs.N8N_WEBHOOK_SECRET }
$files = foreach ($f in $Folders) { Get-ChildItem (Join-Path $root $f) -File | Sort-Object Name }
$i = 0
foreach ($f in $files) {
  $i++
  $body = @{ file_name = $f.Name; data_base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName)) } | ConvertTo-Json
  try {
    $r = Invoke-RestMethod -Method Post $url -Headers $hdr -ContentType 'application/json' -Body $body -TimeoutSec 240
    $info = if ($r.outcome -eq 'unreadable') { $r.reason } else { "$($r.name) - $($r.detail)" }
    Write-Host ("[{0,2}/{1}] {2,-14} {3,-44} {4}" -f $i, $files.Count, $r.outcome, $f.Name, $info)
  } catch { Write-Host ("[{0,2}/{1}] ERROR          {2,-44} {3}" -f $i, $files.Count, $f.Name, $_.Exception.Message) -ForegroundColor Red }
}
