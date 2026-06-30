#!/usr/bin/env bash
# run.sh — compila y carga/atacha el programa eBPF de ejemplo a una interfaz.
# Uso:  sudo ./run.sh load <iface>     (p.ej. sudo ./run.sh load usb0)
#       sudo ./run.sh unload <iface>
#
# Requisitos: clang, bpftool, tc (iproute2). identificadores en inglés.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/example_sem.bpf.c"
OBJ="$HERE/example_sem.bpf.o"
PIN="/sys/fs/bpf/sem"

cmd="${1:-}"
iface="${2:-usb0}"

case "$cmd" in
  load)
    echo "[build] $SRC -> $OBJ"
    clang -O2 -g -target bpf -c "$SRC" -o "$OBJ"
    echo "[build] ok"
    # qdisc clsact + filtro tc en ingress
    tc qdisc add dev "$iface" clsact 2>/dev/null || true
    tc filter add dev "$iface" ingress bpf da obj "$OBJ" sec tc
    # pin del mapa para inspección
    mkdir -p "$PIN"
    echo "[load] programa atado a $iface (tc ingress, sched_cls)"
    echo "[load] ver costo:  sudo bpftool prog show | grep sem_prog"
    ;;
  unload)
    tc qdisc del dev "$iface" clsact 2>/dev/null || true
    rm -rf "$PIN"
    echo "[unload] filtros tc removidos de $iface"
    ;;
  *)
    echo "uso: sudo $0 {load|unload} <iface>"
    exit 1
    ;;
esac
