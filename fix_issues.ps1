# PowerShell script to fix Flutter analyze issues
$libPath = "C:\Users\csp\Documents\plink-live\lib"

Get-ChildItem -Path $libPath -Recurse -Filter "*.dart" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding utf8
    $newContent = $content -replace '\.withOpacity\(', '.withValues(alpha: '
    if ($content -ne $newContent) {
        Set-Content $_.FullName -Value $newContent -Encoding utf8 -NoNewline
        Write-Host "Fixed: $($_.Name)"
    }
}
