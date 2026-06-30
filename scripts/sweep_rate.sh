#!/usr/bin/env bash
# sweep_rate.sh — costo por paquete vs tasa de tráfico ofrecida.
#
# Para cada tasa, reinicia el agente en el dispositivo de campo con ese intervalo,
# espera estabilización y mide el costo incremental. Este script se ejecuta en el
# GATEWAY; lanzar el agente con la tasa correspondiente en el dispositivo de campo.
#
# Tasas sugeridas (intervalo s -> pkt/s aprox): 0.1->10, 0.03->33, 0.01->100, 0.003->333
#
# Uso:  sudo bash sweep_rate.sh     (cambiar la tasa del agente manualmente entre pasos)
set -euo pipefail

OUT="data/rate_sweep.txt"
GAP=25
sysctl -w kernel.bpf_stats_enabled=1 >/dev/null
PROGID="$(bpftool prog show | awk '/sem_prog/ {gsub(":","",$1); print $1; exit}')"
echo "leyendo costo de sem_prog id=$PROGID (etiquetar manualmente la tasa actual)" | tee -a "$OUT"

a="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
echo "lectura 1: $a" | tee -a "$OUT"
sleep "$GAP"
b="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
echo "lectura 2: $b" | tee -a "$OUT"
echo "(repetir para cada tasa del agente)" | tee -a "$OUT"
