#!/bin/bash
RED="eth3"
IFB="ifb0"
DOWNLOAD="102400kbit"
UPLOAD="102400kbit"
RATE_CLASS_1="1024kbit"
CEIL_CLASS_1="4096kbit"
RATE_CLASS_DEF="1024kbit"
CEIL_CLASS_DEF="10240kbit"
start(){
modprobe ifb
modprobe act_mirred
ifconfig $IFB up

tc qdisc add dev $RED handle ffff: ingress
tc filter add dev $RED parent ffff: protocol all u32 match u32 0 0 flowid 1:1 action mirred egress redirect dev $IFB

tc qdisc add dev $IFB root handle 1: htb default 15
tc class add dev $IFB parent 1: classid 1:1 htb rate $DOWNLOAD ceil $DOWNLOAD
tc class add dev $IFB parent 1:1 classid 1:14 htb rate $RATE_CLASS_1 ceil $CEIL_CLASS_1 prio 0 quantum 1514
tc class add dev $IFB parent 1:1 classid 1:15 htb rate $RATE_CLASS_DEF ceil $CEIL_CLASS_DEF prio 1 quantum 1514
tc filter add dev $IFB protocol ip parent 1:0 prio 1 u32 match ip sport 443 0xffff flowid 1:14
tc filter add dev $IFB protocol ip parent 1:0 prio 1 u32 match ip sport 80 0xffff flowid 1:14


}

stop(){
tc qdisc del dev $RED ingress
tc qdisc del dev $IFB root
iptables -F OUTPUT
rmmod ifb
rmmod act_mirred
}

case $1 in 
start)start
      ;;
 stop)stop
      ;;
restart)stop
        start
        ;;
    *)echo "usage $0 start|stop"
      ;;
esac
