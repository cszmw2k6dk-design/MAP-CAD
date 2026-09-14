# make_release.ps1 - Build clean release bundle + version.json
# Usage:
#   powershell -ExecutionPolicy Bypass -File make_release.ps1 -Version 2.18 -UpdateUrl "https://host/map/version.json" -ReleaseUrl "https://host/map/MAP_v2.18.zip" -Note "fix ..."
#   powershell -ExecutionPolicy Bypass -File make_release.ps1 -Version 2.22 -GitHub "owner/repo@main" -Note "fix ..."     # GitHub 模式（推荐）
# If -UpdateUrl/-ReleaseUrl omitted, the plugin keeps empty URL (update check stays off until set).
# -UpdateUrl 为空时保留源码里已有的更新源；要清空请显式加 -ClearUpdateUrl。
# The release zip is named "MAP工具箱_v{Version}.zip" by default (version in the file name); override with -ZipName.
# 默认只出「zip + 散装 lsp/dcl」，不生成 version.json / update.html（在线更新方案不进发布版）。
# 需要在线更新清单时才加 -WithManifest。（-NoManifest 仍兼容，效果相同=不生成）
# The loose files PdfLayout.lsp + PdfLayout.dcl are always copied into the release folder as well,
# for the "APPLOAD the lsp directly" install path (no .cuix / icons there on purpose).
param(
  [string]$Version = "2.18",
  [string]$UpdateUrl = "",
  [string]$ReleaseUrl = "",
  [string]$Note = "",
  [string]$ZipName = "",
  [string]$GitHub = "",
  [string]$MinVersion = "",
  [switch]$Mandatory,
  [switch]$NoManifest,
  [switch]$WithManifest,
  [switch]$ClearUpdateUrl,
  [string]$Root = "."
)
$ErrorActionPreference = "Stop"
$gbk  = [System.Text.Encoding]::GetEncoding(936)
$utf8 = New-Object System.Text.UTF8Encoding($false)

# 0a) GitHub 快捷模式：-GitHub owner/repo[@branch]
#     自动推导更新源(github:owner/repo@branch)与 Release 下载地址，并强制出在线更新清单。
if ($GitHub -ne "") {
  $spec = $GitHub
  $branch = "main"
  if ($spec -match '@([^@]+)$') {
    $branch = $Matches[1]
    $spec = $spec -replace '@[^@]+$', ''
  }
  $UpdateUrl = "github:$spec@$branch"
  if ([string]::IsNullOrWhiteSpace($ZipName)) { $ZipName = "MAP-CAD_v$Version.zip" }
  if ($ReleaseUrl -eq "") {
    $ReleaseUrl = "https://github.com/$spec/releases/download/v$Version/$ZipName"
  }
  $WithManifest = $true
  Write-Host "github mode : repo=$spec branch=$branch"
  Write-Host "update url  : $UpdateUrl"
  Write-Host "release url : $ReleaseUrl"
}

$bundle = Join-Path $Root "PdfLayout.bundle"
if (-not (Test-Path $bundle)) { throw "Not found: $bundle" }

# 0) Sync root sources -> bundle (prevents the release from lagging behind the latest lsp/dcl/cuix)
foreach ($n in @("PdfLayout.lsp", "PdfLayout.dcl", "PdfLayout.cuix")) {
  $src = Join-Path $Root $n
  $dst = Join-Path (Join-Path $bundle "Contents") $n
  if ((Test-Path $src) -and (Test-Path (Split-Path $dst))) {
    $same = $false
    if (Test-Path $dst) { $same = ((Get-FileHash -LiteralPath $src -Algorithm MD5).Hash -eq (Get-FileHash -LiteralPath $dst -Algorithm MD5).Hash) }
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Write-Host ("synced      : {0} {1}" -f $n, $(if ($same) { "(unchanged)" } else { "(updated)" }))
  }
}

