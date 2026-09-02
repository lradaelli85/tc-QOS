#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd)
. "$SCRIPT_DIR/qos.cfg"

NFT_TABLE=tc_qos
NFT_NAT_TABLE=tc_qos_nat

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Command not found: $1"; }

add_system_configurations() {
    need nft; need tc; need ip; need modprobe
    modprobe ifb
    modprobe act_mirred
    if ! grep -q "${IFB}" /proc/net/dev
    then
      ip link add name "${IFB}" type ifb
    fi
    ip link set dev "$IFB" up
    if [[ ${ENABLE_NAT:-off} == on ]]; then
        sysctl -w net.ipv4.ip_forward=1
    fi
}

del_system_configurations() {
    if [[ ${ENABLE_NAT:-off} == on ]]; then
        sysctl -w net.ipv4.ip_forward=0
    fi
    rmmod ifb 2>/dev/null || true
    rmmod act_mirred 2>/dev/null || true
}

emit_port_rule() {
    local proto=$1 ports=$2 mark=$3
    [[ -n $ports ]] || return 0
    printf '        %s dport %s ct state new ct mark set %s return\n' \
        "$proto" "{ $ports }" "$mark"
}

emit_slowdown_rule() {
    local proto=$1 ports=$2
    [[ -n $ports ]] || return 0
    printf '        %s dport %s ct bytes >= %s ct mark set %s return\n' \
        "$proto" "{ $ports }" "$SLOWDOWN_QUOTA" "$DOWN_LOW_PRIO_MARK"
}

add_nftables_rules() {
    local rules
    rules=$(mktemp)
    {
        echo "table inet $NFT_TABLE {"
        echo '    chain prerouting {'
        echo '        type filter hook prerouting priority mangle; policy accept;'
        echo '        ct mark != 0 meta mark set ct mark'
        echo '    }'
        echo '    chain classify {'
        emit_port_rule tcp "${TCP_HIGH_PRIO_PORTS:-}" "$DOWN_HIGH_PRIO_MARK"
        emit_port_rule udp "${UDP_HIGH_PRIO_PORTS:-}" "$DOWN_HIGH_PRIO_MARK"
        emit_port_rule tcp "${TCP_BULK_PORTS:-}" "$DOWN_BULK_MARK"
        emit_port_rule udp "${UDP_BULK_PORTS:-}" "$DOWN_BULK_MARK"
        emit_port_rule tcp "${TCP_LOW_PRIO_PORTS:-}" "$DOWN_LOW_PRIO_MARK"
        emit_port_rule udp "${UDP_LOW_PRIO_PORTS:-}" "$DOWN_LOW_PRIO_MARK"
        echo '    }'
        echo '    chain forward {'
        echo '        type filter hook forward priority mangle; policy accept;'
        if [[ ${ENABLE_SLOWDOWN:-off} == on ]]; then
            emit_slowdown_rule tcp "${TCP_SLOWDOWN_PORTS:-}"
            emit_slowdown_rule udp "${UDP_SLOWDOWN_PORTS:-}"
        fi
        printf '        oifname "%s" ct mark 0 jump classify\n' "$WAN"
        echo '        meta mark set ct mark'
        printf '        oifname "%s" ct mark %s meta priority set 1:%s\n' "$WAN" "$DOWN_HIGH_PRIO_MARK" "$UP_HIGH_PRIO_MARK"
        printf '        oifname "%s" ct mark %s meta priority set 1:%s\n' "$WAN" "$DOWN_LOW_PRIO_MARK" "$UP_LOW_PRIO_MARK"
        printf '        oifname "%s" ct mark %s meta priority set 1:%s\n' "$WAN" "$DOWN_BULK_MARK" "$UP_BULK_MARK"
        echo '    }'
        echo '    chain postrouting {'
        echo '        type filter hook postrouting priority mangle; policy accept;'
        echo '        ct mark != 0 meta mark set ct mark'
        echo '    }'
        echo '}'

        if [[ ${ENABLE_NAT:-off} == on ]]; then
            echo "table ip $NFT_NAT_TABLE {"
            echo '    chain postrouting {'
            echo '        type nat hook postrouting priority srcnat; policy accept;'
            printf '        oifname "%s" masquerade\n' "$WAN"
            echo '    }'
            echo '}'
        fi
    } >"$rules"

    del_nftables_rules
    nft -c -f "$rules"
    nft -f "$rules"
    rm -f "$rules"
}

del_nftables_rules() {
    nft list table inet "$NFT_TABLE" >/dev/null 2>&1 && nft delete table inet "$NFT_TABLE" || true
    nft list table ip "$NFT_NAT_TABLE" >/dev/null 2>&1 && nft delete table ip "$NFT_NAT_TABLE" || true
}

