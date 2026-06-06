# PowerShell script to download all images locally and update recipes.json
Add-Type -AssemblyName System.Web

$jsonPath = "c:\Beltran\Antigravity\Satis_Factory\recipes.json"
$imgItemsDir = "c:\Beltran\Antigravity\Satis_Factory\images\items"
$imgBuildingsDir = "c:\Beltran\Antigravity\Satis_Factory\images\buildings"

# Create directories if they don't exist
New-Item -ItemType Directory -Force -Path $imgItemsDir | Out-Null
New-Item -ItemType Directory -Force -Path $imgBuildingsDir | Out-Null

# Load recipes
$recipes = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json

# We will keep a map of URL -> Local Path to avoid downloading duplicates
$downloadMap = @{}

# Function to download image
function Download-Image {
    param(
        [string]$url,
        [string]$destPath
    )
    if (Test-Path $destPath) {
        return $true
    }
    
    try {
        Write-Host "Downloading: ${url} -> ${destPath}"
        Invoke-WebRequest -Uri $url -OutFile $destPath -TimeoutSec 10
        Start-Sleep -Milliseconds 100
        return $true
    } catch {
        Write-Host "Failed to download ${url}: ${_}" -ForegroundColor Red
        return $false
    }
}

# Function to get building image URL from Wiki API
function Get-BuildingImageUrl {
    param(
        [string]$buildingName
    )
    $fileName = "File:" + $buildingName + ".png"
    # Replace spaces with %20
    $encoded = [System.Web.HttpUtility]::UrlEncode($fileName)
    $uri = "https://satisfactory.wiki.gg/api.php?action=query&titles=$encoded&prop=imageinfo&iiprop=url&format=json"
    
    try {
        $res = Invoke-RestMethod -Uri $uri -Method Get
        $pages = $res.query.pages
        foreach ($key in $pages.psobject.properties.Name) {
            $page = $pages.$key
            if ($null -ne $page.imageinfo) {
                return $page.imageinfo[0].url
            }
        }
    } catch {
        Write-Host "Error getting image URL for ${buildingName}: ${_}" -ForegroundColor Red
    }
    return $null
}

# First collect all building images
$buildings = @{}
foreach ($recipe in $recipes) {
    if (-not $buildings.ContainsKey($recipe.building)) {
        $buildings[$recipe.building] = $true
    }
}

Write-Host "Fetching images for $($buildings.Count) unique buildings..."
foreach ($b in $buildings.Keys) {
    # Clean name for filename
    $cleanName = $b.Replace(" ", "_")
    $localPath = "images/buildings/$cleanName.png"
    $fullLocalPath = Join-Path $imgBuildingsDir "$cleanName.png"
    
    $url = Get-BuildingImageUrl -buildingName $b
    if ($null -ne $url) {
        if (Download-Image -url $url -destPath $fullLocalPath) {
            # Update all recipes with this building image
            foreach ($recipe in $recipes) {
                if ($recipe.building -eq $b) {
                    $recipe.buildingImg = $localPath
                }
            }
        }
    }
}

# Now download item images
Write-Host "Fetching images for ingredients and products..."
foreach ($recipe in $recipes) {
    # Ingredients
    foreach ($ing in $recipe.ingredients) {
        $url = $ing.img
        # Remove query parameters from image URL (e.g. ?3faddb)
        $cleanUrl = $url.Split("?")[0]
        # Get filename
        $fileName = [System.IO.Path]::GetFileName($cleanUrl)
        $localPath = "images/items/$fileName"
        $fullLocalPath = Join-Path $imgItemsDir $fileName
        
        if (Download-Image -url $url -destPath $fullLocalPath) {
            $ing.img = $localPath
        }
    }
    
    # Products
    foreach ($prod in $recipe.products) {
        $url = $prod.img
        $cleanUrl = $url.Split("?")[0]
        $fileName = [System.IO.Path]::GetFileName($cleanUrl)
        $localPath = "images/items/$fileName"
        $fullLocalPath = Join-Path $imgItemsDir $fileName
        
        if (Download-Image -url $url -destPath $fullLocalPath) {
            $prod.img = $localPath
        }
    }
}

# Save updated JSON
$recipes | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding utf8
Write-Host "Completed asset download and recipes.json update!"
