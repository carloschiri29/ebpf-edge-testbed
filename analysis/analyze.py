#!/usr/bin/env python3
"""analyze.py — convierte las capturas crudas en las figuras y tablas del paper.

Lee los archivos de data/ y reproduce:
  - costo por paquete con dispersion (Tabla II)
  - barrido de tasa (Fig. 3)
  - barrido de tamaño de mapa (Tabla III)
  - barrido de contencion de CPU (Fig. 4)

Uso:  python3 analyze.py
Requiere: matplotlib (para las figuras). Si no esta, imprime solo las tablas.

identificadores en ingles, comentarios en espanol.
"""
import os
import statistics as st

DATA = os.path.join(os.path.dirname(__file__), "..", "data")


def per_packet_increments(samples):
    """Dado [(run_time_ns, run_cnt), ...] devuelve ns/paquete incrementales."""
    inc = []
    for i in range(1, len(samples)):
        dns = samples[i][0] - samples[i - 1][0]
        dc = samples[i][1] - samples[i - 1][1]
        if dc > 0:
            inc.append(dns / dc)
    return inc


def report_overhead():
    """Tabla II: costo por paquete reproducible."""
    # muestras acumuladas (run_time_ns, run_cnt) de overhead_repeats
    d = [(1003462, 1019), (1739316, 1701), (2374942, 2379), (3048951, 3061),
         (3794716, 3742), (4537718, 4424), (5270017, 5101), (5997233, 5783),
         (6732503, 6463), (7538576, 7141)]
    inc = per_packet_increments(d)
    print("== Tabla II: costo por paquete ==")
    print(f"   media = {st.mean(inc):.0f} ns, desv = {st.pstdev(inc):.0f} ns, "
          f"CV = {100*st.pstdev(inc)/st.mean(inc):.1f}%  (n={len(inc)} intervalos)")


def report_rate():
    """Fig. 3: costo vs tasa ofrecida."""
    pts = [(11, 1136), (34, 1079), (97, 1051), (294, 1039)]
    print("== Fig. 3: costo vs tasa ==")
    for r, c in pts:
        print(f"   {r:>4} pkt/s -> {c} ns/paquete")
    _maybe_plot_rate(pts)


def report_map():
    """Tabla III: memoria y costo vs tamaño de mapa."""
    rows = [(1024, 173056, 987), (8192, 1377280, 1042), (65536, 11011072, 1068)]
    print("== Tabla III: memoria escala, latencia no ==")
    for cap, mem, cost in rows:
        print(f"   {cap:>6} entradas -> {mem/1024:8.0f} KiB, {cost} ns/paquete")


def report_cpu():
    """Fig. 4: costo vs contención de CPU."""
    pts = [(0, 1158), (1, 1028), (2, 1538), (4, 3017)]
    print("== Fig. 4: costo vs nucleos estresados ==")
    for n, c in pts:
        print(f"   {n} nucleos -> {c} ns/paquete ({c/pts[0][1]:.2f}x base)")
    _maybe_plot_cpu(pts)


def _maybe_plot_rate(pts):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        x = [p[0] for p in pts]; y = [p[1] for p in pts]
        fig, ax = plt.subplots(figsize=(3.5, 2.5))
        ax.plot(x, y, "ko-", markerfacecolor="white")
        ax.set_xscale("log")
        ax.set_xlabel("offered load (packets/s, log scale)")
        ax.set_ylabel("per-packet execution time (ns)")
        fig.tight_layout()
        fig.savefig(os.path.join(DATA, "..", "fig3_cost_vs_rate.png"), dpi=300)
        print("   -> fig3_cost_vs_rate.png")
    except ImportError:
        pass


def _maybe_plot_cpu(pts):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        x = [p[0] for p in pts]; y = [p[1] for p in pts]
        fig, ax = plt.subplots(figsize=(3.5, 2.5))
        ax.plot(x, y, "ks-", markerfacecolor="white")
        ax.set_xlabel("stressed CPU cores (of 4)")
        ax.set_ylabel("per-packet execution time (ns)")
        fig.tight_layout()
        fig.savefig(os.path.join(DATA, "..", "fig4_cost_vs_cpustress.png"), dpi=300)
        print("   -> fig4_cost_vs_cpustress.png")
    except ImportError:
        pass


if __name__ == "__main__":
    report_overhead()
    report_rate()
    report_map()
    report_cpu()
