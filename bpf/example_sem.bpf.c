// SPDX-License-Identifier: GPL-2.0
//
// example_sem.bpf.c — programa eBPF REPRESENTATIVO y GENÉRICO para reproducir
// la metodología de medición de sobrecosto del paper.
//
// NO es un sistema de observabilidad. Solo: (1) parsea la cabecera hasta L4,
// (2) mantiene estado por flujo en un mapa LRU hash, (3) actualiza contadores e
// inter-arribo. Su tamaño y costo son representativos de un clasificador in-band
// del datapath, suficiente para medir el sobrecosto. La lógica semántica real
// (cómputo de features, clasificación) NO está aquí; es objeto de trabajo aparte.
//
// identificadores en inglés, comentarios en español.

#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <linux/pkt_cls.h>

// clave del flujo: 4-tupla reducida (representativa), 16 B
struct flow_key {
    __u32 saddr;
    __u32 daddr;
    __u16 sport;
    __u16 dport;
    __u32 proto;
};

// valor por flujo: contadores e inter-arribo, ~88 B (representativo)
struct flow_feat_t {
    __u64 pkts;
    __u64 bytes;
    __u64 last_ts_ns;
    __u64 mean_iat_ns;
    __u64 min_len;
    __u64 max_len;
    __u64 _reserved[5];   // relleno hasta tamaño representativo
};

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);   // auto-evicta flujos viejos
    __uint(max_entries, 65536);            // capacidad: parámetro del barrido (Tabla III)
    __type(key, struct flow_key);
    __type(value, struct flow_feat_t);
} flow_feat SEC(".maps");

SEC("tc")
int sem_prog(struct __sk_buff *skb)
{
    void *data = (void *)(long)skb->data;
    void *data_end = (void *)(long)skb->data_end;

    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return TC_ACT_OK;
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return TC_ACT_OK;

    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return TC_ACT_OK;

    struct flow_key key = {};
    key.saddr = ip->saddr;
    key.daddr = ip->daddr;
    key.proto = ip->protocol;

    if (ip->protocol == IPPROTO_UDP) {
        struct udphdr *udp = (void *)ip + (ip->ihl * 4);
        if ((void *)(udp + 1) > data_end)
            return TC_ACT_OK;
        key.sport = bpf_ntohs(udp->source);
        key.dport = bpf_ntohs(udp->dest);
    }

    __u64 now = bpf_ktime_get_ns();
    __u16 len = skb->len;

    struct flow_feat_t *f = bpf_map_lookup_elem(&flow_feat, &key);
    if (f) {
        // actualizar estado por flujo (inter-arribo acumulado, representativo)
        __u64 iat = now - f->last_ts_ns;
        f->mean_iat_ns = (f->mean_iat_ns * f->pkts + iat) / (f->pkts + 1);
        f->pkts += 1;
        f->bytes += len;
        f->last_ts_ns = now;
        if (len < f->min_len) f->min_len = len;
        if (len > f->max_len) f->max_len = len;
    } else {
        struct flow_feat_t nf = {};
        nf.pkts = 1;
        nf.bytes = len;
        nf.last_ts_ns = now;
        nf.min_len = len;
        nf.max_len = len;
        bpf_map_update_elem(&flow_feat, &key, &nf, BPF_ANY);
    }

    return TC_ACT_OK;   // observa, no modifica (in-band)
}

char LICENSE[] SEC("license") = "GPL";
