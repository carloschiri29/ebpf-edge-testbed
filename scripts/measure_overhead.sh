#!/usr/bin/env bash
# measure_overhead.sh — costo por paquete del programa eBPF, con repeticiones.
#
# Toma N lecturas de (run_time_ns, run_cnt) del programa, separadas por un
# intervalo fijo. El costo incremental entre lecturas da muestras independientes
# (no el cociente acumulado). Filtra por el ID del programa para evitar residuales.
#
# Uso:  sudo bash measure_overhead.sh [N] [intervalo_s]
set -euo pipefail

N="${1:-10}"
GAP="${2:-20}"
OUT="data/overhead_repeats.txt"

sysctl -w kernel.bpf_stats_enabled=1 >/dev/null

# ID del programa activo (el que corresponde a sem_prog)
PROGID="$(bpftool prog show | awk '/sem_prog/ {gsub(":","",$1); print $1; exit}')"
if [ -z "${PROGID:-}" ]; then
  echo "ERROR: no se encontró sem_prog cargado. Carga el programa primero." >&2
  exit 1
fi
echo "programa sem_prog id=$PROGID, $N lecturas cada ${GAP}s" | tee "$OUT"

for i in $(seq 1 "$N"); do
  sleep "$GAP"
  line="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
  echo "muestra $i: $line" | tee -a "$OUT"
done
echo "guardado en $OUT"
