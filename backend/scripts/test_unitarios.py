"""Suíte sem banco: migrações e regressões integradas rodam separadamente."""
from pathlib import Path
import sys
import unittest

PASTA = Path(__file__).resolve().parent
sys.path.insert(0, str(PASTA.parent))
sys.path.insert(0, str(PASTA))

if __name__ == "__main__":
    suite = unittest.TestSuite()
    for arquivo in sorted(PASTA.glob("test_*.py")):
        if arquivo.name.startswith("test_migracao") or arquivo.name in ("test_unitarios.py", "test_correcoes_mentorly.py"):
            continue
        suite.addTests(unittest.defaultTestLoader.loadTestsFromName(arquivo.stem))
    resultado = unittest.TextTestRunner(verbosity=1).run(suite)
    raise SystemExit(0 if resultado.wasSuccessful() else 1)
