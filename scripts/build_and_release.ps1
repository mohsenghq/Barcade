<#
.SYNOPSIS
    Local build + release script for Starcade.
    Builds platforms available on this PC and uploads to a GitHub Release.

.DESCRIPTION
    Since GitHub Actions has billing issues, this script runs builds locally
    and uploads release assets directly via `gh` CLI.

    Supported platforms (no special SDK required):
      - Web          ✅ always
      - Windows      ⚠️  requires Visual Studio Build Tools

    NOT supported locally (geo-blocked or no Mac):
      - Android      ❌ dl.google.com is geo-blocked
      - macOS        ❌ requires macOS
      - iOS          ❌ requires macOS

    Usage:
      .\scripts\build_and_release.ps1 v2.1.0
      .\scripts\build_and_release.ps1 v2.1.0 -SkipUpload
      .\scripts\build_and_release.ps1 v2.1.0 -Platforms web,windows

.PARAMETER Tag
    Version tag for the release (e.g., v2.1.0). Required.

.PARAMETER Platforms
    Comma-separated list of platforms to build. Default: "web".
    Options: web, windows

.PARAMETER SkipUpload
    Build but don't upload to GitHub Release.

.PARAMETER SkipBuild
    Upload existing build artifacts without rebuilding.

.EXAMPLE
    .\scripts\build_and_release.ps1 v2.1.0
    # Builds web, packages it, creates GitHub Release, uploads starcade-web.zip

.EXAMPLE
    .\scripts\build_and_release.ps1 v2.1.0 -Platforms web,windows
    # Builds both web and windows, uploads both
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Tag,

    [Parameter(Mandatory=$false)]
    [string]$Platforms = "web",

    [Parameter(Mandatory=$false)]
    [switch]$SkipUpload,

    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# ── Configuration ────────────────────────────────────────────────────
$FlutterBin = "$env:HOME\flutter_sdk\flutter\bin\flutter.bat"
$DartBin = "$env:HOME\flutter_sdk\flutter\bin\cache\dart-sdk\bin\dart.exe"

# Environment for Chinese mirror (bypass geo-blocking)
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:PATH = "$env:HOME\flutter_sdk\flutter\bin;$env:HOME\flutter_sdk\flutter\bin\cache\dart-sdk\bin;$env:PATH"

$BuildDir = "build"
$ReleaseDir = "release_packages"
$AppName = "starcade"

# ── Helpers ──────────────────────────────────────────────────────────
function Write-Step($msg) { Write-Host "`n▸ $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "  ✗ $msg" -ForegroundColor Red }

function Test-Flutter {
    if (-not (Test-Path $FlutterBin)) {
        Write-Fail "Flutter not found at $FlutterBin"
        Write-Host "  Install from: https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.9-stable.zip" -ForegroundColor Yellow
        exit 1
    }
}

function Test-Gh {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Fail "GitHub CLI (gh) not found. Install: winget install GitHub.cli"
        exit 1
    }
    $status = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    }
    Write-Ok "gh CLI authenticated"
}

function Find-VS {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $installPath = & $vswhere -latest -property installationPath 2>$null
        if ($installPath) {
            $vcvars = Join-Path $installPath "VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvars) {
                return $vcvars
            }
        }
    }
    return $null
}

# ── Pre-flight checks ───────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Starcade Local Build + Release" -ForegroundColor Magenta
Write-Host "  Tag: $Tag" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta

Test-Flutter
if (-not $SkipUpload) { Test-Gh }

$platformList = $Platforms -split "," | ForEach-Object { $_.Trim().ToLower() }

