"""Validação explícita com MySQL e Groq reais; somente SELECT, nenhuma gravação.
Execute: python backend/scripts/validar_chat_real.py
Não imprime credenciais, não testa login nem envia e-mail.
"""
import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from app import create_app
from auth.jwt_utils import gerar_token
from database.connection import query_one
from services.professor.estatisticas_turma import EstatisticasTurmaService
from services.rate_limit import limiter


def main():
    assert query_one("SELECT 1 ok")["ok"] == 1
    r = query_one("SELECT pt.professor_id,pt.coordenacao_id,pt.turma_id FROM professor_turma pt JOIN professor p ON p.id=pt.professor_id WHERE p.habilitado=1 ORDER BY (SELECT COUNT(*) FROM atividade a WHERE a.turma_id=pt.turma_id) DESC,pt.turma_id LIMIT 1")
    if not r:
        raise RuntimeError("Nenhum professor habilitado com turma vinculada para o teste.")
    d = EstatisticasTurmaService().execute(r["professor_id"], r["coordenacao_id"], r["turma_id"])
    antes = query_one("SELECT (SELECT COUNT(*) FROM atividade) atividades,(SELECT COUNT(*) FROM nota) notas,(SELECT COUNT(*) FROM aluno) alunos")
    headers = {"Authorization": "Bearer " + gerar_token(r["professor_id"], "professor", r["coordenacao_id"])}
    client = create_app().test_client()
    limiter.reset()
    historico = []
    for pergunta in ["qual aluno está com mais risco?", "quais medidas aplicar?", "onde a turma tem mais dificuldade?"]:
        resposta = client.post("/api/professor/ia/chat", headers=headers, json={"mensagem": pergunta, "turma_id": r["turma_id"], "historico": historico[-10:]})
        assert resposta.status_code == 200, {"status": resposta.status_code, "error": resposta.json.get("error")}
        corpo = resposta.json
        for e in corpo["evidencias"]:
            assert e["turma_id"] == d["turma"]["id"]
            aluno = next((a for a in d["alunos"] if a["id"] == e.get("aluno_id")), None)
            assert e["media"] == (aluno["media"] if aluno else d["media"])
            assert e["risco"] == (aluno["risco"] if aluno else d["distribuicao_risco"])
        print(json.dumps({"pergunta": pergunta, "status": resposta.status_code, "resposta": corpo["resposta"], "evidencias_conferidas": len(corpo["evidencias"])}, ensure_ascii=True), flush=True)
        historico.extend([{"role": "user", "content": pergunta}, {"role": "assistant", "content": corpo["resposta"]}])
    depois = query_one("SELECT (SELECT COUNT(*) FROM atividade) atividades,(SELECT COUNT(*) FROM nota) notas,(SELECT COUNT(*) FROM aluno) alunos")
    assert antes == depois
    print(json.dumps({"mysql": "ok", "nenhum_registro_criado": antes == depois, "turma_atividades": len(d["atividades"]), "turma_alunos": len(d["alunos"]), "banco_notas": antes["notas"]}), flush=True)

if __name__ == "__main__": main()
