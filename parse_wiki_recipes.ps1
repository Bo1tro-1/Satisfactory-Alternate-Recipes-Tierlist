# PowerShell script to parse HTML and CSV to generate recipes.json
param(
    [switch]$SkipScrape
)

Add-Type -AssemblyName System.Web

$htmlPath = "C:\Users\bvill\.gemini\antigravity\brain\c1118662-9033-42c0-af0f-c67e6e896509\.system_generated\steps\56\content.md"
$csvPath = "c:\Beltran\Antigravity\Satis_Factory\Satisfactory Recipes - Time_Effort (1.0) UPDATED - Ranking.csv"
$outputPath = "c:\Beltran\Antigravity\Satis_Factory\recipes.json"


# Read HTML file content
$html = Get-Content -Path $htmlPath -Raw

# We want to extract the table containing recipes
# Let's locate the table. It has class "recipetable"
$tableStart = $html.IndexOf('<table class="wikitable sortable recipetable">')
if ($tableStart -lt 0) {
    Write-Error "Could not find recipe table in HTML."
    exit 1
}

$tableEnd = $html.IndexOf('</table>', $tableStart)
$tableHtml = $html.Substring($tableStart, $tableEnd - $tableStart + 8)

if ($SkipScrape -and (Test-Path "c:\Beltran\Antigravity\Satis_Factory\recipes.json")) {
    Write-Host "SkipScrape active: Loading existing recipes.json database..."
    $wikiRecipes = Get-Content -Path "c:\Beltran\Antigravity\Satis_Factory\recipes.json" -Raw | ConvertFrom-Json
} else {
    # Parse rows
    # A row starts with <tr> and ends with </tr>
    $rows = [regex]::Matches($tableHtml, '(?s)<tr>(.*?)</tr>')

    $wikiRecipes = @()

    foreach ($row in $rows) {
        $rowContent = $row.Groups[1].Value
        if ($rowContent -like "*<th>Recipe*") {
            continue # Skip header row
        }
        
        # Each row has 5 columns (<td>)
        $cols = [regex]::Matches($rowContent, '(?s)<td>(.*?)</td>')
        if ($cols.Count -lt 5) {
            continue
        }
        
        # 1. Recipe Name
        $recipeCol = $cols[0].Groups[1].Value
        # Extract name (everything before <br />)
        $recipeName = [regex]::Match($recipeCol, '^[^<]+').Value.Trim()
        
        # 2. Ingredients
        $ingredientsCol = $cols[1].Groups[1].Value
        # Extract item details: amount, image URL, item name, rate
        # E.g. <span class="item-amount" ...>3&#160;&#215; </span><a href="..." title="Iron Plate"><img alt="..." src="[IMG_URL]" ... /></a><span class="item-name">Iron Plate</span><span class="item-minute" ...>11.25 /&#160;min</span>
        $ingredientMatches = [regex]::Matches($ingredientsCol, '(?s)<div class="recipe-item">.*?src="([^"]+)".*?<span class="item-name">([^<]+)</span>.*?<span class="item-minute"[^>]*>([^<]+)</span>')
        $ingredients = @()
        foreach ($itemMatch in $ingredientMatches) {
            $img = "https://satisfactory.wiki.gg" + $itemMatch.Groups[1].Value
            # Decode HTML entities like &#160; and clean up the rate
            $name = [System.Web.HttpUtility]::HtmlDecode($itemMatch.Groups[2].Value).Trim()
            $rate = [System.Web.HttpUtility]::HtmlDecode($itemMatch.Groups[3].Value).Replace("`u{00A0}", " ").Replace("/ ", "/").Trim()
            $ingredients += @{
                name = $name
                img = $img
                rate = $rate
            }
        }
        
        # 3. Produced in (Building & Time)
        $buildingCol = $cols[2].Groups[1].Value
        $buildingName = [regex]::Match($buildingCol, '(?s)<a[^>]*>([^<]+)</a>').Groups[1].Value.Trim()
        $craftTime = [regex]::Match($buildingCol, '(?s)</a><br\s*/>([^<]+)').Groups[1].Value.Trim()
        # Decode building text
        $buildingName = [System.Web.HttpUtility]::HtmlDecode($buildingName)
        $craftTime = [System.Web.HttpUtility]::HtmlDecode($craftTime).Replace("`u{00A0}", " ").Trim()
        
        # 4. Products
        $productsCol = $cols[3].Groups[1].Value
        $productMatches = [regex]::Matches($productsCol, '(?s)<div class="recipe-item">.*?src="([^"]+)".*?<span class="item-name">([^<]+)</span>.*?<span class="item-minute"[^>]*>([^<]+)</span>')
        $products = @()
        foreach ($itemMatch in $productMatches) {
            $img = "https://satisfactory.wiki.gg" + $itemMatch.Groups[1].Value
            $name = [System.Web.HttpUtility]::HtmlDecode($itemMatch.Groups[2].Value).Trim()
            $rate = [System.Web.HttpUtility]::HtmlDecode($itemMatch.Groups[3].Value).Replace("`u{00A0}", " ").Replace("/ ", "/").Trim()
            $products += @{
                name = $name
                img = $img
                rate = $rate
            }
        }
        
        # 5. Unlocked by (Tier)
        $unlockedCol = $cols[4].Groups[1].Value
        # Clean up tags and extract text
        $unlockedText = [regex]::Replace($unlockedCol, '<[^>]+>', ' ').Trim()
        $unlockedText = [System.Web.HttpUtility]::HtmlDecode($unlockedText)
        # Simplify whitespace
        $unlockedText = [regex]::Replace($unlockedText, '\s+', ' ')
        # Extract tier or building
        # E.g. "Hard Drive scanning after unlocking: Tier 5 - Oil Processing" -> "Tier 5"
        $tier = "Hard Drive"
        if ($unlockedText -match "Tier (\d+)") {
            $tier = "Tier " + $Matches[1]
        } elseif ($unlockedText -match "MAM ([^A-Z]*[A-Z][a-zA-Z\s]+)") {
            $tier = "MAM: " + $Matches[1].Replace("Research", "").Trim()
        }
        
        $wikiRecipes += @{
            recipeName = $recipeName
            ingredients = $ingredients
            building = $buildingName
            buildingImg = "" # We will resolve building images later
            time = $craftTime
            products = $products
            tier = $tier
            unlockDetail = $unlockedText
        }
    }
    Write-Host "Parsed $($wikiRecipes.Count) recipes from Wiki HTML."
}