# ── Ensure clean release_packages dir ────────────────────────────────
if (-not $SkipBuild) {
    if (Test-Path $ReleaseDir) { Remove-Item -Recurse -Force $ReleaseDir }
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

# ── Flutter pub get ──────────────────────────────────────────────────
Write-Step "Resolving dependencies"
& $FlutterBin pub get
if ($LASTEXITCODE -ne 0) { Write-Fail "flutter pub get failed"; exit 1 }
Write-Ok "Dependencies resolved"

# ── Analyze ──────────────────────────────────────────────────────────
Write-Step "Running static analysis"
& $FlutterBin analyze
if ($LASTEXITCODE -ne 0) { Write-Fail "Analysis failed"; exit 1 }
Write-Ok "Analysis passed"

# ── Tests ────────────────────────────────────────────────────────────
Write-Step "Running tests"
& $FlutterBin test
if ($LASTEXITCODE -ne 0) { Write-Fail "Tests failed"; exit 1 }
Write-Ok "All tests passed"

# ── Build Web ────────────────────────────────────────────────────────
if ($platformList -contains "web" -and -not $SkipBuild) {
    Write-Step "Building Web"
    & $FlutterBin build web --release
    if ($LASTEXITCODE -ne 0) { Write-Fail "Web build failed"; exit 1 }

    # Package web build as zip using Node.js (PowerShell Compress-Archive is slow)
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $zipHelper = Join-Path $scriptDir "zip_helper.mjs"
    $webZip = Join-Path $ReleaseDir "$AppName-web.zip"
    Push-Location $PSScriptRoot
    node $zipHelper 2>&1 | Write-Host
    Pop-Location
    if (Test-Path "$PSScriptRoot\$AppName-web.zip") {
        Move-Item "$PSScriptRoot\$AppName-web.zip" $webZip -Force
    }
    $webSize = [math]::Round((Get-Item $webZip).Length / 1MB, 1)
    Write-Ok "Web build: $webZip ($webSize MB)"
}

# ── Build Windows ────────────────────────────────────────────────────
if ($platformList -contains "windows" -and -not $SkipBuild) {
    Write-Step "Building Windows Desktop"
    $vcvars = Find-VS
    if (-not $vcvars) {
        Write-Fail "Visual Studio Build Tools not found"
        Write-Host "  Install with: winget install Microsoft.VisualStudio.2022.BuildTools" -ForegroundColor Yellow
        Write-Host "  Then add 'Desktop development with C++' workload" -ForegroundColor Yellow
        Write-Host "  Skipping Windows build." -ForegroundColor Yellow
    } else {
        & $FlutterBin build windows --release
        if ($LASTEXITCODE -ne 0) { Write-Fail "Windows build failed"; exit 1 }

        $winZip = Join-Path $ReleaseDir "$AppName-windows.zip"
        $winBuildDir = Join-Path $BuildDir "windows\x64\runner\Release"
        # Use Node.js for faster zipping
        $origDir = Get-Location
        Set-Location $winBuildDir
        $zipScript = Join-Path $PSScriptRoot "zip_helper.mjs"
        node $zipScript 2>&1 | Write-Host
        Set-Location $origDir
        if (Test-Path "$PSScriptRoot\$AppName-windows.zip") {
            Move-Item "$PSScriptRoot\$AppName-windows.zip" $winZip -Force
        }
        $winSize = [math]::Round((Get-Item $winZip).Length / 1MB, 1)
        Write-Ok "Windows build: $winZip ($winSize MB)"
    }
}

# ── Summary ──────────────────────────────────────────────────────────
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Build Summary" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Magenta

$assets = @()
Get-ChildItem -Path $ReleaseDir -Filter "*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 1)
    Write-Host "  📦 $($_.Name) ($sizeMB MB)" -ForegroundColor White
    $assets += $_.FullName
}

if ($assets.Count -eq 0) {
    Write-Fail "No build artifacts produced"
    exit 1
}

# ── Upload to GitHub Release ─────────────────────────────────────────
if ($SkipUpload) {
    Write-Host "`n⏭  Skipping upload (-SkipUpload flag)" -ForegroundColor Yellow
    Write-Host "  Artifacts in: $ReleaseDir\" -ForegroundColor Yellow
    Write-Host "`n  To upload manually:" -ForegroundColor Yellow
    $assetArgs = ($assets | ForEach-Object { "`"$_`"" }) -join " "
    Write-Host "    gh release create `"$Tag`" --title `"Starcade $Tag`" --generate-notes $assetArgs" -ForegroundColor Cyan
    exit 0
}

Write-Step "Uploading to GitHub Release"

# Create release if it doesn't exist, or use existing
$existingRelease = gh release view "$Tag" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Creating new release $Tag..."
    gh release create "$Tag" --title "Starcade $Tag" --generate-notes --draft
    if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to create release"; exit 1 }
    Write-Ok "Release created (draft)"
}

# Upload each asset
foreach ($asset in $assets) {
    $assetName = Split-Path $asset -Leaf
    Write-Host "  ⬆  Uploading $assetName..."
    gh release upload "$Tag" "$asset" --clobber
    if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to upload $assetName"; exit 1 }
    Write-Ok "Uploaded $assetName"
}

# Mark as non-draft
Write-Host "  Publishing release..."
gh release edit "$Tag" --draft=false 2>$null
Write-Ok "Release published: $Tag"

Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ Done! Release: $Tag" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
