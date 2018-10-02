#!/bin/bash
#load configurations
. qos.cfg

function system_stuff(){

#https://bugzilla.redhat.com/show_bug.cgi?id=1011281
#echo 1 >/sys/module/sch_htb/parameters/htb_rate_est

#load ifb module
modprobe ifb
#load act_mirred module
modprobe act_mirred
#set ifb device as UP
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
iptables -t mangle -N QOS_DPI
iptables -t mangle -A FORWARD -j QOS_SLOWDOWN
iptables -t mangle -A FORWARD -m mark --mark 0 -o $WAN -j QOS_DOWNLOAD
iptables -t mangle -A FORWARD -o $WAN -m mark ! --mark 0 -j QOS_UPLOAD
iptables -t mangle -A PREROUTING -m connmark ! --mark 0 -j RESTORE-MARK
iptables -t mangle -A POSTROUTING -m mark ! --mark 0 -j SAVE-MARK

#restore mark for previously marked connection
iptables -t mangle -A RESTORE-MARK -m conntrack ! --ctstate NEW -j CONNMARK --restore-mark

#Send everything to nDPI to applications detection
iptables -t mangle -A PREROUTING -j QOS_DPI

#DPI for applications
iptables -t mangle -A QOS_DPI -m connmark --mark $APP_LOW_PRIO_MARK -j RETURN
iptables -t mangle -A QOS_DPI -m connmark --mark $APP_BULK_MARK -j RETURN
iptables -t mangle -A QOS_DPI -m connmark --mark $APP_HIGH_PRIO_MARK -j RETURN
iptables -t mangle -A QOS_DPI -m connbytes --connbytes-mode packets --connbytes-dir both --connbytes 20 -j RETURN
iptables -t mangle -A QOS_DPI -m ndpi --youtube -j CONNMARK --set-mark $APP_LOW_PRIO_MARK
iptables -t mangle -A QOS_DPI -m ndpi --facebook -j CONNMARK --set-mark $APP_BULK_MARK
iptables -t mangle -A QOS_DPI -m ndpi --dropbox -j CONNMARK --set-mark $APP_HIGH_PRIO_MARK

if [ $ENABLE_SLOWDOWN == "on" ]
then
#slow down if traffic generated is higher than 30MB
iptables -t mangle -A QOS_SLOWDOWN \
-p tcp -m multiport --dports 80,443,20,21,990 -m connbytes --connbytes $SLOWDOWN_QUOTA: \
--connbytes-dir both --connbytes-mode bytes -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK

iptables -t mangle -A QOS_SLOWDOWN \
-p tcp -m multiport --dports 80,443,20,21,990 -m connbytes --connbytes $SLOWDOWN_QUOTA: \
--connbytes-dir both --connbytes-mode bytes -j RETURN
fi

#high prio traffic
iptables -t mangle -A QOS_DOWNLOAD -p tcp -m multiport --dports 80,443,22 \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_HIGH_PRIO_MARK

iptables -t mangle -A QOS_DOWNLOAD -p tcp -m multiport --dports 80,443,22 \
-m conntrack --ctstate NEW -j RETURN

#low prio traffic
iptables -t mangle -A QOS_DOWNLOAD -p tcp -m multiport --dports 1024:65535 \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK

iptables -t mangle -A QOS_DOWNLOAD -p tcp -m multiport --dports 1024:65535 \
-m conntrack --ctstate NEW -j RETURN

#In this way i should not need to mark connection for upload,and the mark for download traffic shuold be maintained
#high prio traffic
iptables -t mangle -A QOS_UPLOAD -m mark --mark $DOWN_HIGH_PRIO_MARK -j CLASSIFY --set-class 1:$UP_HIGH_PRIO_MARK
iptables -t mangle -A QOS_UPLOAD -m mark --mark $DOWN_HIGH_PRIO_MARK -j RETURN
iptables -t mangle -A QOS_UPLOAD -m mark --mark $DOWN_LOW_PRIO_MARK -j CLASSIFY --set-class 1:$UP_LOW_PRIO_MARK
iptables -t mangle -A QOS_UPLOAD -m mark --mark $DOWN_LOW_PRIO_MARK -j RETURN
iptables -t mangle -A QOS_UPLOAD -m mark --mark $DOWN_BULK_MARK -j CLASSIFY --set-class 1:$UP_BULK_MARK
iptables -t mangle -A QOS_UPLOAD -m mark --mark $DOWN_BULK_MARK -j RETURN

# #save mark of the previously marked connections
iptables -t mangle -A SAVE-MARK -m conntrack --ctstate NEW -j CONNMARK --save-mark
}

