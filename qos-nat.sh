#!/bin/bash

WAN="eth2"
IFB="ifb0"

WAN_DOWNLOAD="1000mbit"
WAN_UPLOAD="1000mbit"

DEF_DOWNLOAD_GUARANTEED="256kbit"
DEF_DOWNLOAD_MAX="1mbit"

GUARANTEED_DOWNLOAD_CLASS_1="1mbit"
MAX_DOWNLOAD_CLASS_1="4mbit"

GUARANTEED_DOWNLOAD_CLASS_2="512kbit"
MAX_DOWNLOAD_CLASS_2="512kbit"


GUARANTEED_UPLOAD_CLASS_1="512kbit"
MAX_UPLOAD_CLASS_1="2mbit"

GUARANTEED_UPLOAD_CLASS_2="512kbit"
MAX_UPLOAD_CLASS_2="1mbit"

DEF_UPLOAD_GUARANTEED="64kbit"
DEF_UPLOAD_MAX="2mbit"

function system_stuff(){
modprobe ifb
modprobe act_mirred
ip link set dev $IFB up

#Outgoing NAT
iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE

#Enable ip forwarding,otherwise device behind this GW won't reach Internet
sysctl -w net.ipv4.ip_forward=1
}

function iptables_rules(){
#Qos chains
iptables -t mangle -N QOS_UPLOAD
iptables -t mangle -N QOS_DOWNLOAD
iptables -t mangle -N QOS_SLOWDOWN
iptables -t mangle -N RESTORE-MARK
iptables -t mangle -N SAVE-MARK
iptables -t mangle -A FORWARD -j QOS_SLOWDOWN
iptables -t mangle -A FORWARD -j QOS_DOWNLOAD
iptables -t mangle -A FORWARD -j QOS_UPLOAD
iptables -t mangle -A PREROUTING -j RESTORE-MARK
iptables -t mangle -A POSTROUTING -j SAVE-MARK

#restore mark for previously marked connection
iptables -t mangle -A RESTORE-MARK -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark

#slow down if traffic generated is higher than 30MB
iptables -t mangle -A QOS_SLOWDOWN -o $WAN -p tcp -m multiport --dports 80,443,10443 -m connbytes \
--connbytes 30000000: --connbytes-dir both --connbytes-mode bytes -j MARK --set-mark 11
iptables -t mangle -A QOS_SLOWDOWN -o $WAN -p tcp -m multiport --dports 80,443,10443 -m connbytes \
--connbytes 30000000: --connbytes-dir both --connbytes-mode bytes -j RETURN

#high prio traffic
iptables -t mangle -A QOS_DOWNLOAD -m comment --comment "--1mb/s up to 4mb/s--" -m mark --mark 0 -o $WAN -p tcp -m multiport --dports 80,443 \
-m conntrack --ctstate NEW -j MARK --set-mark 10
iptables -t mangle -A QOS_DOWNLOAD -o $WAN -p tcp -m multiport --dports 80,443 \
-m conntrack --ctstate NEW -j RETURN

#low prio traffic
iptables -t mangle -A QOS_DOWNLOAD -m comment --comment "--512kb/s up to 512kb/s--" -m mark --mark 0 -o $WAN -p tcp -m multiport --dports 1024:65535 \
-m conntrack --ctstate NEW -j MARK --set-mark 11
iptables -t mangle -A QOS_DOWNLOAD -o $WAN -p tcp -m multiport --dports 1024:65535 \
-m conntrack --ctstate NEW -j RETURN

#In this way i should not need to mark connection for upload,and the mark for download traffic shuold be maintained
#high prio traffic
iptables -t mangle -m comment --comment "--512kb/s up to 2048kb/s--" -A QOS_UPLOAD -o $WAN -j CLASSIFY --set-class 1:21
iptables -t mangle -A QOS_UPLOAD -o $WAN -j RETURN

# #save mark of the previously marked connections
iptables -t mangle -A SAVE-MARK -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
}

