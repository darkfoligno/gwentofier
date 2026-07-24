const fs = require('fs');
const path = require('path');

const migrationsDir = path.join(__dirname, '../supabase/migrations');
const finalSql = path.join(__dirname, '../gwent_ofieri_supabase_final.sql');

function extractCardsFromFile(filePath) {
    if (!fs.existsSync(filePath)) return [];
    
    const content = fs.readFileSync(filePath, 'utf-8');
    const cards = [];
    
    // Rares, Epics, Legendaries
    // (v_set_id, 'CODE', 'Name', 'Image', 'Element', 'rarity', 'type', boolean, boolean, power, life, mana, tier, 'Effect Text'
    const valuesRegex1 = /\([^,]+,\s*'[^']*',\s*'((?:[^']|'')*)',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*'[^']*',\s*(?:true|false),\s*(?:true|false),\s*\d+,\s*\d+,\s*\d+,\s*\d+,\s*'((?:[^']|'')*)'/gi;
    let match;
    while ((match = valuesRegex1.exec(content)) !== null) {
        let name = match[1].replace(/''/g, "'");
        let effect = match[2].replace(/''/g, "'").replace(/\n/g, ' ').trim();
        cards.push(`Name: ${name} - /Efect_text: ${effect}`);
    }

    // Commons (from WITH source AS VALUES)
    // (1,'Name',power,life,mana,'Effect Text')
    const valuesRegex2 = /\(\d+,\s*'((?:[^']|'')*)',\s*\d+,\s*\d+,\s*\d+,\s*'((?:[^']|'')*)'\)/gi;
    while ((match = valuesRegex2.exec(content)) !== null) {
        let name = match[1].replace(/''/g, "'");
        let effect = match[2].replace(/''/g, "'").replace(/\n/g, ' ').trim();
        cards.push(`Name: ${name} - /Efect_text: ${effect}`);
    }
    
    return cards;
}

let allCards = [];

if (fs.existsSync(migrationsDir)) {
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql'));
    for (const file of files) {
        allCards.push(...extractCardsFromFile(path.join(migrationsDir, file)));
    }
}
allCards.push(...extractCardsFromFile(finalSql));

// Deduplicate by name
const uniqueCards = [];
const seen = new Set();
for (const card of allCards) {
    const nameMatch = card.match(/^Name: (.*?) - \/Efect_text:/);
    if (nameMatch) {
        const name = nameMatch[1];
        if (!seen.has(name)) {
            seen.add(name);
            uniqueCards.push(card);
        }
    }
}

const output = `# AUDITORIA DO CATÁLOGO GERAL DE CARTAS - GWENTOFIER\n\n${uniqueCards.join('\n')}\n`;
fs.writeFileSync(path.join(__dirname, '../CATALOGO_CARTAS.md'), output, 'utf-8');
console.log(`Extracted ${uniqueCards.length} cards.`);