function start(){

system_stuff
#######################DOWNLOAD#############################################
#Defult class is bulk traffic class
tc qdisc add dev $IFB root handle 1: htb default $DOWN_BULK_MARK

#set global download value
tc class add dev $IFB parent 1: classid 1:1 htb rate $WAN_DOWNLOAD burst 15k

#high priority class
tc class add dev $IFB parent 1:1 classid 1:$DOWN_HIGH_PRIO_MARK htb rate $HIGH_PRIO_DOWN_GUARANTEED  \
ceil $HIGH_PRIO_DOWN_MAX quantum 1514 burst 15k prio 0

#low priority class
tc class add dev $IFB parent 1:1 classid 1:$DOWN_LOW_PRIO_MARK htb rate $LOW_PRIO_DOWN_GUARANTEED \
ceil $LOW_PRIO_DOWN_MAX quantum 1514 burst 15k prio 9

#bulk traffic class
tc class add dev $IFB parent 1:1 classid 1:$DOWN_BULK_MARK htb rate $DOWNLOAD_GUARANTEED_DEFAULT \
ceil $DOWNLOAD_MAX_DEFAULT quantum 1514 burst 15k prio 5

#use class [high prio]
tc filter add dev $IFB parent 1:0 protocol ip handle $DOWN_HIGH_PRIO_MARK fw flowid 1:$DOWN_HIGH_PRIO_MARK
tc filter add dev $IFB parent 1:0 protocol ip handle $APP_HIGH_PRIO_MARK fw flowid 1:$DOWN_HIGH_PRIO_MARK

#use class [low prio]
tc filter add dev $IFB parent 1:0 protocol ip handle $DOWN_LOW_PRIO_MARK fw flowid 1:$DOWN_LOW_PRIO_MARK
tc filter add dev $IFB parent 1:0 protocol ip handle $APP_LOW_PRIO_MARK fw flowid 1:$DOWN_LOW_PRIO_MARK

#use class [bulk traffic]
tc filter add dev $IFB parent 1:0 protocol ip handle $DOWN_BULK_MARK fw flowid 1:$DOWN_BULK_MARK
tc filter add dev $IFB parent 1:0 protocol ip handle $APP_BULK_MARK fw flowid 1:$DOWN_BULK_MARK

# Tell which algorithm the classes use
tc qdisc add dev $IFB parent 1:$DOWN_HIGH_PRIO_MARK sfq perturb 10
tc qdisc add dev $IFB parent 1:$DOWN_LOW_PRIO_MARK sfq perturb 10
tc qdisc add dev $IFB parent 1:$DOWN_BULK_MARK sfq perturb 10

#redirect everything to ifb interface,needed for ingress (traffic coming from WAN)
tc qdisc add dev $WAN handle ffff: ingress
tc filter add dev $WAN parent ffff: protocol ip u32 match u32 0 0 action \
connmark action mirred egress redirect dev $IFB

# ######################UPLOAD################################################
#default class is bulk traffic class
tc qdisc add dev $WAN root handle 1:0 htb default $UP_BULK_MARK

#set the global upload value
tc class add dev $WAN parent 1: classid 1:1 htb rate $WAN_UPLOAD burst 15k

#high priority class
tc class add dev $WAN parent 1:1 classid 1:$UP_HIGH_PRIO_MARK htb rate $HIGH_PRIO_UP_GUARANTEED ceil $HIGH_PRIO_UP_MAX quantum 1514 burst 15k prio 0

#low priority class
tc class add dev $WAN parent 1:1 classid 1:$UP_LOW_PRIO_MARK htb rate $LOW_PRIO_UP_GUARANTEED ceil $LOW_PRIO_UP_MAX quantum 1514 burst 15k prio 9

#bulk traffic class
tc class add dev $WAN parent 1:1 classid 1:$UP_BULK_MARK htb rate $UPLOAD_GUARANTEED_DEFAULT ceil $UPLOAD_MAX_DEFAULT quantum 1514 burst 15k prio 5

# Tell which algorithm the classes use
tc qdisc add dev $WAN parent 1:$UP_HIGH_PRIO_MARK sfq perturb 10
tc qdisc add dev $WAN parent 1:$UP_LOW_PRIO_MARK sfq perturb 10
tc qdisc add dev $WAN parent 1:$UP_BULK_MARK sfq perturb 10

iptables_rules
}

function stop(){
#remove tc devices
tc qdisc del dev $WAN ingress
tc qdisc del dev $WAN root
tc qdisc del dev $IFB root

#flush iptables rules
iptables -t mangle -F SAVE-MARK
iptables -t mangle -D POSTROUTING -m mark ! --mark 0 -j SAVE-MARK
iptables -t mangle -X SAVE-MARK
iptables -t mangle -F RESTORE-MARK
iptables -t mangle -D PREROUTING -m connmark ! --mark 0 -j RESTORE-MARK
iptables -t mangle -X RESTORE-MARK
iptables -t mangle -F QOS_SLOWDOWN
iptables -t mangle -D FORWARD -j QOS_SLOWDOWN
iptables -t mangle -X QOS_SLOWDOWN
iptables -t mangle -F QOS_DOWNLOAD
iptables -t mangle -D FORWARD -m mark --mark 0 -o $WAN -j QOS_DOWNLOAD
iptables -t mangle -X QOS_DOWNLOAD
iptables -t mangle -F QOS_UPLOAD
iptables -t mangle -D FORWARD -o $WAN -m mark ! --mark 0 -j QOS_UPLOAD
iptables -t mangle -X QOS_UPLOAD
iptables -t mangle -F QOS_DPI
iptables -t mangle -D PREROUTING -j QOS_DPI
iptables -t mangle -X QOS_DPI
iptables -t nat -D POSTROUTING -o $WAN -j MASQUERADE

#disable forwarding
sysctl -w net.ipv4.ip_forward=0

#remove Qos modules
rmmod ifb
rmmod act_mirred
}

function show() {
  local qos_dev
  clear
  echo "## Download QoS classes ##"
  tc -g -s -nm -cf qos_class_mapping.cfg class show dev $IFB
  echo " "
  echo "## Upload QoS classes ##"
  tc -g -s -nm -cf qos_class_mapping.cfg class show dev $WAN
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
stats)
       show
      ;;
*)
   echo "usage $0 start|stop|restart|stats"
    ;;
esac
