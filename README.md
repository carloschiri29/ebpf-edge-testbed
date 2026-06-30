# ebpf-edge-testbed

A low-cost, reproducible testbed and measurement methodology for **eBPF datapath overhead at the IoT edge**.

This repository accompanies the paper *"A Reproducible Testbed and Measurement Methodology for eBPF Datapath Overhead at the IoT Edge"* (INTERCON 2026). It contains everything needed to rebuild the testbed and reproduce the overhead measurements: the bring-up procedure, the measurement scripts, the analysis tools, the raw captures, and a **representative example eBPF program**.

> **Note on the subject program.** The measurements in the paper use an in-band eBPF program that is *representative* of datapath observability workloads. The program shipped here (`bpf/example_sem.bpf.c`) is a minimal, generic stand-in that counts packets and tracks per-flow inter-arrival time in an LRU hash map — enough to reproduce the overhead methodology. It is **not** a specific observability system; that is the subject of separate, ongoing work.

## Hardware

| Role | Device |
|---|---|
| Gateway (device under test) | Raspberry Pi 4 Model B (4 cores, 8 GB) |
| Field device | Raspberry Pi Zero 2 W (512 MB) |
| Interconnect | USB-gadget Ethernet, point-to-point (10.55.0.0/24) |

## Software

- OS: Raspbian/Debian 12 (bookworm), kernel 6.12.93, aarch64
- Toolchain: clang 14.0.6, bpftool 7.5.0
- Field-device agent: Python 3.11

## Layout

```
bpf/        example_sem.bpf.c   representative eBPF program (generic)
            run.sh              build + load/attach helper
scripts/    agent.py            telemetry workload generator (field device)
            measure_overhead.sh per-packet cost (repeatable, ID-filtered)
            sweep_rate.sh       cost vs offered load
            sweep_map.sh        memory + cost vs flow-map size
            sweep_cpu.sh        cost vs host CPU contention
analysis/   analyze.py          turns raw captures into figures/tables
data/       *.jsonl, *.txt      raw captures from the paper
docs/       BRINGUP.md          bring-up and verification procedure
```

## Quick start

1. Bring up the link and load the program — see [docs/BRINGUP.md](docs/BRINGUP.md).
2. On the field device: `python3 scripts/agent.py --interval 0.03 --gateway 10.55.0.1`
3. On the gateway: `sudo ./bpf/run.sh load usb0`
4. Run a measurement, e.g. `sudo bash scripts/measure_overhead.sh`
5. Regenerate figures/tables: `python3 analysis/analyze.py`

## Reproducing the paper's results

The `data/` directory holds the raw captures used in the paper. Running `analysis/analyze.py` over them regenerates the per-packet cost, the load sweep (Fig. 3), the map-size sweep (Table III), and the CPU-contention sweep (Fig. 4).

## License

MIT — see [LICENSE](LICENSE).

## Citation


