#!/usr/bin/env python3
"""Ejecuta un archivo .sql en Athena y guarda la evidencia de cada ejecucion.

Solo usa la libreria estandar de Python y la AWS CLI v2 ya configurada.

Por cada sentencia del archivo (separadas por ';'):
  1. La lanza con `aws athena start-query-execution` en el workgroup y la base
     de datos que aparecen en evidencias/outputs.json (outputs de Terraform).
  2. Espera a que termine y descarga el resultado con `get-query-results`.
  3. Escribe el CSV en la ruta indicada (encabezado + filas, sin comillas).
  4. Agrega una fila a evidencias/ejecuciones_athena.csv con
     etapa, archivo_sql, id_ejecucion, archivo_resultado.
  5. Si se indica --esperado, compara el CSV obtenido con la referencia.

Uso:
  python3 scripts/ejecutar_athena.py --etapa inicial \
      --sql consultas/intentos_por_fecha_estado.sql \
      --salida resultados/inicial/intentos_por_fecha_estado.csv \
      --esperado resultados_esperados/intentos_por_fecha_estado_inicial.csv
"""
import argparse
import csv
import json
import subprocess
import sys
import time
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
REGISTRO = RAIZ / "evidencias" / "ejecuciones_athena.csv"
OUTPUTS = RAIZ / "evidencias" / "outputs.json"
COLUMNAS_REGISTRO = ["etapa", "archivo_sql", "id_ejecucion", "archivo_resultado"]


def aws(*argumentos, region):
    """Ejecuta un comando de la AWS CLI y devuelve su salida JSON."""
    comando = ["aws", *argumentos, "--region", region, "--output", "json"]
    proceso = subprocess.run(comando, capture_output=True, text=True)
    if proceso.returncode != 0:
        sys.exit(f"Error en {' '.join(comando[:3])}:\n{proceso.stderr}")
    return json.loads(proceso.stdout) if proceso.stdout.strip() else {}


def leer_outputs():
    if not OUTPUTS.exists():
        sys.exit("No existe evidencias/outputs.json. Ejecute antes: "
                 "terraform -chdir=infraestructura output -json > evidencias/outputs.json")
    datos = json.loads(OUTPUTS.read_text(encoding="utf-8"))
    return {clave: valor["value"] for clave, valor in datos.items()}


def sentencias(ruta_sql):
    """Quita las lineas de comentario y separa el archivo por ';'."""
    lineas = [l for l in ruta_sql.read_text(encoding="utf-8").splitlines()
              if not l.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lineas).split(";") if s.strip()]


def ejecutar(sql, salidas_cfg):
    respuesta = aws("athena", "start-query-execution",
                    "--query-string", sql,
                    "--work-group", salidas_cfg["workgroup"],
                    "--query-execution-context", f"Database={salidas_cfg['base_datos']}",
                    region=salidas_cfg["region"])
    id_ejecucion = respuesta["QueryExecutionId"]
    print(f"  id_ejecucion: {id_ejecucion}", flush=True)

    while True:
        estado = aws("athena", "get-query-execution", "--query-execution-id", id_ejecucion,
                     region=salidas_cfg["region"])["QueryExecution"]["Status"]
        if estado["State"] in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(1)
    if estado["State"] != "SUCCEEDED":
        sys.exit(f"La consulta {id_ejecucion} termino en {estado['State']}: "
                 f"{estado.get('StateChangeReason', '')}")

    filas, token = [], None
    while True:
        extra = ["--next-token", token] if token else []
        pagina = aws("athena", "get-query-results", "--query-execution-id", id_ejecucion,
                     *extra, region=salidas_cfg["region"])
        for fila in pagina["ResultSet"]["Rows"]:
            filas.append([celda.get("VarCharValue", "") for celda in fila["Data"]])
        token = pagina.get("NextToken")
        if not token:
            break
    return id_ejecucion, filas


def relativa(ruta):
    return Path(ruta).resolve().relative_to(RAIZ).as_posix()


def registrar(etapa, archivo_sql, id_ejecucion, archivo_resultado):
    nuevo = not REGISTRO.exists()
    REGISTRO.parent.mkdir(parents=True, exist_ok=True)
    with REGISTRO.open("a", newline="", encoding="utf-8") as archivo:
        escritor = csv.writer(archivo, lineterminator="\n")
        if nuevo:
            escritor.writerow(COLUMNAS_REGISTRO)
        escritor.writerow([etapa, archivo_sql, id_ejecucion, archivo_resultado])


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--etapa", required=True, choices=["inicial", "final"])
    parser.add_argument("--sql", required=True, help="Archivo .sql relativo a la raiz")
    parser.add_argument("--salida", required=True, action="append",
                        help="CSV de resultado; repetir una vez por sentencia del archivo")
    parser.add_argument("--esperado", action="append", default=[],
                        help="CSV de referencia para comparar (opcional, en el mismo orden)")
    args = parser.parse_args()

    ruta_sql = (RAIZ / args.sql).resolve()
    consultas = sentencias(ruta_sql)
    if len(consultas) != len(args.salida):
        sys.exit(f"{args.sql} tiene {len(consultas)} sentencias y se indicaron "
                 f"{len(args.salida)} --salida.")

    cfg = leer_outputs()
    print(f"Workgroup={cfg['workgroup']}  Base de datos={cfg['base_datos']}  Region={cfg['region']}")

    hubo_diferencias = False
    for indice, (sql, salida) in enumerate(zip(consultas, args.salida)):
        print(f"[{args.etapa}] {args.sql} -> {salida}")
        id_ejecucion, filas = ejecutar(sql, cfg)

        ruta_salida = (RAIZ / salida).resolve()
        ruta_salida.parent.mkdir(parents=True, exist_ok=True)
        with ruta_salida.open("w", newline="", encoding="utf-8") as archivo:
            csv.writer(archivo, lineterminator="\n").writerows(filas)
        print(f"  {len(filas) - 1} filas de datos guardadas")

        registrar(args.etapa, relativa(ruta_sql), id_ejecucion, relativa(ruta_salida))

        if indice < len(args.esperado):
            esperado = (RAIZ / args.esperado[indice]).read_text(encoding="utf-8")
            obtenido = ruta_salida.read_text(encoding="utf-8")
            if esperado.strip() == obtenido.strip():
                print(f"  OK: coincide con {args.esperado[indice]}")
            else:
                hubo_diferencias = True
                print(f"  DIFERENTE de {args.esperado[indice]}:\n--- esperado\n{esperado}"
                      f"--- obtenido\n{obtenido}")

    sys.exit(1 if hubo_diferencias else 0)


if __name__ == "__main__":
    main()
