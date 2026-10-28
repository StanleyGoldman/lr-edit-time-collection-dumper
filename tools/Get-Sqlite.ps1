# Downloads the official SQLite command-line tools and puts sqlite3.exe into the
# plugin's bin folder, which Lightroom needs to read Develop history
# (docs/adr/0001-develop-history-from-catalog-db.md). The binary is gitignored.
#
# Run from the repo root:  pwsh tools/Get-Sqlite.ps1

$ErrorActionPreference = 'Stop'

# To upgrade: take the version and zip name from https://sqlite.org/download.html,
# then record the SHA-256 of the zip (sqlite.org publishes SHA3-256 only; check
# that first, then compute SHA-256 with Get-FileHash).
$zipName = 'sqlite-tools-win-x64-3540100.zip'
$url = "https://sqlite.org/2026/$zipName"
$sha256 = 'FB20997ADE5583A5FBF1E36DB7BC3C82C9416B3F314F16961E1572AA4E49487D'

$binDir = Join-Path $PSScriptRoot '..\EditWindowJobs.lrdevplugin\bin'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sqlite-" + [guid]::NewGuid())
New-Item -ItemType Directory -Force $workDir, $binDir | Out-Null
try {
	$zipPath = Join-Path $workDir $zipName
	Invoke-WebRequest -Uri $url -OutFile $zipPath
	$actual = (Get-FileHash -Algorithm SHA256 $zipPath).Hash
	if ($actual -ne $sha256) {
		throw "SHA-256 mismatch for $zipName`: expected $sha256, got $actual"
	}
	Expand-Archive -Path $zipPath -DestinationPath (Join-Path $workDir 'tools')
	Copy-Item (Join-Path $workDir 'tools\sqlite3.exe') $binDir -Force
	Write-Host "sqlite3.exe installed in $((Resolve-Path $binDir).Path)"
}
finally {
	Remove-Item -Recurse -Force $workDir
}
