"""Testes unitários dos anexos privados de atividades (sem banco real)."""

import io
import os
import sys
import unittest
import zipfile
from unittest.mock import patch

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from erros import RecursoNaoEncontrado
from services.activity.anexos import AnexosAtividadeService, MAXIMO_BYTES, validar_arquivo


def documento_office(pasta):
    memoria = io.BytesIO()
    with zipfile.ZipFile(memoria, "w") as pacote:
        pacote.writestr("[Content_Types].xml", "<Types />")
        pacote.writestr(f"{pasta}/document.xml", "<document />")
    return memoria.getvalue()


class ValidacaoAnexoTest(unittest.TestCase):
    def test_aceita_formatos_validos_e_normaliza_nome(self):
        casos = [
            ("pasta/material.pdf", b"%PDF-1.7\nconteudo", "application/pdf"),
            ("foto.PNG", b"\x89PNG\r\n\x1a\nconteudo", "image/png"),
            ("leia.txt", "Acentuação".encode(), "text/plain; charset=utf-8"),
            ("roteiro.docx", documento_office("word"),
             "application/vnd.openxmlformats-officedocument.wordprocessingml.document"),
        ]
        for nome, conteudo, mime in casos:
            with self.subTest(nome=nome):
                seguro, detectado = validar_arquivo(nome, conteudo)
                self.assertEqual(seguro, nome.replace("pasta/", ""))
                self.assertEqual(detectado, mime)

    def test_recusa_extensao_assinatura_tamanho_e_texto_invalidos(self):
        invalidos = [
            ("programa.exe", b"MZ"),
            ("falso.pdf", b"nao e pdf"),
            ("vazio.txt", b""),
            ("binario.txt", b"\xff\xfe"),
            ("grande.csv", b"a" * (MAXIMO_BYTES + 1)),
        ]
        for nome, conteudo in invalidos:
            with self.subTest(nome=nome), self.assertRaises(ValueError):
                validar_arquivo(nome, conteudo)


class AnexosAtividadeServiceTest(unittest.TestCase):
    def setUp(self):
        self.service = AnexosAtividadeService()
        self.atividade = {
            "id": 7,
            "coordenacao_id": 3,
            "turma_id": 9,
            "etapa_id": 5,
        }

    @patch("services.activity.anexos.ProfessorTurma.professor_leciona_na_turma",
           return_value=False)
    @patch("services.activity.anexos.Atividade.find_by_id")
    def test_nao_vaza_atividade_de_professor_sem_vinculo(self, buscar, _vinculo):
        buscar.return_value = self.atividade
        with self.assertRaises(RecursoNaoEncontrado):
            self.service.listar(7, 11, 3)

    @patch("services.activity.anexos.AtividadeAnexo.buscar")
    @patch("services.activity.anexos.AtividadeAnexo.criar", return_value=21)
    @patch("services.activity.anexos.AtividadeAnexo.listar", return_value=[])
    @patch("services.activity.anexos.Etapa.esta_fechada", return_value=False)
    @patch("services.activity.anexos.ProfessorTurma.professor_leciona_na_turma",
           return_value=True)
    @patch("services.activity.anexos.Atividade.find_by_id")
    def test_envia_com_professor_e_escola_do_token(
            self, buscar_atividade, _vinculo, _fechada, _listar, criar,
            buscar_anexo):
        buscar_atividade.return_value = self.atividade
        buscar_anexo.return_value = {
            "id": 21,
            "atividade_id": 7,
            "nome_original": "guia.pdf",
            "tipo_mime": "application/pdf",
            "tamanho_bytes": 15,
            "created_at": None,
        }
        resultado = self.service.enviar(
            7, 11, 3, "guia.pdf", b"%PDF-1.7\nteste")
        self.assertEqual(resultado["id"], 21)
        criar.assert_called_once_with(
            3, 7, 11, "guia.pdf", "application/pdf", b"%PDF-1.7\nteste")

    @patch("services.activity.anexos.AtividadeAnexo.listar",
           return_value=[{"id": i} for i in range(10)])
    @patch("services.activity.anexos.Etapa.esta_fechada", return_value=False)
    @patch("services.activity.anexos.ProfessorTurma.professor_leciona_na_turma",
           return_value=True)
    @patch("services.activity.anexos.Atividade.find_by_id")
    def test_limita_quantidade_por_atividade(
            self, buscar_atividade, _vinculo, _fechada, _listar):
        buscar_atividade.return_value = self.atividade
        with self.assertRaisesRegex(ValueError, "limite de 10"):
            self.service.enviar(7, 11, 3, "guia.pdf", b"%PDF-1.7\nteste")

    @patch("services.activity.anexos.Etapa.esta_fechada", return_value=True)
    @patch("services.activity.anexos.ProfessorTurma.professor_leciona_na_turma",
           return_value=True)
    @patch("services.activity.anexos.Atividade.find_by_id")
    def test_etapa_fechada_impede_alterar_anexos(
            self, buscar_atividade, _vinculo, _fechada):
        buscar_atividade.return_value = self.atividade
        with self.assertRaisesRegex(ValueError, "etapa fechada"):
            self.service.enviar(7, 11, 3, "guia.pdf", b"%PDF-1.7\nteste")


if __name__ == "__main__":
    unittest.main(verbosity=2)