# Now parse CSV
# Since Row 1 is metadata, we skip it.
$csvContent = Get-Content -Path $csvPath
# Join and parse as CSV, or read lines manually to handle metadata row
$csvLines = $csvContent | ConvertFrom-Csv -Header "Score","Item","Recipe","Power","Items","Buildings","Resources","BuildingsScaled","ResourcesScaled","Empty1","Bauxite","NitrogenGas","SAM","Limestone","CrudeOil","CateriumOre","Coal","RawQuartz","Sulfur","Water","Uranium","CopperOre","IronOre","Empty2","Alternate","CostSum","CostScore","Scaled" | Select-Object -Skip 2

Write-Host "Parsed $($csvLines.Count) rows from CSV."

# Create a mapping of matched recipes
$finalRecipes = @()
$unmatchedCount = 0

foreach ($csvRow in $csvLines) {
    if ($csvRow.Alternate -ne "TRUE") {
        continue # Only keep alternate recipes as requested
    }
    
    $csvRecipeName = $csvRow.Recipe
    # Clean CSV name: remove "Alternate: " prefix
    $cleanCsvName = $csvRecipeName.Replace("Alternate: ", "").Trim()
    
    # Find matching recipe in wiki data
    # We do case-insensitive match
    $matched = $wikiRecipes | Where-Object { 
        $_.recipeName -eq $cleanCsvName -or 
        $_.recipeName -eq $cleanCsvName.Replace("Screws", "Screw").Replace("Ingots", "Ingot").Replace("Plates", "Plate") 
    } | Select-Object -First 1
    
    # Helper to clean and parse percentage values
    $parsePct = {
        param($val)
        if ($null -eq $val -or $val -eq "") { return 0.0 }
        # Remove % sign and clean whitespace
        $cleanVal = $val.Replace("%", "").Trim()
        if ([double]::TryParse($cleanVal, [ref]0.0)) {
            return [double]$cleanVal
        }
        return 0.0
    }

    if ($null -ne $matched) {
        $score = [double]$csvRow.Score
        if ($matched.psobject.Properties['score']) { $matched.score = $score } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "score" -Value $score }
        if ($matched.psobject.Properties['csvName']) { $matched.csvName = $csvRecipeName } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "csvName" -Value $csvRecipeName }
        
        # Parse comparison metrics including scaled ones
        $diffPowerVal = &$parsePct $csvRow.Power
        $diffItemsVal = &$parsePct $csvRow.Items
        $diffBuildingsVal = &$parsePct $csvRow.Buildings
        $diffResourcesVal = &$parsePct $csvRow.Resources
        $diffBuildingsScaledVal = &$parsePct $csvRow.BuildingsScaled
        $diffResourcesScaledVal = &$parsePct $csvRow.ResourcesScaled

        if ($matched.psobject.Properties['diffPower']) { $matched.diffPower = $diffPowerVal } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "diffPower" -Value $diffPowerVal }
        if ($matched.psobject.Properties['diffItems']) { $matched.diffItems = $diffItemsVal } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "diffItems" -Value $diffItemsVal }
        if ($matched.psobject.Properties['diffBuildings']) { $matched.diffBuildings = $diffBuildingsVal } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "diffBuildings" -Value $diffBuildingsVal }
        if ($matched.psobject.Properties['diffResources']) { $matched.diffResources = $diffResourcesVal } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "diffResources" -Value $diffResourcesVal }
        if ($matched.psobject.Properties['diffBuildingsScaled']) { $matched.diffBuildingsScaled = $diffBuildingsScaledVal } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "diffBuildingsScaled" -Value $diffBuildingsScaledVal }
        if ($matched.psobject.Properties['diffResourcesScaled']) { $matched.diffResourcesScaled = $diffResourcesScaledVal } else { Add-Member -InputObject $matched -MemberType NoteProperty -Name "diffResourcesScaled" -Value $diffResourcesScaledVal }

        $finalRecipes += $matched
    } else {
        # Try fuzzy match
        $matchedFuzzy = $wikiRecipes | Where-Object { 
            $_.recipeName -like "*$cleanCsvName*" -or 
            $cleanCsvName -like "*$($_.recipeName)*"
        } | Select-Object -First 1
        
        if ($null -ne $matchedFuzzy) {
            $score = [double]$csvRow.Score
            if ($matchedFuzzy.psobject.Properties['score']) { $matchedFuzzy.score = $score } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "score" -Value $score }
            if ($matchedFuzzy.psobject.Properties['csvName']) { $matchedFuzzy.csvName = $csvRecipeName } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "csvName" -Value $csvRecipeName }

            # Parse comparison metrics including scaled ones
            $diffPowerVal = &$parsePct $csvRow.Power
            $diffItemsVal = &$parsePct $csvRow.Items
            $diffBuildingsVal = &$parsePct $csvRow.Buildings
            $diffResourcesVal = &$parsePct $csvRow.Resources
            $diffBuildingsScaledVal = &$parsePct $csvRow.BuildingsScaled
            $diffResourcesScaledVal = &$parsePct $csvRow.ResourcesScaled

            if ($matchedFuzzy.psobject.Properties['diffPower']) { $matchedFuzzy.diffPower = $diffPowerVal } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "diffPower" -Value $diffPowerVal }
            if ($matchedFuzzy.psobject.Properties['diffItems']) { $matchedFuzzy.diffItems = $diffItemsVal } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "diffItems" -Value $diffItemsVal }
            if ($matchedFuzzy.psobject.Properties['diffBuildings']) { $matchedFuzzy.diffBuildings = $diffBuildingsVal } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "diffBuildings" -Value $diffBuildingsVal }
            if ($matchedFuzzy.psobject.Properties['diffResources']) { $matchedFuzzy.diffResources = $diffResourcesVal } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "diffResources" -Value $diffResourcesVal }
            if ($matchedFuzzy.psobject.Properties['diffBuildingsScaled']) { $matchedFuzzy.diffBuildingsScaled = $diffBuildingsScaledVal } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "diffBuildingsScaled" -Value $diffBuildingsScaledVal }
            if ($matchedFuzzy.psobject.Properties['diffResourcesScaled']) { $matchedFuzzy.diffResourcesScaled = $diffResourcesScaledVal } else { Add-Member -InputObject $matchedFuzzy -MemberType NoteProperty -Name "diffResourcesScaled" -Value $diffResourcesScaledVal }

            $finalRecipes += $matchedFuzzy
        } else {
            $unmatchedCount++
            Write-Host "Could not match CSV recipe: '$csvRecipeName' ($cleanCsvName)" -ForegroundColor Yellow
        }
    }
}

Write-Host "Successfully matched $($finalRecipes.Count) recipes."
Write-Host "Unmatched recipes: $unmatchedCount"

# Output as JSON
$finalRecipes | ConvertTo-Json -Depth 5 | Out-File -FilePath $outputPath -Encoding utf8
Write-Host "Recipes written to $outputPath"
