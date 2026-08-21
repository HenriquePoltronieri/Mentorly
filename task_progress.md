# Task Progress

## PART A — Backend
- [ ] A1: Rename `ClassRepository` → `TurmaRepository`
  - [ ] Rename file `class_repository.py` → `turma_repository.py`
  - [ ] Rename class `ClassRepository` → `TurmaRepository`
  - [ ] Update imports in `create_class.py`, `get_class_report.py`, `update_class.py`
  - [ ] Search remaining references to `ClassRepository`
- [ ] A2: Update outdated docs
  - [ ] Update `backend/att.md`
  - [ ] Update `README.md` (Repositories section)
- [ ] A3: Verify layered architecture
  - [ ] Verify Controllers/Services/Repositories/Models
  - [ ] `python -m py_compile` on all .py files
  - [ ] App runs (`python app.py`)

## PART B — FLUTTER ↔ FLASK INTEGRATION
- [ ] B1: Fix the 4 screens that call http directly
  - [ ] `loginScreen.dart` → use AuthService
  - [ ] `listaProfessoresScreen.dart` → create ProfessoresService
  - [ ] `cadastroProfessorScreen.dart` → use ProfessoresService
  - [ ] `buscarAtividadesScreen.dart` → create AtividadesService
  - [ ] Use centralized `ApiService.baseUrl`
- [ ] B2: Resolve `planilhaService.dart` empty (comment)
- [ ] B3: Align JSON contract (PENDING — depends on group decision)

## FINAL
- [ ] Verify backend compilation
- [ ] Verify Flutter compilation (flutter analyze)
- [ ] List changed files