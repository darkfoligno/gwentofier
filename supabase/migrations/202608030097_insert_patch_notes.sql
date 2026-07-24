BEGIN;

INSERT INTO public.patch_notes (version, title, body, published_at, author_id)
VALUES (
    'V37.0',
    'VEREDITO DAS ATUALIZAÇÕES: SANEAMENTO GERAL E PVP ALFA',
    'Saudações aos guerreiros das Areias de Ofier! A auditoria do Lançamento Alfa V37.0 foi concluída com sucesso.

Aqui está o veredito oficial das nossas implementações e migrations recentes:

🔹 **O QUE ESTÁ 100% FUNCIONAL:**
- O fluxo de combate do Modo PVP Assíncrono via WebSocket está funcional e validado.
- Todas as mais de 241 cartas foram extraídas e integradas com sucesso.
- O Sistema de Resgate Diário foi corrigido para resetar à Meia-Noite (Calendário) e agora invoca o Gacha 3D automaticamente!
- O Modo Treino está perfeitamente isolado: nenhuma recompensa financeira ou estatística de rank será afetada indevidamente.
- O layout mobile foi otimizado, abandonando os cronômetros frustrantes e as quebras de tela.

🔹 **SITUAÇÃO DAS CARTAS E SEUS EFEITOS (O GRANDE EXPURGO):**
- **100% Funcionais**: Efeitos que manipulam dano bruto, reforço (boosts), bloqueio simples e draws puros. As modificações de vida/poder ocorrem precisamente via `match_runtime_effects` ou lógica nativa.
- **Incógnitas (Estimadas em ~50%)**: Algumas cartas de complexidade Lendária (roubo de cartas do cemitério do inimigo no turno dele, anulação de ações antes da janela de reação e contadores cumulativos dinâmicos). Nesses casos pontuais, implementamos o "Graceful Degradation" (se o efeito for muito anômalo, o servidor não travará; o efeito é parcialmente ignorado para manter a fluidez do combate).

Agradecemos o apoio contínuo. Nos vemos no Campo de Batalha!',
    now(),
    NULL
);

COMMIT;
