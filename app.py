"""Atalho para iniciar a API a partir da raiz do projeto."""

import runpy
import sys
from pathlib import Path


if __name__ == "__main__":
    root = Path(__file__).resolve().parent
    local_mysql = root / ".local_mysql.py"
    if local_mysql.exists():
        runpy.run_path(str(local_mysql))["ensure_running"]()
    backend = root / "backend"
    sys.path.insert(0, str(backend))
    runpy.run_path(str(backend / "app.py"), run_name="__main__")
