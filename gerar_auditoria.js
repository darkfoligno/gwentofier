const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Credenciais injetadas diretamente
const supabaseUrl = 'https://vshrwpnrckkgvesuqoyk.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZzaHJ3cG5yY2trZ3Zlc3Vxb3lrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4NDEyODE0MSwiZXhwIjoyMDk5NzA0MTQxfQ.YEn5VNuK-KhiYUQYzNh3Cso90i3aKo9SDSrhBqTEfyU';

const supabase = createClient(supabaseUrl, supabaseKey);

async function auditarProjetoCompleto() {
  console.log("🔍 1. Conectando ao Supabase para buscar o cadastro oficial das cartas...");
  const { data: cards, error: cardsError } = await supabase.from('cards').select('*');
  
  if (cardsError) {
    console.error("❌ Erro ao buscar cartas no banco:", cardsError);
    return;
  }

  console.log(`✅ ${cards.length} cartas encontradas no banco!`);
  console.log("🔍 2. Lendo os arquivos locais de migração SQL em 'supabase/migrations'...");

  // Varre a pasta local do projeto para encontrar como cada feitiço foi codificado no banco
  const migrationsDir = path.join(__dirname, 'supabase', 'migrations');
  let todoCodigoSql = "";

  if (fs.existsSync(migrationsDir)) {
    const arquivos = fs.readdirSync(migrationsDir);
    arquivos.forEach(arq => {
      if (arq.endsWith('.sql')) {
        const conteudo = fs.readFileSync(path.join(migrationsDir, arq), 'utf8');
        todoCodigoSql += `\n/* === ARQUIVO DE MIGRAÇÃO: ${arq} === */\n` + conteudo;
      }
    });
    console.log(`✅ Lidos ${arquivos.length} arquivos de migração SQL com sucesso!`);
  } else {
    console.log("⚠️ Pasta supabase/migrations não encontrada. Verifique se está rodando na raiz do projeto.");
  }

  console.log("📝 3. Processando e cruzando a mecânica para gerar os relatórios Markdown...");

  let mdComunsRaras = `# 🛑 AUDITORIA DE ENGENHARIA E FLUXO MECÂNICO: COMUNS E RARAS\n\n`;
  let mdEpicasLendarias = `# 🛑 AUDITORIA DE ENGENHARIA E FLUXO MECÂNICO: ÉPICAS E LENDÁRIAS\n\n`;

  cards.forEach(card => {
    const isComumOuRara = (card.rarity === 'common' || card.rarity === 'rare');
    
    let bloco = `## 🃏 ${card.name} | ID: \`${card.id}\` | Raridade: \`${card.rarity}\` | Elemento: \`${card.element || 'N/A'}\`\n`;
    bloco += `* **🔮 Código do Efeito (\`effect_code\`):** \`${card.effect_code || 'NENHUM'}\`\n`;
    bloco += `* **⚔️ Atributos:** 💎 Mana: ${card.cost} | ATK: ${card.base_power} | HP: ${card.base_life}\n`;
    bloco += `* **📖 Descrição no Jogo:** "${card.description}"\n`;

    // Busca no código SQL das migrações como o efeito foi programado
    if (card.effect_code && todoCodigoSql.includes(card.effect_code)) {
      bloco += `* **🟢 Status da Mecânica no SQL:** \`PROGRAMADA EM MIGRAÇÃO LOCAL\`\n\n`;
      bloco += `### 🔬 Código PL/pgSQL de Execução Encontrado:\n`;
      bloco += `\`\`\`sql\n`;
      
      // Extrai o bloco de código exato onde o feitiço foi programado nas migrações
      const linhas = todoCodigoSql.split('\n');
      let capturando = false;
      let contador = 0;

      for (let i = 0; i < linhas.length; i++) {
        if (linhas[i].includes(card.effect_code)) {
          capturando = true;
        }
        if (capturando && contador < 22) {
          bloco += linhas[i] + "\n";
          contador++;
        } else if (contador >= 22) {
          bloco += `  -- [Trecho contínuo no banco de dados...]\n`;
          break;
        }
      }
      bloco += `\`\`\`\n\n`;
    } else if (card.effect_code) {
      bloco += `* **🔴 Status da Mecânica no SQL:** \`ALERTA: EFEITO NÃO ENCONTRADO NAS MIGRAÇÕES LOCAIS\` (Pode não estar implementado nas funções do banco!)\n\n`;
    } else {
      bloco += `* **⚪ Status:** \`CARTA SEM EFEITO ATIVO CODIFICADO\`\n\n`;
    }

    bloco += `---\n\n`;

    if (isComumOuRara) {
      mdComunsRaras += bloco;
    } else {
      mdEpicasLendarias += bloco;
    }
  });

  fs.writeFileSync('AUDITORIA_MECANICA_COMUNS_RARAS.md', mdComunsRaras);
  fs.writeFileSync('AUDITORIA_MECANICA_EPICAS_LENDARIAS.md', mdEpicasLendarias);

  console.log("\n🏆 AUDITORIA MECÂNICA CONCLUÍDA COM SUCESSO!");
  console.log("📁 Arquivo gerado: AUDITORIA_MECANICA_COMUNS_RARAS.md");
  console.log("📁 Arquivo gerado: AUDITORIA_MECANICA_EPICAS_LENDARIAS.md");
}

auditarProjetoCompleto();