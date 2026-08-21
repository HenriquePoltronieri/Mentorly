# Roteiro do Vídeo (5 minutos)

## Antes de gravar

- [ ] MySQL rodando
- [ ] Backend no ar com `python app.py` (é esse comando que instala as procedures)
- [ ] `baseUrl` ajustada para onde o app vai rodar (web = `localhost`, emulador = `10.0.2.2`)
- [ ] Duas turmas já cadastradas, para a listagem não abrir vazia
- [ ] Conferir que Buscar Atividades e Relatório estão respondendo (dependem das procedures)
- [ ] Áudio testado e notificações desligadas
- [ ] Fonte do editor aumentada, para o trecho de código ficar legível

Deixe as exclusões para o final da demonstração, senão os dados somem e atrapalham o
resto do vídeo.

---

## 0:00 – 0:30 · Introdução

Diga o que é o projeto em uma frase: um sistema para a coordenação organizar turmas e
atividades escolares, feito em Flutter e Flask.

Mostre o diagrama de camadas do README e diga a frase principal:
*"as telas nunca chamam a API direto, sempre passam por um Service."*

## 0:30 – 1:45 · CRUD de Turmas

1. Tela inicial → "Entrar no painel da coordenação" → **Gerenciar Turmas**.
   A lista já vem do banco. → **funcionalidade 2 (Listar)**
2. Botão "Adicionar turma". Preencha nome `3 ano A` e descrição
   `Matemática - manhã`. Clique em Adicionar e mostre a turma aparecendo na lista
   sozinha. → **funcionalidade 1 (Cadastrar)**
3. Clique no ícone de lápis da turma. Mude o nome para `3 ano A - Tarde` e salve.
   Mostre a lista atualizada. → **funcionalidade 3 (Atualizar)**

Não exclua ainda.

## 1:45 – 3:15 · CRUD de Atividades

1. Toque na turma. Abre a tela de atividades daquela turma.
   → **funcionalidade 6 (Listar por turma)**
2. Botão "Adicionar atividade". Preencha nome `Prova 1 - Frações`, descrição e data
   `2026-09-15`. A turma já vem selecionada no campo. Adicione.
   → **funcionalidade 5 (Cadastrar)**
3. Clique no lápis da atividade, mude o nome para `Prova 1 - Frações (revisada)` e salve.
   Aparece a confirmação de sucesso. → **funcionalidade 7 (Atualizar)**

Não exclua ainda.

## 3:15 – 4:15 · Busca e Relatório

1. Volte ao painel → **Buscar Atividades**. Digite `Frações`, mude a ordenação para
   Título e clique em Buscar. Mostre o resultado com o nome da turma.
   → **funcionalidade 9**
   Diga: *"esses dados vêm da procedure `sp_buscar_atividades`, o filtro e a ordenação
   acontecem no banco."*
2. Volte ao painel → **Relatório de Turmas**. Mostre a turma com a contagem de
   atividades. → **funcionalidade 10**
   Diga: *"aqui é a procedure `sp_relatorio_turmas_atividades`, que usa LEFT JOIN e
   GROUP BY."*

## 4:15 – 4:45 · Arquitetura no código

Abra rápido, nesta ordem, e diga uma frase sobre cada um:

1. `gerenciarTurmasScreen.dart` — a tela chama o `TurmasService`, não tem `http` aqui.
2. `turmasService.dart` — monta a chamada `POST /classes` usando o `ApiService`.
3. `class_controller.py` — o Controller só lê os dados e chama o `CreateClassService`.
4. `create_class.py` — o Service valida o nome e chama a Model.
5. `class_model.py` — a Model é quem salva, no `Class.create`.

Depois abra `turma_repository.py` e diga: *"o Repository tem só duas consultas especiais,
nada de CRUD — o CRUD está na Model, como o professor pediu."*

## 4:45 – 5:00 · Encerramento

Volte ao aplicativo e **agora exclua**: primeiro a atividade (confirmação → some da
lista) → **funcionalidade 8**, depois a turma → **funcionalidade 4**.

Termine mostrando o README, na tabela com as 10 funcionalidades.
