<#
  Publishes the project:
    1) the code to GitHub (everything except .env, which git ignores)
    2) the portal (web\) to Vercel, with its keys as encrypted Vercel environment variables
  Needs GITHUB_USER, GITHUB_TOKEN, VERCEL_TOKEN, PORTAL_PASSCODE in .env.
  Usage: powershell -ExecutionPolicy Bypass -File scripts\publish.ps1 [-SkipGitHub] [-Message "what changed"]
#>
param([switch]$SkipGitHub, [string]$Message = 'Update GE Recruiting Copilot')
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envs = @{}
Get-Content (Join-Path $root '.env') | ? { $_ -match '^\s*([A-Z0-9_]+)=(.*)$' } | % { $envs[$Matches[1]] = $Matches[2].Trim() }
$project = 'ge-recruiting-copilot'

# ---------- 1. GitHub ----------
if (-not $SkipGitHub) {
  Push-Location $root
  try {
    Copy-Item (Join-Path $root 'data\test-questions.json') (Join-Path $root 'web\api\test-questions.json') -Force
    git add -A
    if (git status --porcelain) { git commit -q -m "$Message`n`nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" }
    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-access-token:$($envs.GITHUB_TOKEN)"))
    git -c "http.extraHeader=Authorization: Basic $basic" push -q "https://github.com/$($envs.GITHUB_USER)/$project.git" main
    Write-Host "GitHub: https://github.com/$($envs.GITHUB_USER)/$project"
  } finally { Pop-Location }
}

# ---------- 2. Vercel ----------
$api = 'https://api.vercel.com'
$H = @{ Authorization = "Bearer $($envs.VERCEL_TOKEN)" }
try { $null = Invoke-RestMethod -Method Post "$api/v10/projects" -Headers $H -ContentType 'application/json' -Body (@{ name = $project; framework = $null } | ConvertTo-Json) }
catch { if ($_.Exception.Response.StatusCode.value__ -ne 409) { throw } }   # 409 = already exists

$vars = 'SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY', 'N8N_BASE_URL', 'N8N_WEBHOOK_SECRET', 'GHL_API_KEY', 'GHL_LOCATION_ID', 'PORTAL_PASSCODE'
$body = ConvertTo-Json @($vars | % { @{ key = $_; value = $envs[$_]; type = 'encrypted'; target = @('production', 'preview') } })
$null = Invoke-RestMethod -Method Post "$api/v10/projects/$project/env?upsert=true" -Headers $H -ContentType 'application/json' -Body $body
Write-Host "Vercel: $($vars.Count) environment variables set (encrypted)"

$web = Join-Path $root 'web'
$sha1 = [Security.Cryptography.SHA1]::Create()
$files = foreach ($f in Get-ChildItem $web -Recurse -File) {
  $bytes = [IO.File]::ReadAllBytes($f.FullName)
  $sha = -join ($sha1.ComputeHash($bytes) | % { $_.ToString('x2') })
  $null = Invoke-RestMethod -Method Post "$api/v2/files" -Headers ($H + @{ 'x-vercel-digest' = $sha }) -ContentType 'application/octet-stream' -Body $bytes
  @{ file = $f.FullName.Substring($web.Length + 1).Replace('\', '/'); sha = $sha; size = $bytes.Length }
}
$dep = @{ name = $project; target = 'production'; files = @($files); projectSettings = @{ framework = $null } } | ConvertTo-Json -Depth 6
$d = Invoke-RestMethod -Method Post "$api/v13/deployments?skipAutoDetectionConfirmation=1" -Headers $H -ContentType 'application/json' -Body $dep
Write-Host "Vercel: deploying $($files.Count) files…"
do { Start-Sleep 4; $d = Invoke-RestMethod "$api/v13/deployments/$($d.id)" -Headers $H } while ($d.readyState -in 'QUEUED', 'BUILDING', 'INITIALIZING')
if ($d.readyState -ne 'READY') { throw "Vercel deployment ended as $($d.readyState)" }
$p = Invoke-RestMethod "$api/v9/projects/$project/domains" -Headers $H
Write-Host "Portal live: https://$(@($p.domains)[0].name)"
