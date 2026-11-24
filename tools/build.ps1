<#
.SYNOPSIS
    Build the KernelSU module zip from a Xiaomi Market APK.

.DESCRIPTION
    The APK is not redistributed with this repository; supply your own copy.
    The script extracts the native libraries, assembles the module tree and
    produces a flashable zip.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\build.ps1 -Apk C:\apk\miuistore.apk -Out .\miui_market_cn.zip
#>

param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Out = "miui_market_cn.zip"
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Apk)) { throw "APK not found: $Apk" }

$root = Split-Path $PSScriptRoot -Parent
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("miuimarket_" + [guid]::NewGuid().ToString("N"))
$appDir = Join-Path $work "module\system\app\com.xiaomi.market"

New-Item -ItemType Directory -Force -Path (Join-Path $appDir "lib\arm64"), (Join-Path $appDir "lib\arm") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $work "module") | Out-Null

Copy-Item (Join-Path $root "module\module.prop")       (Join-Path $work "module")
Copy-Item (Join-Path $root "module\post-fs-data.sh")   (Join-Path $work "module")
Copy-Item (Join-Path $root "module\customize.sh")      (Join-Path $work "module")
Copy-Item $Apk (Join-Path $appDir "com.xiaomi.market.apk")

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $Apk))
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch '^lib/(arm64-v8a|armeabi-v7a)/') { continue }
        $abi = if ($entry.FullName.StartsWith('lib/arm64-v8a/')) { 'arm64' } else { 'arm' }
        $name = [System.IO.Path]::GetFileName($entry.FullName)
        $dst = Join-Path $appDir "lib\$abi\$name"
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $dst, $true)
    }
} finally { $zip.Dispose() }

$outFull = if ([System.IO.Path]::IsPathRooted($Out)) { $Out } else { Join-Path (Get-Location).Path $Out }
if (Test-Path $outFull) { Remove-Item $outFull -Force }
New-Item -ItemType Directory -Force -Path (Split-Path $outFull -Parent) | Out-Null
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    (Join-Path $work "module"), $outFull,
    [System.IO.Compression.CompressionLevel]::Optimal, $false)
$Out = $outFull

Remove-Item $work -Recurse -Force

$size = [math]::Round((Get-Item $Out).Length / 1MB, 1)
Write-Host "built: $Out ($size MB)"
