<#
  Asks the bot the 10 test questions (data\test-questions.json) through the real search workflow,
  grades each answer and saves the run to Supabase (shown on the portal Test page).
  PASS = the bot returned exactly the expected people (each once); for "no match" questions, nobody.
  Usage: powershell -ExecutionPolicy Bypass -File scripts\run-tests.ps1
#>
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envs = @{}
Get-Content (Join-Path $root '.env') | ? { $_ -match '^\s*([A-Z0-9_]+)=(.*)$' } | % { $envs[$Matches[1]] = $Matches[2].Trim() }
$tests = (Get-Content (Join-Path $root 'data\test-questions.json') -Raw -Encoding UTF8 | ConvertFrom-Json).questions
$url = "$($envs.N8N_BASE_URL.TrimEnd('/'))/webhook/ge-rc-search"
$norm = { param($s) ($s.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '').ToLower().Trim() }

$details = @(); $score = 0
foreach ($t in $tests) {
  $body = [Text.Encoding]::UTF8.GetBytes((@{ question = $t.q } | ConvertTo-Json))
  $r = Invoke-RestMethod -Method Post $url -Headers @{ 'x-ge-rc-secret' = $envs.N8N_WEBHOOK_SECRET } -ContentType 'application/json; charset=utf-8' -Body $body -TimeoutSec 180
  $got = @($r.matches | % { & $norm $_.name })
  $exp = @($t.expected | % { & $norm $_ })
  $missing = @($exp | ? { $got -notcontains $_ }); $extra = @($got | ? { $exp -notcontains $_ })
  $twice = $got.Count -ne @($got | Select-Object -Unique).Count
  $pass = (-not $missing.Count) -and (-not $extra.Count) -and (-not $twice)
  if ($pass) { $score++ }
  $details += [ordered]@{ id = $t.id; question = $t.q; expected = $t.expected; why = $t.why; pass = $pass
    bot = @($r.matches | % { [ordered]@{ name = $_.name; score = $_.score; reason = $_.reason; cv_file = $_.cv_file } })
    bot_message = $r.message; missing = $missing; extra = $extra }
  Write-Host ("{0,2}. {1}  {2}" -f $t.id, $(if ($pass) { 'PASS' } else { 'FAIL' }), $t.q)
  if (-not $pass) { Write-Host "      expected: $($t.expected -join ', ')`n      bot said: $(($r.matches | % { "$($_.name) ($($_.score))" }) -join ', ')  $($r.note)" -ForegroundColor Yellow }
}
Write-Host "`nSCORE: $score / $($tests.Count)"
$sb = @{ apikey = $envs.SUPABASE_SERVICE_ROLE_KEY; Authorization = "Bearer $($envs.SUPABASE_SERVICE_ROLE_KEY)" }
$row = [Text.Encoding]::UTF8.GetBytes((@{ score = $score; total = $tests.Count; details = $details } | ConvertTo-Json -Depth 10))
Invoke-RestMethod -Method Post "$($envs.SUPABASE_URL)/rest/v1/test_runs" -Headers $sb -ContentType 'application/json; charset=utf-8' -Body $row | Out-Null
Write-Host 'Saved to Supabase (test_runs).'
