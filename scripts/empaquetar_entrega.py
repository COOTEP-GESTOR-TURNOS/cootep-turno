"""Arma el ZIP de código para Moodle a partir de una etiqueta del repositorio paraguas.

Incluye el contenido de los submódulos (la descarga ZIP de GitHub no los incluye)
y quita las carpetas .git. Así el ZIP y el repositorio corresponden a la misma versión.

Uso:
    python scripts/empaquetar_entrega.py https://github.com/ORG/cootep-turno.git v1.0.0
"""

import os
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


def _quitar_solo_lectura(funcion, ruta, _error):
    # En Windows, los objetos de Git son de solo lectura y rmtree falla sin esto.
    os.chmod(ruta, stat.S_IWRITE)
    funcion(ruta)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    url, etiqueta = sys.argv[1], sys.argv[2]
    salida = Path.cwd() / f"cootep-turno-{etiqueta}"

    with tempfile.TemporaryDirectory() as tmp:
        destino = Path(tmp) / "cootep-turno"
        subprocess.run(
            ["git", "clone", "--recurse-submodules", "--depth", "1", "--shallow-submodules",
             "--branch", etiqueta, url, str(destino)],
            check=True,
        )
        for ruta in sorted(destino.rglob(".git"), key=lambda p: len(p.parts)):
            if not ruta.exists():
                continue
            if ruta.is_dir():
                shutil.rmtree(ruta, onexc=_quitar_solo_lectura)
            else:
                ruta.unlink()
        archivo = shutil.make_archive(str(salida), "zip", root_dir=tmp, base_dir="cootep-turno")

    print(f"Listo: {archivo}")


if __name__ == "__main__":
    main()
