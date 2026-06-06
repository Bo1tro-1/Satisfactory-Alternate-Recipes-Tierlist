$uri = "https://satisfactory.wiki.gg/api.php?action=cargoquery&tables=recipes&fields=recipe,ingredients,products,building,tier&limit=10&format=json"
try {
    $res = Invoke-RestMethod -Uri $uri -Method Get
    Write-Host "Success!"
    $res | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Error: $_"
}
