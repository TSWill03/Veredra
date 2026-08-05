# Integracao com AgentSkills

## Fonte canonica

As skills deste projeto sao selecionadas e versionadas em `TSWill03/AgentsSkills`. O mapeamento oficial do projeto e `veredra` no arquivo `registry/skills.json`.

Skills atualmente mapeadas: skill-feedback, veredra-research-ingestion, tdd, handoff, to-prd, to-issues, domain-modeling, codebase-design, improve-codebase-architecture, supabase-postgres-best-practices, prototype, web-design-guidelines e frontend-design.

## Sincronizacao

- Execute `python scripts/sync-agent-skills.py --agent codex` quando `.agents/skills/skill-feedback/SKILL.md` nao existir ou antes de atualizar o catalogo.
- A sincronizacao usa copia local e nunca deve instalar skills globalmente.
- O repositorio `AgentsSkills` e privado; a maquina precisa estar autenticada no GitHub CLI (`gh auth status`) ou no Git.

## Feedback obrigatorio por uso

Sempre que qualquer skill for usada, o agente deve registrar exatamente um evento de feedback ao concluir o fluxo. Leia e siga `skill-feedback/SKILL.md`, informando skill, versao, projeto, agente, resultado esperado, resultado obtido, status, erros sanitizados e sugestao de melhoria.

O registrador tenta criar uma issue `[skill-feedback]` em `TSWill03/AgentsSkills`. Sem rede ou autenticacao, deve preservar o JSONL em `.agent-feedback/pending/`. Nunca registrar tokens, senhas, cookies, arquivos `.env`, chaves privadas ou dados pessoais desnecessarios.

Uma tarefa que utilizou skill nao esta completamente encerrada enquanto o feedback nao tiver sido enviado ou persistido no fallback local.
