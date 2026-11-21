$ErrorActionPreference = 'Stop'

$mobileRoot = Split-Path -Parent $PSScriptRoot
$generatedRoot = Join-Path $mobileRoot 'build\generated_launcher_assets'

Push-Location $mobileRoot
try {
    & 'C:\flutter\bin\flutter.bat' test 'tool\brand_assets_test.dart'
    if ($LASTEXITCODE -ne 0) {
        throw "Brand asset generation failed with exit code $LASTEXITCODE."
    }

    Get-ChildItem -Path $generatedRoot -File -Recurse | ForEach-Object {
        $relativePath = $_.FullName.Substring($generatedRoot.Length).TrimStart('\')
        $targetPath = Join-Path $mobileRoot $relativePath
        $targetDirectory = Split-Path -Parent $targetPath
        [System.IO.Directory]::CreateDirectory($targetDirectory) | Out-Null

        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if ([System.IO.File]::Exists($targetPath)) {
            $stream = [System.IO.File]::Open(
                $targetPath,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::Read
            )
            try {
                $stream.SetLength(0)
                $stream.Write($bytes, 0, $bytes.Length)
            }
            finally {
                $stream.Dispose()
            }
        }
        else {
            [System.IO.File]::WriteAllBytes($targetPath, $bytes)
        }
    }
}
finally {
    Pop-Location
}