function start(){

system_stuff
#######################DOWNLOAD#############################################
#Defult class is 12 - bulk traffic
tc qdisc add dev $IFB root handle 1: htb default 12

#set download value
tc class add dev $IFB parent 1: classid 1:1 htb rate $WAN_DOWNLOAD burst 15k

#high priority class - 1mb/s up to 4mb/s
tc class add dev $IFB parent 1:1 classid 1:10 htb rate $GUARANTEED_DOWNLOAD_CLASS_1 ceil $MAX_DOWNLOAD_CLASS_1 quantum 1514 burst 15k prio 9

#low priority class - guarantee 512kb/s up to 512kb/s
tc class add dev $IFB parent 1:1 classid 1:11 htb rate $GUARANTEED_DOWNLOAD_CLASS_2 ceil $MAX_DOWNLOAD_CLASS_2 quantum 1514 burst 15k prio 0

#bulk traffic - guarantee 256kb/s up to 10mb/s
tc class add dev $IFB parent 1:1 classid 1:12 htb rate $DEF_DOWNLOAD_GUARANTEED ceil $DEF_DOWNLOAD_MAX quantum 1514 burst 15k prio 5

#use class 10 [high prio] for every connection marked with 10
tc filter add dev $IFB parent 1:0 protocol ip handle 10 fw flowid 1:10

#use class 11 [low prio] for every connection marked with 11
tc filter add dev $IFB parent 1:0 protocol ip handle 11 fw flowid 1:11

# Tell which algorithm the classes use
tc qdisc add dev $IFB parent 1:10 sfq perturb 10
tc qdisc add dev $IFB parent 1:11 sfq perturb 10
tc qdisc add dev $IFB parent 1:12 sfq perturb 10

#redirect everything to ifb interface,needed for ingress (traffic coming from WAN)
tc qdisc add dev $WAN handle ffff: ingress
tc filter add dev $WAN parent ffff: protocol ip u32 match u32 0 0 action connmark action mirred egress redirect dev $IFB

######################UPLOAD################################################
#default class is 22
tc qdisc add dev $WAN root handle 1:0 htb default 23

#set the upload value
tc class add dev $WAN parent 1: classid 1:1 htb rate $WAN_UPLOAD burst 15k

#high priority class - guarantee 512kb/s up to 2mkb/s
tc class add dev $WAN parent 1:1 classid 1:21 htb rate $GUARANTEED_UPLOAD_CLASS_1 ceil $MAX_UPLOAD_CLASS_1 quantum 1514 burst 15k prio 9

#low priority class - guarantee 512kb/s up to 1mb/s
tc class add dev $WAN parent 1:1 classid 1:22 htb rate $GUARANTEED_UPLOAD_CLASS_2 ceil $MAX_UPLOAD_CLASS_2 quantum 1514 burst 15k prio 0

#bulk traffic - guarantee 64kb/s up to 2mb/s
tc class add dev $WAN parent 1:1 classid 1:23 htb rate $DEF_UPLOAD_GUARANTEED ceil $DEF_UPLOAD_MAX quantum 1514 burst 15k prio 5

# Tell which algorithm the classes use
tc qdisc add dev $WAN parent 1:21 sfq perturb 10
tc qdisc add dev $WAN parent 1:22 sfq perturb 10
tc qdisc add dev $WAN parent 1:23 sfq perturb 10

iptables_rules
}

function stop(){
#remove tc devices
tc qdisc del dev $WAN ingress
tc qdisc del dev $WAN root
tc qdisc del dev $IFB root

#flush iptables rules
iptables -t mangle -F SAVE-MARK
iptables -t mangle -D POSTROUTING -j SAVE-MARK
iptables -t mangle -X SAVE-MARK
iptables -t mangle -F RESTORE-MARK
iptables -t mangle -D PREROUTING -j RESTORE-MARK
iptables -t mangle -X RESTORE-MARK
iptables -t mangle -F QOS_SLOWDOWN
iptables -t mangle -D FORWARD -j QOS_SLOWDOWN
iptables -t mangle -X QOS_SLOWDOWN
iptables -t mangle -F QOS_DOWNLOAD
iptables -t mangle -D FORWARD -j QOS_DOWNLOAD
iptables -t mangle -X QOS_DOWNLOAD
iptables -t mangle -F QOS_UPLOAD
iptables -t mangle -D FORWARD -j QOS_UPLOAD
iptables -t mangle -X QOS_UPLOAD
iptables -t nat -D POSTROUTING -o $WAN -j MASQUERADE

#disable forwarding
sysctl -w net.ipv4.ip_forward=0

#remove Qos modules
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
   echo "usage $0 start|stop|restart"
    ;;
esac