add_qos_devs_and_classes() {
    if [[ ${BULK_DEFAULT:-off} == on ]]; then
        tc qdisc add dev "$IFB" root handle 1: htb default "$DOWN_BULK_MARK"
    else
        tc qdisc add dev "$IFB" root handle 1: htb
    fi
    tc class add dev "$IFB" parent 1: classid 1:1 htb rate "$WAN_DOWNLOAD" burst "$BURST"
    tc class add dev "$IFB" parent 1:1 classid "1:$DOWN_HIGH_PRIO_MARK" htb rate "$HIGH_PRIO_DOWN_GUARANTEED" ceil "$HIGH_PRIO_DOWN_MAX" quantum "$QUANTUM" burst "$BURST" prio 0
    tc class add dev "$IFB" parent 1:1 classid "1:$DOWN_LOW_PRIO_MARK" htb rate "$LOW_PRIO_DOWN_GUARANTEED" ceil "$LOW_PRIO_DOWN_MAX" quantum "$QUANTUM" burst "$BURST" prio 7
    tc class add dev "$IFB" parent 1:1 classid "1:$DOWN_BULK_MARK" htb rate "$DOWNLOAD_GUARANTEED_DEFAULT" ceil "$DOWNLOAD_MAX_DEFAULT" quantum "$QUANTUM" burst "$BURST" prio 5
    tc filter add dev "$IFB" parent 1:0 protocol ip handle "$DOWN_HIGH_PRIO_MARK" fw flowid "1:$DOWN_HIGH_PRIO_MARK"
    tc filter add dev "$IFB" parent 1:0 protocol ip handle "$DOWN_LOW_PRIO_MARK" fw flowid "1:$DOWN_LOW_PRIO_MARK"
    tc filter add dev "$IFB" parent 1:0 protocol ip handle "$DOWN_BULK_MARK" fw flowid "1:$DOWN_BULK_MARK"
    tc qdisc add dev "$IFB" parent "1:$DOWN_HIGH_PRIO_MARK" sfq perturb 10
    tc qdisc add dev "$IFB" parent "1:$DOWN_LOW_PRIO_MARK" sfq perturb 10
    tc qdisc add dev "$IFB" parent "1:$DOWN_BULK_MARK" sfq perturb 10

    # Gestione Ingress della WAN tramite TC senza l'azione connmark rimossa
    tc qdisc add dev "$WAN" handle ffff: ingress
    tc filter add dev "$WAN" parent ffff: protocol ip u32 match u32 0 0 action mirred egress redirect dev "$IFB"

    if [[ ${BULK_DEFAULT:-off} == on ]]; then
        tc qdisc add dev "$WAN" root handle 1: htb default "$UP_BULK_MARK"
    else
        tc qdisc add dev "$WAN" root handle 1: htb
    fi
    tc class add dev "$WAN" parent 1: classid 1:1 htb rate "$WAN_UPLOAD" burst "$BURST"
    tc class add dev "$WAN" parent 1:1 classid "1:$UP_HIGH_PRIO_MARK" htb rate "$HIGH_PRIO_UP_GUARANTEED" ceil "$HIGH_PRIO_UP_MAX" quantum "$QUANTUM" burst "$BURST" prio 0
    tc class add dev "$WAN" parent 1:1 classid "1:$UP_LOW_PRIO_MARK" htb rate "$LOW_PRIO_UP_GUARANTEED" ceil "$LOW_PRIO_UP_MAX" quantum "$QUANTUM" burst "$BURST" prio 7
    tc class add dev "$WAN" parent 1:1 classid "1:$UP_BULK_MARK" htb rate "$UPLOAD_GUARANTEED_DEFAULT" ceil "$UPLOAD_MAX_DEFAULT" quantum "$QUANTUM" burst "$BURST" prio 5
    tc qdisc add dev "$WAN" parent "1:$UP_HIGH_PRIO_MARK" sfq perturb 10
    tc qdisc add dev "$WAN" parent "1:$UP_LOW_PRIO_MARK" sfq perturb 10
    tc qdisc add dev "$WAN" parent "1:$UP_BULK_MARK" sfq perturb 10
}

del_qos_devs_and_classes() {
    tc qdisc del dev "$WAN" ingress 2>/dev/null || true
    tc qdisc del dev "$WAN" root 2>/dev/null || true
    tc qdisc del dev "$IFB" root 2>/dev/null || true
}

start() {
    add_system_configurations
    add_nftables_rules
    if ! add_qos_devs_and_classes; then
        del_qos_devs_and_classes
        del_nftables_rules
        die 'Error in creating tc classes.Running rollback'
    fi
}

stop() {
    del_qos_devs_and_classes
    del_nftables_rules
    del_system_configurations
}

show() {
    echo '## Download QoS classes ##'
    tc -g -s -nm -cf "$SCRIPT_DIR/qos_class_mapping.cfg" class show dev "$IFB"
    echo
    echo '## Upload QoS classes ##'
    tc -g -s -nm -cf "$SCRIPT_DIR/qos_class_mapping.cfg" class show dev "$WAN"
}

case ${1:-} in
    start)   start ;;
    stop)    stop ;;
    restart) stop; start ;;
    stats)   show ;;
    *) printf 'usage: %s start|stop|restart|stats\n' "$0" >&2; exit 2 ;;
esac