# 1) Patch version + update url inside bundle LSP (GBK)
$lsp = Join-Path $bundle "Contents\PdfLayout.lsp"
$lspFull = (Resolve-Path $lsp).Path
$t = [System.IO.File]::ReadAllText($lspFull, $gbk)
$t = [regex]::Replace($t, '(?m)^\((setq|defvar) \*PdfLayout_Version\*.*$', '($1 *PdfLayout_Version* "' + $Version + '")')
# 更新源：传了 -UpdateUrl 才覆盖；否则保留源码里已有的值（避免误清空更新源）
if ($UpdateUrl -ne "" -or $ClearUpdateUrl) {
  $t = [regex]::Replace($t, '(?m)^\((setq|defvar) \*PdfLayout_UpdateUrl\*.*$', '($1 *PdfLayout_UpdateUrl* "' + $UpdateUrl + '")')
  Write-Host ("update url  : {0}" -f $(if ($UpdateUrl -eq "") { "(cleared)" } else { $UpdateUrl }))
} else {
  Write-Host "update url  : kept (未传 -UpdateUrl，保留源码里现有的更新源)"
}
# also refresh the display version (header / dialog title / load message) so it never drifts
$t = [regex]::Replace($t, 'MAP工具箱 PdfLayout\.lsp\s+v\d+(\.\d+)*', 'MAP工具箱 PdfLayout.lsp  v' + $Version)
$t = [regex]::Replace($t, 'MAP工具箱 v\d+(\.\d+)*', 'MAP工具箱 v' + $Version)
[System.IO.File]::WriteAllText($lspFull, $t, $gbk)

# 1b) Patch version string inside DCL (GBK)
$dcl = Join-Path $bundle "Contents\PdfLayout.dcl"
if (Test-Path $dcl) {
  $dclFull = (Resolve-Path $dcl).Path
  $d = [System.IO.File]::ReadAllText($dclFull, $gbk)
  $d = [regex]::Replace($d, 'MAP工具箱 v\d+(\.\d+)*', 'MAP工具箱 v' + $Version)
  [System.IO.File]::WriteAllText($dclFull, $d, $gbk)
}

# 2) Patch PackageContents.xml version (UTF-8, preserves Chinese)
$xml = Join-Path $bundle "PackageContents.xml"
$xmlFull = (Resolve-Path $xml).Path
$x = [System.IO.File]::ReadAllText($xmlFull, $utf8)
$x = [regex]::Replace($x, 'AppVersion="\d+\.\d+\.\d+"', 'AppVersion="' + $Version + '.0"')
$x = [regex]::Replace($x, 'Version="\d+\.\d+\.\d+"', 'Version="' + $Version + '.0"')
[System.IO.File]::WriteAllText($xmlFull, $x, $utf8)

# 3) Build clean zip (exclude scratch files)
$outDir = Join-Path $Root "MAP工具箱"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outDir = (Resolve-Path -LiteralPath $outDir).Path   # absolute: [System.IO.File] 用的是进程工作目录，不是 PS 当前位置
if ([string]::IsNullOrWhiteSpace($ZipName)) { $ZipName = "MAP工具箱_v" + $Version + ".zip" }
$zip = Join-Path $outDir $ZipName
$stage = Join-Path $env:TEMP ("pdl_rel_" + [guid]::NewGuid().ToString("N"))
$stageB = Join-Path $stage "PdfLayout.bundle"
New-Item -ItemType Directory -Path $stageB | Out-Null
Copy-Item (Join-Path $bundle "PackageContents.xml") -Destination $stageB
$cSrc = Join-Path $bundle "Contents"; $cDst = Join-Path $stageB "Contents"
New-Item -ItemType Directory -Path $cDst | Out-Null
Copy-Item (Join-Path $cSrc "PdfLayout.lsp") -Destination $cDst
Copy-Item (Join-Path $cSrc "PdfLayout.dcl") -Destination $cDst
Copy-Item (Join-Path $cSrc "PdfLayout.cuix") -Destination $cDst
Copy-Item -Recurse (Join-Path $cSrc "icons") -Destination $cDst
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path $stageB -DestinationPath $zip -Force
Remove-Item -Recurse -Force -LiteralPath $stage

