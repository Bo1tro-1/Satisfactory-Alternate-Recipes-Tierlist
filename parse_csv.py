import csv

csv_path = r"c:\Beltran\Antigravity\Satis_Factory\Satisfactory Recipes - Time_Effort (1.0) UPDATED - Ranking.csv"

with open(csv_path, mode='r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header1 = next(reader)
    header2 = next(reader)
    
    recipes = []
    for row in reader:
        if not row or len(row) < 25:
            continue
        score = row[0]
        item = row[1]
        recipe_name = row[2]
        is_alternate = row[24] # Column 'Alternate'
        
        if is_alternate.strip().upper() == "TRUE":
            recipes.append((score, item, recipe_name))

print(f"Total alternative recipes found in CSV: {len(recipes)}")
print("First 10 alternative recipes:")
for r in recipes[:10]:
    print(r)
