#!/usr/bin/env bash
# sweep_map.sh — memoria y costo por paquete vs capacidad del mapa de flujos.
#
# Para cada capacidad, edita max_entries en el fuente, recompila/recarga, y mide
# memoria del mapa + costo por paquete. Ejecutar en el gateway con el agente activo.
#
# Uso:  sudo bash sweep_map.sh
set -euo pipefail

OUT="data/map_sweep.txt"
SRC="bpf/example_sem.bpf.c"
GAP=25
cp "$SRC" "$SRC.orig"
sysctl -w kernel.bpf_stats_enabled=1 >/dev/null
echo "barrido de tamaño de mapa" | tee "$OUT"

for cap in 1024 8192 65536; do
  echo "=== max_entries $cap ===" | tee -a "$OUT"
  sed -i "s/__uint(max_entries, [0-9]*)/__uint(max_entries, $cap)/" "$SRC"
  # limpiar y recargar
  tc qdisc del dev usb0 clsact 2>/dev/null || true
  rm -rf /sys/fs/bpf/sem
  bash bpf/run.sh load usb0 >/dev/null
  sleep 3
  PROGID="$(bpftool prog show | awk '/sem_prog/ {gsub(":","",$1); print $1; exit}')"
  # memoria del mapa
  bpftool map show | grep -A2 flow_feat | grep -oE 'max_entries [0-9]+  memlock [0-9]+' | tee -a "$OUT"
  # costo
  a="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
  sleep "$GAP"
  b="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
  echo "costo lectura1: $a" | tee -a "$OUT"
  echo "costo lectura2: $b" | tee -a "$OUT"
done

# restaurar
cp "$SRC.orig" "$SRC"
echo "restaurado max_entries original; guardado en $OUT"
