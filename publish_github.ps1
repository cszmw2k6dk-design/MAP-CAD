# publish_github.ps1 - one-click release to GitHub (build bundle + manifest + GitHub Release)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File publish_github.ps1 -Version 2.22 -Repo CSZMW2K6DK-Design/MAP-CAD -Note "fix ..."
#
# What it does:
#   1) calls make_release.ps1 in GitHub mode  -> clean zip + version.json (compact JSON)
#   2) copies version.json to the repo root and commits the changed sources
#   3) pushes to origin (unless -SkipPush)
#   4) creates/updates the GitHub Release (tag) and uploads the zip asset
#   5) verifies the asset URL and the manifest URL, purges the jsDelivr cache
#   6) prints the client-side setting to paste into PdfLayout.lsp
#
# Auth: `gh` CLI if available, otherwise -Token / $env:GITHUB_TOKEN (repo scope).
param(
  [Parameter(Mandatory=$true)][string]$Version,
  [Parameter(Mandatory=$true)][string]$Repo,          # owner/name
  [string]$Branch = "main",
  [string]$Tag = "",
  [string]$Note = "",
  [string]$Root = ".",
  [string]$Token = $env:GITHUB_TOKEN,
  [string]$Remote = "origin",
  [switch]$SkipBuild,
  [switch]$SkipPush,
  [switch]$NoCommit,
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$utf8 = New-Object System.Text.UTF8Encoding($false)

if ($Tag -eq "") { $Tag = "v$Version" }
$assetName = "MAP-CAD_v$Version.zip"
$releaseUrl = "https://github.com/$Repo/releases/download/$Tag/$assetName"
$manifestUrlRaw = "https://raw.githubusercontent.com/$Repo/$Branch/version.json"
$manifestUrlCdn = "https://cdn.jsdelivr.net/gh/$Repo@$Branch/version.json"

$rootFull = (Resolve-Path -LiteralPath $Root).Path
Write-Host "== MAP release =="
Write-Host ("repo        : {0}" -f $Repo)
Write-Host ("version     : {0}   tag: {1}   branch: {2}" -f $Version, $Tag, $Branch)
Write-Host ("asset       : {0}" -f $assetName)
Write-Host ("release url : {0}" -f $releaseUrl)

# ---------- 1) build ----------
if ($SkipBuild) {
  Write-Host "build       : skipped (-SkipBuild)"
} else {
  $mk = Join-Path $rootFull "make_release.ps1"
  if (-not (Test-Path -LiteralPath $mk)) { throw "not found: $mk" }
  & powershell -NoProfile -ExecutionPolicy Bypass -File $mk `
      -Version $Version -GitHub "$Repo@$Branch" -Note $Note `
      -ZipName $assetName -WithManifest -Root $rootFull
  if ($LASTEXITCODE -ne 0) { throw "make_release.ps1 failed with exit code $LASTEXITCODE" }
}

$outDir = Join-Path $rootFull "MAP工具箱"
$zipPath = Join-Path $outDir $assetName
$manifestSrc = Join-Path $outDir "version.json"
if (-not (Test-Path -LiteralPath $zipPath)) { throw "release zip not found: $zipPath" }
if (-not (Test-Path -LiteralPath $manifestSrc)) { throw "version.json not found: $manifestSrc (需要 -WithManifest)" }

$manifestPath = Join-Path $rootFull "version.json"
Copy-Item -LiteralPath $manifestSrc -Destination $manifestPath -Force
Write-Host ("manifest    : {0}" -f $manifestPath)
Write-Host ("content     : {0}" -f ([System.IO.File]::ReadAllText($manifestPath, $utf8)))

if ($DryRun) {
  Write-Host "dry run     : stop before git/upload"
  exit 0
}

# ---------- 2) commit ----------
$repoPaths = @(
  "PdfLayout.lsp", "PdfLayout.dcl", "PdfLayout.cuix", "PdfLayout.bundle",
  "version.json", "README.md", "make_release.ps1", "publish_github.ps1"
) | Where-Object { Test-Path -LiteralPath (Join-Path $rootFull $_) }

if ($NoCommit) {
  Write-Host "git commit  : skipped (-NoCommit)"
} else {
  Push-Location $rootFull
  try {
    if (-not (Test-Path -LiteralPath (Join-Path $rootFull ".git"))) {
      Write-Host "git init    : (no .git found)"
      git init | Out-Null
    }
    git add -- $repoPaths
    $staged = git diff --cached --name-only
    if ($staged) {
      git -c user.name="MAP Release" -c user.email="map-release@local" commit -m "release: MAP工具箱 v$Version" | Write-Host
    } else {
      Write-Host "git commit  : nothing staged"
    }
    if ($SkipPush) {
      Write-Host "git push    : skipped (-SkipPush)"
    } else {
      $remotes = git remote
      if ($remotes -notcontains $Remote) {
        Write-Host ("git remote  : adding {0} -> https://github.com/{1}.git" -f $Remote, $Repo)
        git remote add $Remote "https://github.com/$Repo.git"
      }
      git push $Remote "HEAD:$Branch"
    }
  } finally {
    Pop-Location
  }
}

# ---------- 3) release + asset upload ----------
$gh = Get-Command gh -ErrorAction SilentlyContinue
$body = if ($Note -ne "") { $Note } else { "MAP工具箱 v$Version" }

if ($gh) {
  Write-Host "upload      : via gh CLI"
  $existing = $null
  try { $existing = gh release view $Tag --repo $Repo --json tagName 2>$null } catch { $existing = $null }
  if ($existing) {
    gh release upload $Tag $zipPath --repo $Repo --clobber
    Write-Host "asset       : re-uploaded (existing release)"
  } else {
    gh release create $Tag $zipPath --repo $Repo --title "MAP工具箱 v$Version" --notes $body
  }
} elseif ($Token) {
  Write-Host "upload      : via REST API"
  $headers = @{
    Authorization = "token $Token"
    "User-Agent"  = "MAP-Release"
    Accept        = "application/vnd.github+json"
  }
  $api = "https://api.github.com/repos/$Repo/releases"
  $release = $null
  try {
    $release = Invoke-RestMethod -Method Get -Uri "$api/tags/$Tag" -Headers $headers
  } catch {
    $release = $null
  }
  if (-not $release) {
    $payload = @{ tag_name = $Tag; name = "MAP工具箱 v$Version"; body = $body; draft = $false; prerelease = $false } |
      ConvertTo-Json -Compress
    $release = Invoke-RestMethod -Method Post -Uri $api -Headers $headers -Body $payload -ContentType "application/json"
    Write-Host ("release     : created id={0}" -f $release.id)
  } else {
    Write-Host ("release     : exists id={0}" -f $release.id)
  }
  # replace an asset with the same name
  foreach ($a in @($release.assets)) {
    if ($a.name -eq $assetName) {
      Invoke-RestMethod -Method Delete -Uri $a.url -Headers $headers | Out-Null
      Write-Host ("asset       : removed old {0}" -f $a.name)
    }
  }
  $uploadUrl = ("https://uploads.github.com/repos/{0}/releases/{1}/assets?name={2}" -f $Repo, $release.id, $assetName)
  Invoke-RestMethod -Method Post -Uri $uploadUrl -Headers $headers -InFile $zipPath -ContentType "application/zip" | Out-Null
  Write-Host "asset       : uploaded"
} else {
  Write-Warning "no gh CLI and no -Token/GITHUB_TOKEN: skipped Release upload."
  Write-Host "manual step : 打开 https://github.com/$Repo/releases/new 新建 tag $Tag，把下面这个文件作为附件上传："
  Write-Host ("              {0}" -f $zipPath)
}

# ---------- 4) verify ----------
Start-Sleep -Seconds 3
try {
  $hashLocal = (Get-FileHash -LiteralPath $zipPath -Algorithm MD5).Hash.ToLowerInvariant()
  $head = Invoke-WebRequest -Method Head -Uri $releaseUrl -UseBasicParsing -TimeoutSec 30
  Write-Host ("verify zip  : HTTP {0}  (本地 MD5 {1})" -f $head.StatusCode, $hashLocal)
} catch {
  Write-Warning "zip URL not reachable yet: $releaseUrl"
}

$manifestOk = $false
foreach ($url in @($manifestUrlRaw, $manifestUrlCdn)) {
  for ($i = 1; $i -le 6 -and -not $manifestOk; $i++) {
    try {
      $txt = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20).Content
      if ($txt -match ('"version":"' + [regex]::Escape($Version) + '"')) {
        Write-Host "verify json : OK  $url"
        $manifestOk = $true
      } else {
        Write-Host "verify json : stale cache, retry $i  $url"
        Start-Sleep -Seconds 10
      }
    } catch {
      Write-Host "verify json : unreachable, retry $i  $url"
      Start-Sleep -Seconds 5
    }
  }
  if ($manifestOk) { break }
}
if (-not $manifestOk) {
  Write-Warning "manifest not serving v$Version yet (CDN cache). 稍等几分钟，或对 jsDelivr 执行 purge。"
}

try {
  Invoke-RestMethod -Uri ("https://purge.jsdelivr.net/gh/{0}@{1}/version.json" -f $Repo, $Branch) -TimeoutSec 20 | Out-Null
  Write-Host "jsdelivr    : purge requested"
} catch {
  Write-Host "jsdelivr    : purge skipped"
}

Write-Host ""
Write-Host "== client setting (PdfLayout.lsp) =="
Write-Host ("(setq *PdfLayout_UpdateUrl* `"github:{0}@{1}`")" -f $Repo, $Branch)
Write-Host ""
Write-Host "== done =="
