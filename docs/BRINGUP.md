# Bring-up and verification

Cold-start procedure for the testbed. Run the gates in order; each must pass before the next.

## Topology

```
Field device (Pi Zero 2 W)            Gateway / DUT (Pi 4)
  usb0 = 10.55.0.2   <--- USB-gadget Ethernet --->   usb0 = 10.55.0.1
  agent.py (telemetry)                  example_sem.bpf.c (tc ingress)
```

## Gate 1 — link is up

The USB-gadget interface does not always come up with an address after a reboot. On **each** device:

```bash
# field device
sudo ip addr add 10.55.0.2/24 dev usb0
sudo ip link set usb0 up
# gateway
sudo ip addr add 10.55.0.1/24 dev usb0
sudo ip link set usb0 up
```

Verify:

```bash
ping -c3 10.55.0.1   # from the field device
```

0% loss → Gate 1 passed.

## Gate 2 — program loaded and attached

On the **gateway**:

```bash
sudo ./bpf/run.sh load usb0
sudo tc filter show dev usb0 ingress   # should list a bpf sched_cls filter
```

## Gate 3 — traffic flows

On the **field device**:

```bash
python3 scripts/agent.py --interval 0.03 --gateway 10.55.0.1
```

On the **gateway**, confirm the program counter advances:

```bash
sudo sysctl -w kernel.bpf_stats_enabled=1
sudo bpftool prog show | grep sem_prog   # run twice; run_cnt must increase
```

`run_cnt` increasing → the datapath is live and you can run any measurement.

## Notes

- **netem is directional (egress).** Apply impairment on the field device:
  `sudo tc qdisc add dev usb0 root netem loss 30%` ; remove with `sudo tc qdisc del dev usb0 root`.
- **eBPF does not survive a reboot.** Re-run `./bpf/run.sh load usb0` after restarting the gateway.
- **Residual programs.** Repeated `load` without `unload` stacks tc filters. Clear them with
  `sudo tc qdisc del dev usb0 clsact` before reloading, and always measure by program **id**
  (`bpftool prog show id <ID>`) to avoid ambiguity.
