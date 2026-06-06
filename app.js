// Satisfactory Alternate Recipes Visualizer - JS

document.addEventListener('DOMContentLoaded', () => {
    // State variables
    let recipesData = [];
    let activeFilters = {
        search: '',
        tier: 'all',
        building: 'all',
        grade: 'all',
        sortBy: 'score' // 'score', 'name', 'tier'
    };

    // DOM Elements
    const recipesGrid = document.getElementById('recipes-grid');
    const loadingIndicator = document.getElementById('loading-indicator');
    const noResults = document.getElementById('no-results');
    const searchInput = document.getElementById('search-input');
    const totalRecipesCount = document.getElementById('total-recipes-count');
    const tierFiltersContainer = document.getElementById('tier-filters');
    const buildingFiltersContainer = document.getElementById('building-filters');
    const sortButtons = document.querySelectorAll('.sort-btn');

    // Load recipe data from global variable (bypasses browser CORS policy for local files)
    try {
        if (typeof RECIPES_DATA === 'undefined') {
            throw new Error('Recipes database is not loaded.');
        }
        
        // Sort originally by score descending
        recipesData = RECIPES_DATA.sort((a, b) => b.score - a.score);
        
        // Initialize filters & data display
        initDynamicFilters();
        updateStats(recipesData);
        renderRecipes();
        
        loadingIndicator.style.display = 'none';
        recipesGrid.style.display = 'grid';
    } catch (err) {
        console.error('Initialization error:', err);
        loadingIndicator.innerHTML = `<p style="color: #ff5252;">Error loading data: ${err.message}. Make sure recipes-data.js is in the same directory and referenced in index.html.</p>`;
    }

    // Initialize Tier and Building filters dynamically
    function initDynamicFilters() {
        const tiers = new Set();
        const buildings = new Set();

        // Attach click listener to existing static buttons (Todos / Todas / Grade)
        tierFiltersContainer.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', handleFilterClick);
        });
        buildingFiltersContainer.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', handleFilterClick);
        });
        document.getElementById('grade-filters').querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', handleFilterClick);
        });

        recipesData.forEach(recipe => {
            if (recipe.tier) tiers.add(recipe.tier);
            if (recipe.building) buildings.add(recipe.building);
        });

        // Populate Tiers (Sorted naturally)
        const sortedTiers = Array.from(tiers).sort((a, b) => {
            const getOrder = (t) => {
                if (t.startsWith('Tier')) {
                    return parseInt(t.replace('Tier', '').trim());
                }
                return 99; // MAM or other goes last
            };
            return getOrder(a) - getOrder(b);
        });

        sortedTiers.forEach(tier => {
            const btn = document.createElement('button');
            btn.className = 'filter-btn';
            btn.dataset.filterType = 'tier';
            btn.dataset.filterVal = tier;
            btn.textContent = tier;
            btn.addEventListener('click', handleFilterClick);
            tierFiltersContainer.appendChild(btn);
        });

        // Populate Buildings (Sorted alphabetically)
        const sortedBuildings = Array.from(buildings).sort();
        sortedBuildings.forEach(building => {
            const btn = document.createElement('button');
            btn.className = 'filter-btn';
            btn.dataset.filterType = 'building';
            btn.dataset.filterVal = building;
            btn.textContent = building;
            btn.addEventListener('click', handleFilterClick);
            buildingFiltersContainer.appendChild(btn);
        });
    }

    // Helper to determine tier grade from score
    function getScoreTierClass(score) {
        if (score >= 85) return 'tier-s';
        if (score >= 70) return 'tier-a';
        if (score >= 55) return 'tier-b';
        if (score >= 40) return 'tier-c';
        return 'tier-f';
    }

    function getScoreGrade(score) {
        if (score >= 85) return 'S';
        if (score >= 70) return 'A';
        if (score >= 55) return 'B';
        if (score >= 40) return 'C';
        return 'F';
    }

    // Filter Click Handlers
    function handleFilterClick(e) {
        const btn = e.target;
        const filterType = btn.dataset.filterType;
        const filterVal = btn.dataset.filterVal;

        // Toggle active class on siblings
        let container;
        if (filterType === 'tier') container = tierFiltersContainer;
        else if (filterType === 'building') container = buildingFiltersContainer;
        else if (filterType === 'grade') container = document.getElementById('grade-filters');
        
        container.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Update state
        activeFilters[filterType] = filterVal;
        renderRecipes();
    }

    // Search input handler
    searchInput.addEventListener('input', (e) => {
        activeFilters.search = e.target.value.toLowerCase().trim();
        renderRecipes();
    });

    // Sorting buttons handler
    sortButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            sortButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            activeFilters.sortBy = btn.dataset.sort;
            renderRecipes();
        });
    });

    // Update global Stats Overview
    function updateStats(filteredData) {
        totalRecipesCount.textContent = filteredData.length;
    }

    // Render cards to Grid
    function renderRecipes() {
        // Clear grid
        recipesGrid.innerHTML = '';

        // 1. Filter Data
        let filtered = recipesData.filter(recipe => {
            // Search match
            const matchesSearch = !activeFilters.search || 
                recipe.recipeName.toLowerCase().includes(activeFilters.search) ||
                recipe.building.toLowerCase().includes(activeFilters.search) ||
                recipe.ingredients.some(i => i.name.toLowerCase().includes(activeFilters.search)) ||
                recipe.products.some(p => p.name.toLowerCase().includes(activeFilters.search));

            // Tier match
            const matchesTier = activeFilters.tier === 'all' || recipe.tier === activeFilters.tier;

            // Building match
            const matchesBuilding = activeFilters.building === 'all' || recipe.building === activeFilters.building;

            // Grade match
            const matchesGrade = activeFilters.grade === 'all' || getScoreGrade(recipe.score) === activeFilters.grade;

            return matchesSearch && matchesTier && matchesBuilding && matchesGrade;
        });

        // 2. Sort Data
        if (activeFilters.sortBy === 'score') {
            filtered.sort((a, b) => b.score - a.score);
        } else if (activeFilters.sortBy === 'name') {
            filtered.sort((a, b) => a.recipeName.localeCompare(b.recipeName));
        } else if (activeFilters.sortBy === 'tier') {
            filtered.sort((a, b) => {
                const getOrder = (t) => {
                    if (t.startsWith('Tier')) {
                        return parseInt(t.replace('Tier', '').trim());
                    }
                    return 99;
                };
                return getOrder(a.tier) - getOrder(b.tier);
            });
        }

        // Update Stats
        updateStats(filtered);

        // 3. Render Cards
        if (filtered.length === 0) {
            recipesGrid.style.display = 'none';
            noResults.style.display = 'block';
            return;
        }

        noResults.style.display = 'none';
        recipesGrid.style.display = 'grid';

        filtered.forEach(recipe => {
            const card = document.createElement('div');
            card.className = 'recipe-card';

            const scoreTierClass = getScoreTierClass(recipe.score);
            const scoreGrade = getScoreGrade(recipe.score);

            // Generate ingredients HTML
            const ingredientsHTML = recipe.ingredients.map(ing => `
                <div class="item-row">
                    <div class="item-img-container">
                        <img src="${ing.img}" alt="${ing.name}" onerror="this.src='https://satisfactory.wiki.gg/images/Hard_Drive.png'">
                    </div>
                    <div class="item-text-info">
                        <span class="item-name-label">${ing.name}</span>
                        <span class="item-rate-label">${ing.rate}</span>
                    </div>
                </div>
            `).join('');

            // Generate products HTML
            const productsHTML = recipe.products.map(prod => `
                <div class="item-row">
                    <div class="item-img-container">
                        <img src="${prod.img}" alt="${prod.name}" onerror="this.src='https://satisfactory.wiki.gg/images/Hard_Drive.png'">
                    </div>
                    <div class="item-text-info">
                        <span class="item-name-label">${prod.name}</span>
                        <span class="item-rate-label">${prod.rate}</span>
                    </div>
                </div>
            `).join('');

            card.innerHTML = `
                <div class="card-header">
                    <div class="recipe-title-area">
                        <h2>${recipe.recipeName}</h2>
                        <div class="recipe-meta">
                            <span class="tier-badge">${recipe.tier || 'MAM'}</span>
                            <span class="building-name">${recipe.building}</span>
                        </div>
                    </div>
                    <div class="score-badge ${scoreTierClass}">
                        <span class="score-val">${recipe.score.toFixed(1)}</span>
                        <span class="score-lbl">TIER ${scoreGrade}</span>
                    </div>
                </div>
                
                <div class="recipe-flow">
                    <!-- Ingredients -->
                    <div class="flow-column ingredients-col">
                        ${ingredientsHTML}
                    </div>
                    
                    <!-- Middle (Building and Time) -->
                    <div class="flow-middle">
                        <div class="building-display">
                            <img src="${recipe.buildingImg || 'https://satisfactory.wiki.gg/images/Hard_Drive.png'}" alt="${recipe.building}" onerror="this.src='https://satisfactory.wiki.gg/images/Hard_Drive.png'">
                        </div>
                        <div class="building-info">
                            <span class="crafting-time">${recipe.time}</span>
                        </div>
                    </div>
                    
                    <!-- Products -->
                    <div class="flow-column products-col">
                        ${productsHTML}
                    </div>
                </div>
                
                <div class="card-footer">
                    <span class="unlock-path">${recipe.unlockDetail}</span>
                </div>
            `;

            recipesGrid.appendChild(card);
        });
    }

    // Back to Top button logic
    const backToTopBtn = document.getElementById('back-to-top');
    if (backToTopBtn) {
        window.addEventListener('scroll', () => {
            if (window.scrollY > 300) {
                backToTopBtn.classList.add('show');
            } else {
                backToTopBtn.classList.remove('show');
            }
        });

        backToTopBtn.addEventListener('click', () => {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        });
    }
});
