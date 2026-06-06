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

# Replace CSS link with styled content
$styleTag = "<style>`n$css`n</style>"
$html = $html.Replace('<link rel="stylesheet" href="style.css">', $styleTag)

# Replace scripts
$dataTag = "<script>`nconst RECIPES_DATA = $recipesJsonRaw;`n</script>"
$html = $html.Replace('<script src="recipes-data.js"></script>', $dataTag)

$appTag = "<script>`n$jsApp`n</script>"
$html = $html.Replace('<script src="app.js"></script>', $appTag)

# Write to file
$html | Out-File -FilePath $bundleOutputPath -Encoding utf8
Write-Host "Successfully compiled standalone bundle to: $bundleOutputPath"
