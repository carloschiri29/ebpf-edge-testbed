#!/usr/bin/env bash
# sweep_cpu.sh — costo por paquete del eBPF bajo contención de CPU del host.
#
# Mide el costo por paquete con 0, 1, 2 y 4 núcleos saturados con stress-ng.
# Requiere: stress-ng, bpftool. Ejecutar en el gateway con el agente emitiendo.
#
# Uso:  sudo bash sweep_cpu.sh
set -euo pipefail

OUT="data/cpu_sweep.txt"
GAP=25
sysctl -w kernel.bpf_stats_enabled=1 >/dev/null
PROGID="$(bpftool prog show | awk '/sem_prog/ {gsub(":","",$1); print $1; exit}')"
echo "barrido de CPU, sem_prog id=$PROGID" | tee "$OUT"

read_inc() {
  # imprime ns/paquete incremental sobre GAP segundos
  local a b ns1 c1 ns2 c2
  a="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
  ns1="$(echo "$a" | awk '{print $2}')"; c1="$(echo "$a" | awk '{print $4}')"
  sleep "$GAP"
  b="$(bpftool prog show id "$PROGID" | grep -oE 'run_time_ns [0-9]+ run_cnt [0-9]+')"
  ns2="$(echo "$b" | awk '{print $2}')"; c2="$(echo "$b" | awk '{print $4}')"
  awk -v n1="$ns1" -v c1="$c1" -v n2="$ns2" -v c2="$c2" \
      'BEGIN{ if (c2>c1) printf "%.0f ns/pkt (dcnt=%d)\n",(n2-n1)/(c2-c1),(c2-c1); else print "sin avance" }'
}

for cores in 0 1 2 4; do
  echo "=== $cores nucleos estresados ===" | tee -a "$OUT"
  if [ "$cores" -gt 0 ]; then
    stress-ng --cpu "$cores" --timeout $((GAP+10))s >/dev/null 2>&1 &
    STRESS_PID=$!
    sleep 3
  fi
  read_inc | tee -a "$OUT"
  if [ "$cores" -gt 0 ]; then wait "$STRESS_PID" 2>/dev/null || true; fi
done
echo "guardado en $OUT"
