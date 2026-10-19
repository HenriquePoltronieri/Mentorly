# Roteiro de demonstração (até 5 minutos)

O vídeo é obrigatório na entrega da atividade. Prepare uma escola fictícia com ano letivo atual, etapa, critério, uma turma, um aluno e um professor convidado e vinculado à turma. Inicie MySQL e use `iniciar.ps1` ou `Iniciar Mentorly.cmd` para abrir API e Flutter. Verifique login antes de começar a gravação.

| Tempo | Demonstração | Fluxo que aparece |
|---|---|---|
| 0:00–0:30 | Mostre o README em **Funcionalidades Implementadas** e o [diagrama de classes](diagrama-classes.md). | Estrutura e requisitos da entrega. |
| 0:30–1:45 | Entre como Coordenação; crie um ano letivo, configure etapa e critério, cadastre uma turma e um aluno. Abra as respectivas listas para mostrar os registros persistidos. | Interface → API → Controller → Service → Model → MySQL. |
| 1:45–2:30 | Cadastre ou mostre um professor, vincule-o à turma e abra a lista de turmas vinculadas. | Vínculo e isolamento por escola. |
| 2:30–3:45 | Entre como Professor; crie uma atividade, abra a listagem, lance uma nota e mostre o boletim ou desempenho do aluno. | CRUD pedagógico completo e cálculo acadêmico. |
| 3:45–4:20 | Use **Buscar Atividades** ou **Relatório de Turmas**. | `BuscarAtividadesService` → procedure de busca; `RelatorioTurmasAtividadesService` → consulta agregada no Repository. |
| 4:20–4:50 | Mostre os arquivos reais `backend/controllers/class_controller.py`, `backend/services/turmas.py`, `backend/models/turma_model.py` e `backend/repositories/consultas.py`. | Responsabilidades das camadas e Model `db.Model`. |
| 4:50–5:00 | Volte à interface e mostre o resultado atualizado. | Confirmação do fluxo de ponta a ponta. |

Fale apenas dos fluxos que aparecerem funcionando na gravação. A IA depende de `AI_API_KEY` válida e pode ficar fora do vídeo. Use dados fictícios para evitar expor e-mails reais ou chaves. O envio do vídeo é feito separadamente pelo grupo.
