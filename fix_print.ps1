# PowerShell script to replace print with debugPrint
$libPath = "C:\Users\csp\Documents\plink-live\lib"

Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding utf8
    # Replace print( with debugPrint( but not debugPrint(
    $newContent = $content -replace '(?<!debug)print\(', 'debugPrint('
    if ($content -ne $newContent) {
        Set-Content $_.FullName -Value $newContent -Encoding utf8 -NoNewline
        Write-Host "Fixed: $($_.Name)"
    }
}
