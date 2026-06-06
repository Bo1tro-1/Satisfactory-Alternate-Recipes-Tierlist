# PowerShell script to bundle HTML, CSS, JS and all images into a single self-contained HTML file
Add-Type -AssemblyName System.Web

$workspace = "c:\Beltran\Antigravity\Satis_Factory"
$indexHtmlPath = Join-Path $workspace "index.html"
$styleCssPath = Join-Path $workspace "style.css"
$appJsPath = Join-Path $workspace "app.js"
$recipesJsonPath = Join-Path $workspace "recipes.json"
$recipesDataJsPath = Join-Path $workspace "recipes-data.js"
$bundleOutputPath = Join-Path $workspace "Satisfactory_Alternate_Recipes_Tierlist.html"

Write-Host "Bundling modular source files into standalone offline HTML bundle..."

# Load HTML, CSS, JS
$html = Get-Content -Path $indexHtmlPath -Raw
$css = Get-Content -Path $styleCssPath -Raw
$jsApp = Get-Content -Path $appJsPath -Raw

# Load recipes data and convert images to Base64
$recipes = Get-Content -Path $recipesJsonPath -Raw | ConvertFrom-Json
$base64Cache = @{}

function Get-Base64DataUri {
    param([string]$relativePath)
    if ([string]::IsNullOrEmpty($relativePath)) {
        return ""
    }
    if ($base64Cache.ContainsKey($relativePath)) {
        return $base64Cache[$relativePath]
    }
    # Clean up relative path and make it absolute
    $cleanPath = $relativePath.Replace("/", "\").TrimStart("\")
    $fullPath = Join-Path $workspace $cleanPath
    if (Test-Path $fullPath) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $base64 = [System.Convert]::ToBase64String($bytes)
            $extension = [System.IO.Path]::GetExtension($fullPath).Replace(".", "").ToLower()
            if ($extension -eq "jpg") { $extension = "jpeg" }
            $mimeType = "image/" + $extension
            $dataUri = "data:" + $mimeType + ";base64," + $base64
            $base64Cache[$relativePath] = $dataUri
            return $dataUri
        } catch {
            Write-Host "Error encoding file ${fullPath}: ${_}" -ForegroundColor Red
        }
    } else {
        Write-Host "Warning: File not found: ${fullPath} (from relative path: ${relativePath})" -ForegroundColor Yellow
    }
    return $relativePath
}

# Convert all image paths in recipes list to Base64 data URIs
Write-Host "Encoding images to Base64..."
foreach ($recipe in $recipes) {
    if ($recipe.buildingImg) {
        $recipe.buildingImg = Get-Base64DataUri -relativePath $recipe.buildingImg
    }
    foreach ($ing in $recipe.ingredients) {
        if ($ing.img) {
            $ing.img = Get-Base64DataUri -relativePath $ing.img
        }
    }
    foreach ($prod in $recipe.products) {
        if ($prod.img) {
            $prod.img = Get-Base64DataUri -relativePath $prod.img
        }
    }
}

# Also update the modular recipes-data.js so it contains the correct properties
Write-Host "Updating modular recipes-data.js..."
$recipesJsonRaw = $recipes | ConvertTo-Json -Depth 5
"const RECIPES_DATA = $recipesJsonRaw;" | Out-File -FilePath $recipesDataJsPath -Encoding utf8

# Replace CSS link with styled content (regex handles any existing ?v= cache-busting param)
$styleTag = "<style>`n$css`n</style>"
$html = [regex]::Replace($html, '(?i)<link\s+rel="stylesheet"\s+href="style\.css(?:\?v=[^"]+)?"\s*>', $styleTag)

# Replace scripts
$dataTag = "<script>`nconst RECIPES_DATA = $recipesJsonRaw;`n</script>"
$html = [regex]::Replace($html, '(?i)<script\s+src="recipes-data\.js(?:\?v=[^"]+)?"\s*></script>', $dataTag)

$appTag = "<script>`n$jsApp`n</script>"
$html = [regex]::Replace($html, '(?i)<script\s+src="app\.js(?:\?v=[^"]+)?"\s*></script>', $appTag)

# Write bundle to file
$html | Out-File -FilePath $bundleOutputPath -Encoding utf8
Write-Host "Successfully compiled standalone bundle to: $bundleOutputPath"

# Auto-update index.html with a new timestamp version query parameter to prevent browser caching for modular files
Write-Host "Updating index.html with new cache-busting version query string..."
$cacheBuster = Get-Date -Format "yyyyMMddHHmmss"
$indexHtmlContent = Get-Content -Path $indexHtmlPath -Raw
$indexHtmlContent = [regex]::Replace($indexHtmlContent, '(?i)href="style\.css(?:\?v=[^"]+)?"', "href=`"style.css?v=$cacheBuster`"")
$indexHtmlContent = [regex]::Replace($indexHtmlContent, '(?i)src="recipes-data\.js(?:\?v=[^"]+)?"', "src=`"recipes-data.js?v=$cacheBuster`"")
$indexHtmlContent = [regex]::Replace($indexHtmlContent, '(?i)src="app\.js(?:\?v=[^"]+)?"', "src=`"app.js?v=$cacheBuster`"")
$indexHtmlContent | Out-File -FilePath $indexHtmlPath -Encoding utf8
Write-Host "Updated index.html references with version: $cacheBuster"

