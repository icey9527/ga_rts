param(
    [string]$Source = "E:\02\GAELpak\020",
    [string]$Dest = "E:\ai_rts-main\rts_game\assets",
    [switch]$All
)

$ErrorActionPreference = "Stop"

$folders = @{
    backgrounds = Join-Path $Dest "backgrounds"
    effects     = Join-Path $Dest "effects"
    ships       = Join-Path $Dest "ships"
    ui          = Join-Path $Dest "ui"
    raw         = Join-Path $Dest "raw"
}

foreach ($p in $folders.Values) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}

function Get-AssetCategory {
    param([string]$Name)
    $n = $Name.ToLowerInvariant()

    if ($n -match '^(testbg|bg|nebula|space|star|sky|galaxy|ob12)') { return "backgrounds" }
    if ($n -match '^(oe|effect)|beam|thrust|flare|glow|spark|burst|smoke|trail|expl|shock|ring|laser|shot|bullet') { return "effects" }
    if ($n -match '^(ou)|ship|fighter|bomber|interceptor|scout|repair|mothership|unit|craft|mox') { return "ships" }
    if ($n -match 'ui|menu|button|frame|panel|hud|icon|cursor') { return "ui" }
    return "raw"
}

$selected = @(
    "testbg_*.bmp.png",
    "testbg_*.bmp",
    "ob12*.bmp.png",
    "ob12*.bmp",
    "beam*.bmp.png",
    "beam*.bmp",
    "thrusterg*.dds",
    "thrustergs*.dds",
    "oe0*.dds",
    "oe0*.tbl",
    "oe1*.dds",
    "oe1*.tbl"
)

$files = if ($All) {
    Get-ChildItem -LiteralPath $Source -File
} else {
    foreach ($pattern in $selected) {
        Get-ChildItem -LiteralPath $Source -File -Filter $pattern
    }
}

$files | Sort-Object FullName -Unique | ForEach-Object {
    $category = Get-AssetCategory -Name $_.Name
    $target = Join-Path $Dest $category
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target $_.Name) -Force
}

Write-Host "Imported curated GAELpak assets. Backgrounds use bg/testbg/ob12-style names; ou* goes to ships, oe*/beam/thrust goes to effects."
