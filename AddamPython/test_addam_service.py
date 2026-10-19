import unittest

from addam_service import responder


class AddamResponderTests(unittest.TestCase):
    def test_apresenta_o_addam_e_sugestoes_ao_cumprimentar(self):
        resultado = responder("Olá, Addam")
        self.assertEqual(resultado["assistant"], "Addam")
        self.assertIn("assistente de teste", resultado["reply"])
        self.assertGreater(len(resultado["suggestions"]), 0)

    def test_explica_limites_desta_versao(self):
        resultado = responder("O que você consegue fazer?")
        self.assertIn("não leio o banco", resultado["reply"])
        self.assertIn("não gero PDFs", resultado["reply"])

    def test_orienta_consulta_de_estoque_sem_fingir_acesso_ao_banco(self):
        resultado = responder("Como vejo o estoque?")
        self.assertIn("abra Estoque", resultado["reply"])
        self.assertIn("não consulto o banco", resultado["reply"])

    def test_informa_que_pdf_ainda_nao_existe(self):
        resultado = responder("Gere um PDF")
        self.assertIn("ainda não está disponível", resultado["reply"])

    def test_diferencia_consultar_vendas_de_criar_uma_venda(self):
        consulta = responder("Onde vejo as vendas?")
        criacao = responder("Como faço uma venda?")
        self.assertIn("Abra Relatórios", consulta["reply"])
        self.assertIn("abra PDV", criacao["reply"])

    def test_pergunta_desconhecida_recebe_fallback(self):
        resultado = responder("xyzzy pergunta que não conheço")
        self.assertIn("Ainda não entendi", resultado["reply"])


if __name__ == "__main__":
    unittest.main()
