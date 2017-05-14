#!/bin/bash

WAN="wlp5s0"
IFB="ifb0"
DOWNLOAD="10240kbit"
UPLOAD="512kbit"
RATE_CLASS_1="1024kbit"
CEIL_CLASS_1="4096kbit"
RATE_CLASS_2="512kbit"
CEIL_CLASS_2="512kbit"
RATE_CLASS_DEF="256kbit"
CEIL_CLASS_DEF="10240kbit"
UPLOAD_RATE_CLASS_1="64kbit"
UPLOAD_CEIL_CLASS_1="128kbit"
UPLOAD_RATE_CLASS_DEF="64kbit"
UPLOAD_CEIL_CLASS_DEF="64kbit"

function system_stuff(){

        modprobe ifb
        modprobe act_mirred
        ifconfig $IFB up
        #Outgoing NAT
        iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
        #Enable ip forwarding,otherwise device behind this GW won't reach Internet
        sysctl -w net.ipv4.ip_forward=1



}

function iptables_rules(){
        #Qos chains
iptables -t mangle -N QOS_DOWNLOAD
#iptables -t mangle -N QOS_UPLOAD
iptables -t mangle -A FORWARD -j QOS_DOWNLOAD
        #iptables -t mangle -A POSTROUTING -j QOS_UPLOAD
        #iptables -t mangle -A PREROUTING -j QOS
#iptables -t mangle -A QOS --proto tcp -m tcp --tcp-flags SYN,RST,ACK ACK -m length --length 0:128 -m connmark ! --mark 0 -j --set-mark 10
iptables -t mangle -A PREROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark
iptables -t mangle -A QOS_DOWNLOAD -m mark --mark 0 -o $WAN -p tcp -m multiport --dports 80,443 -m conntrack --ctstate  NEW -j MARK --set-mark 10
iptables -t mangle -A QOS_DOWNLOAD -m mark --mark 0 -o $WAN -p icmp -m conntrack --ctstate  NEW -j MARK --set-mark 10
iptables -t mangle -A QOS_DOWNLOAD -m mark --mark 0 -o $WAN -p tcp -m multiport --dports 1024:65535 -m conntrack --ctstate  NEW -j MARK --set-mark 11
        #iptables -t mangle -A QOS_UPLOAD -o $WAN
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j RETURN


}

function start(){

system_stuff
#######################DOWNLOAD#############################################
        #
        # #setting everything for download stuff
        # tc qdisc add dev $IFB root handle 1: htb default 12
        # tc class add dev $IFB parent 1: classid 1:1 htb rate $DOWNLOAD burst 15k
        # #high priority class - 1mb/s guaranteed up tp 4mb/s
        # tc class add dev $IFB parent 1:1 classid 1:10 htb rate $RATE_CLASS_1 \
        # ceil $CEIL_CLASS_1 quantum 1514 burst 15k prio 0
        # #low priority class - guarantee 512kb/s up to 512kb/s
        # tc class add dev $IFB parent 1:1 classid 1:11 htb rate $RATE_CLASS_2 \
        # ceil $CEIL_CLASS_2 quantum 1514 burst 15k prio 9
        # #bulk traffic - guarantee 256kb/s up to 10mb/s
        # tc class add dev $IFB parent 1:1 classid 1:12 htb rate $RATE_CLASS_DEF \
        # ceil $CEIL_CLASS_DEF quantum 1514 burst 15k prio 5
        # #use class 10 for every connection marked with 10
        # tc filter add dev $IFB parent 1:0 protocol ip handle 10 fw flowid 1:10
        # #use class 11 for every connection marked with 11
        # tc filter add dev $IFB parent 1:0 protocol ip handle 11 fw flowid 1:11
        # # Tell which algorithm the classes use
        # tc qdisc add dev $IFB parent 1:10 sfq
        # tc qdisc add dev $IFB parent 1:11 sfq
        # tc qdisc add dev $IFB parent 1:12 sfq
        # #redirect everything to ifb interface
        # tc qdisc add dev $WAN handle ffff: ingress
        # tc filter add dev $WAN parent ffff: protocol ip u32 match u32 0 0 \
        # action connmark action mirred egress redirect dev $IFB

# ######################UPLOAD################################################
         tc qdisc add dev $WAN root handle 1:0 htb default 22
         tc class add dev $WAN parent 1: classid 1:1 htb rate $UPLOAD
#         #high priority class - guarantee 512kb/s up to 512kb/s
         tc class add dev $WAN parent 1:1 classid 1:21 htb rate \
         $UPLOAD_RATE_CLASS_1 ceil $UPLOAD_CEIL_CLASS_1  prio 0
#         #low priority class - guarantee 512kb/s up to 512kb/s
         tc class add dev $WAN parent 1:1 classid 1:22 htb rate \
         $UPLOAD_RATE_CLASS_DEF ceil $UPLOAD_CEIL_CLASS_DEF prio 9
         tc qdisc add dev $WAN parent 1:21 sfq
         tc qdisc add dev $WAN parent 1:22 sfq



iptables_rules
}

function stop(){
        tc qdisc del dev $WAN ingress
        tc qdisc del dev $WAN root
        tc qdisc del dev $IFB root
        iptables -t mangle -F PREROUTING
        iptables -t mangle -F FORWARD
        iptables -t mangle -F QOS_DOWNLOAD
        iptables -t mangle -X QOS_DOWNLOAD
        sysctl -w net.ipv4.ip_forward=0
        iptables -t nat -D POSTROUTING -o $WAN -j MASQUERADE
        iptables -t mangle -F PREROUTING
        iptables -t mangle -F POSTROUTING
        ifconfig $IFB down
        rmmod ifb
        rmmod act_mirred
}

case $1 in
start)
      start
      ;;
stop)
      stop
      ;;
restart)
        stop
        start
      ;;
*)
   echo "usage $0 start|stop"
    ;;
esac