# 3b) 散装文件：直接放到 MAP工具箱 发布目录，供 APPLOAD 等方式单独加载 lsp 使用
#     只放 lsp + dcl（不放 cuix / icons，走加载路径的人不需要工具栏文件）
foreach ($n in @("PdfLayout.lsp", "PdfLayout.dcl")) {
  Copy-Item -LiteralPath (Join-Path $cSrc $n) -Destination $outDir -Force
}
Write-Host ("loose files : lsp + dcl copied into {0}" -f $outDir)

# 3c) 发布版散装 lsp：剔除 CUIX（工具栏）相关代码——走加载路径的人没有 cuix 文件，
#     留着只会每次加载都提示"未找到 PdfLayout.cuix"。源码里用 ;;;@CUIX-BEGIN / ;;;@CUIX-END
#     标记要剔除的区域；zip 里的 bundle 版本保持原样（bundle 自带 cuix）。
$looseLsp = Join-Path $outDir "PdfLayout.lsp"
$lt = [System.IO.File]::ReadAllText($looseLsp, $gbk)
$lt2 = [regex]::Replace($lt, '(?s);;;@CUIX-BEGIN.*?;;;@CUIX-END[ \t]*\r?\n', '')
if ($lt2 -eq $lt) {
  Write-Warning "loose lsp   : 未找到 ;;;@CUIX-BEGIN / ;;;@CUIX-END 标记，cuix 代码可能没被剔除"
} else {
  [System.IO.File]::WriteAllText($looseLsp, $lt2, $gbk)
  $blocks = ([regex]::Matches($lt, ';;;@CUIX-BEGIN')).Count
  $left = ([regex]::Matches($lt2, '(?i)cuix')).Count
  Write-Host ("loose lsp   : 已剔除 cuix 相关代码 {0} 处，剩余 cuix 字样 {1} 个" -f $blocks, $left)
}

# 4) MD5
$hash = (Get-FileHash -LiteralPath $zip -Algorithm MD5).Hash.ToLowerInvariant()

# 5) Compact version.json (no space after colon, so the LISP parser can read it)
# ReleaseUrl is used as-is. If left empty, version.json stores "" and the plugin
# simply won't print a download line (e.g. Teams/OneDrive mode has no clickable URL).
$NoteJson = $Note -replace '\\', '\\' -replace '"', '\"'
$json = '{"version":"' + $Version + '","release_url":"' + $ReleaseUrl + '","md5":"' + $hash + '","releasenote":"' + $NoteJson + '"'
if ($MinVersion -ne "") { $json += ',"min_version":"' + $MinVersion + '"' }
$json += ',"mandatory":' + $(if ($Mandatory) { 'true' } else { 'false' })
$json += ',"released":"' + (Get-Date -Format "yyyy-MM-dd") + '"}'
$vjson = Join-Path $outDir "version.json"
$writeManifest = ($WithManifest -and -not $NoManifest)
if (-not $writeManifest) {
  Write-Host "manifest    : skipped (默认不出在线更新清单；需要时加 -WithManifest)"
} else {
  [System.IO.File]::WriteAllText($vjson, $json, $utf8)  # compact JSON, uppercase hex md5 -> lowercased above
}

# 6) Generate a human-friendly update.html (same data as version.json)
$tpl = Join-Path $Root "update_template.html"
if ($writeManifest -and (Test-Path $tpl)) {
  $html = Join-Path $outDir "update.html"
  $h = [System.IO.File]::ReadAllText($tpl, $utf8)
  $h = $h.Replace("@@VER@@", $Version)
  $h = $h.Replace("@@NOTE@@", $Note)
  $h = $h.Replace("@@MD5@@", $hash)
  $h = $h.Replace("@@DATE@@", (Get-Date -Format "yyyy-MM-dd HH:mm"))
  $h = $h.Replace("@@ZIP@@", $ZipName)
  [System.IO.File]::WriteAllText($html, $h, $utf8)
  Write-Host "update html : $html"
}
if (-not $writeManifest) { Write-Host "update html : skipped (默认不出在线更新页面；需要时加 -WithManifest)" }

Write-Host "OK zip      : $zip"
Write-Host "MD5         : $hash"
Write-Host "manifest    : " ($(if ($writeManifest) { $vjson } else { "(不生成)" }))
Write-Host "App/Ver     : $Version"
