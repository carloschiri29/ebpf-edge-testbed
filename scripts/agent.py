#!/usr/bin/env python3
"""agent.py — generador de carga de telemetría para el dispositivo de campo.

Emite paquetes UDP pequeños hacia la compuerta a una tasa configurable, de modo
que el tráfico atraviese la pila de red y dispare el programa eBPF en el gateway.
Genérico: no contiene nada del sistema de observabilidad; solo produce un flujo
de telemetría representativo (carga + temperatura del SoC, si está disponible).

Uso:  python3 agent.py --interval 0.03 --gateway 10.55.0.1 --port 1883

identificadores en inglés, comentarios en español.
"""
import argparse
import socket
import struct
import time


def read_soc_temp():
    """Lee la temperatura del SoC (Raspberry Pi). Devuelve grados C o None."""
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as fh:
            return int(fh.read().strip()) / 1000.0
    except OSError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--interval", type=float, default=0.03,
                    help="segundos entre envíos (0.03 ~= 33 Hz -> flujo continuo)")
    ap.add_argument("--gateway", default="10.55.0.1", help="IP del gateway")
    ap.add_argument("--port", type=int, default=1883, help="puerto destino")
    ap.add_argument("--dport", type=int, default=50000, help="puerto observado por el pipeline")
    args = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    print(f"[agent] intervalo {args.interval}s ({1/args.interval:.0f} Hz) -> "
          f"{args.gateway}:{args.port}")

    seq = 0
    t_report = time.time()
    sent = 0
    try:
        while True:
            temp = read_soc_temp()
            temp_val = temp if temp is not None else 0.0
            # payload representativo: seq + timestamp + temperatura (telemetría)
            payload = struct.pack("!Idf", seq & 0xFFFFFFFF, time.time(), temp_val)
            sock.sendto(payload, (args.gateway, args.port))
            seq += 1
            sent += 1

            now = time.time()
            if now - t_report >= 5.0:
                rate = sent / (now - t_report)
                temp_str = f"{temp:.2f}" if temp is not None else "n/a"
                print(f"[agent] seq={seq}  temp={temp_str} C  ~{rate:.0f} pkt/s")
                t_report = now
                sent = 0

            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\n[agent] detenido")


if __name__ == "__main__":
    main()
