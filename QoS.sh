#!/bin/bash

#load configurations
. qos.cfg

IPTMAN="iptables -t mangle"

function add_system_configurations(){
#https://bugzilla.redhat.com/show_bug.cgi?id=1011281
#echo 1 >/sys/module/sch_htb/parameters/htb_rate_est

#load ifb module
modprobe ifb

#load act_mirred module
modprobe act_mirred

#set ifb device as UP
ip link set dev $IFB up

if [ $ENABLE_NAT == "on" ]
#Enable ip forwarding,otherwise device behind this GW won't reach Internet
  then
    sysctl -w net.ipv4.ip_forward=1
fi

if [ ! -e $LABEL_CONF ]
  then
    mkdir -p /etc/xtables/
    echo "0 $APP_LABEL" > $LABEL_CONF
  else
    is_present=`grep -c $APP_LABEL $LABEL_CONF`
    if [ $is_present -eq 0 ]
      then
        echo "0 $APP_LABEL" >> $LABEL_CONF
    fi
fi
}

function del_system_configurations(){
if [ $ENABLE_NAT == "on" ]
  then
    #disable forwarding
    sysctl -w net.ipv4.ip_forward=0
fi

#remove Qos modules
rmmod ifb
rmmod act_mirred
}


function l7_classification(){
$IPTMAN -N QOS_DPI

#Send everything to nDPI to applications detection
$IPTMAN -A PREROUTING -j QOS_DPI

#DPI for applications
### $IPTMAN -A QOS_DPI -m connmark --mark $APP_LOW_PRIO_MARK -j RETURN
### $IPTMAN -A QOS_DPI -m connmark --mark $APP_BULK_MARK -j RETURN
### $IPTMAN -A QOS_DPI -m connmark --mark $APP_HIGH_PRIO_MARK -j RETURN
$IPTMAN -A QOS_DPI -m connlabel --label $APP_LABEL -j RETURN
$IPTMAN -A QOS_DPI -m connbytes --connbytes-mode packets --connbytes-dir both --connbytes 20 -j RETURN
if [ ${#LOW_PRIO_APP[@]} -gt 0 ]
  then
    for app in ${LOW_PRIO_APP[@]}
    do
      $IPTMAN -A QOS_DPI -m ndpi --$app -m connlabel --set --label $APP_LABEL -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK
###      $IPTMAN -A QOS_DPI -m ndpi --$app -j CONNMARK --set-mark $APP_LOW_PRIO_MARK
    done
fi
if [ ${#BULK_PRIO_APP[@]} -gt 0 ]
  then
    for app in ${BULK_PRIO_APP[@]}
    do
      $IPTMAN -A QOS_DPI -m ndpi --$app -m connlabel --set --label $APP_LABEL -j CONNMARK --set-mark $DOWN_BULK_MARK
###      $IPTMAN -A QOS_DPI -m ndpi --$app -j CONNMARK --set-mark $APP_BULK_MARK
    done
fi
if [ ${#HIGH_PRIO_APP[@]} -gt 0 ]
  then
    for app in ${HIGH_PRIO_APP[@]}
    do
      $IPTMAN -A QOS_DPI -m ndpi --$app -m connlabel --set --label $APP_LABEL -j CONNMARK --set-mark $DOWN_HIGH_PRIO_MARK
###      $IPTMAN -A QOS_DPI -m ndpi --$app -j CONNMARK --set-mark $APP_HIGH_PRIO_MARK
    done
fi
$IPTMAN -A QOS_UPLOAD -m mark --mark $APP_HIGH_PRIO_MARK -j CLASSIFY --set-class 1:$UP_HIGH_PRIO_MARK
$IPTMAN -A QOS_UPLOAD -m mark --mark $APP_HIGH_PRIO_MARK -j RETURN
$IPTMAN -A QOS_UPLOAD -m mark --mark $APP_LOW_PRIO_MARK -j CLASSIFY --set-class 1:$UP_LOW_PRIO_MARK
$IPTMAN -A QOS_UPLOAD -m mark --mark $APP_LOW_PRIO_MARK -j RETURN
$IPTMAN -A QOS_UPLOAD -m mark --mark $APP_BULK_MARK -j CLASSIFY --set-class 1:$UP_BULK_MARK
$IPTMAN -A QOS_UPLOAD -m mark --mark $APP_BULK_MARK -j RETURN

}

function slowdown(){
$IPTMAN -N QOS_SLOWDOWN
$IPTMAN -I FORWARD -j QOS_SLOWDOWN

if [ ! -z ${TCP_SLOWDOWN_PORTS} ]
then
$IPTMAN -A QOS_SLOWDOWN \
-p tcp -m multiport --dports $TCP_SLOWDOWN_PORTS -m connbytes --connbytes $SLOWDOWN_QUOTA: \
--connbytes-dir both --connbytes-mode bytes -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK

$IPTMAN -A QOS_SLOWDOWN \
-p tcp -m multiport --dports $TCP_SLOWDOWN_PORTS -m connbytes --connbytes $SLOWDOWN_QUOTA: \
--connbytes-dir both --connbytes-mode bytes -j RETURN
fi

if [ ! -z ${UDP_SLOWDOWN_PORTS} ]
then
$IPTMAN -A QOS_SLOWDOWN \
-p udp -m multiport --dports $UDP_SLOWDOWN_PORTS -m connbytes --connbytes $SLOWDOWN_QUOTA: \
--connbytes-dir both --connbytes-mode bytes -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK

$IPTMAN -A QOS_SLOWDOWN \
-p udp -m multiport --dports $UDP_SLOWDOWN_PORTS -m connbytes --connbytes $SLOWDOWN_QUOTA: \
--connbytes-dir both --connbytes-mode bytes -j RETURN
fi
}

function add_iptables_rules(){
if [ $ENABLE_NAT == "on" ]
  then
    #Outgoing NAT
    iptables -t nat -A POSTROUTING -o $WAN -j MASQUERADE
fi
#Qos chains
$IPTMAN -N QOS_UPLOAD
$IPTMAN -N QOS_DOWNLOAD
$IPTMAN -N RESTORE-MARK
$IPTMAN -N SAVE-MARK
$IPTMAN -A FORWARD -m mark --mark 0 -o $WAN -j QOS_DOWNLOAD
$IPTMAN -A FORWARD -o $WAN -m mark ! --mark 0 -j QOS_UPLOAD
$IPTMAN -A PREROUTING -m connmark ! --mark 0 -j RESTORE-MARK
$IPTMAN -A POSTROUTING -m mark ! --mark 0 -j SAVE-MARK

#restore mark for previously marked connection
$IPTMAN -A RESTORE-MARK -m conntrack ! --ctstate NEW -j CONNMARK --restore-mark

if [ $ENABLE_L7 == "on" ]
  then
    l7_classification
fi

if [ $ENABLE_SLOWDOWN == "on" ]
  then
    slowdown
fi

#high prio traffic
#http(s),ssh
$IPTMAN -A QOS_DOWNLOAD -p tcp -m multiport --dports $TCP_HIGH_PRIO_PORTS \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_HIGH_PRIO_MARK

$IPTMAN -A QOS_DOWNLOAD -p tcp -m multiport --dports $TCP_HIGH_PRIO_PORTS \
-m conntrack --ctstate NEW -j RETURN

#voip,dns,ipsec,openvpn,NTP
$IPTMAN -A QOS_DOWNLOAD -p udp -m multiport --dports $UDP_HIGH_PRIO_PORTS \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_HIGH_PRIO_MARK

$IPTMAN -A QOS_DOWNLOAD -p udp -m multiport --dports $UDP_HIGH_PRIO_PORTS \
-m conntrack --ctstate NEW -j RETURN

#bulk traffic
$IPTMAN -A QOS_DOWNLOAD -p tcp -m multiport --dports $TCP_BULK_PORTS \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_BULK_MARK

$IPTMAN -A QOS_DOWNLOAD -p tcp -m multiport --dports $TCP_BULK_PORTS \
-m conntrack --ctstate NEW -j RETURN

$IPTMAN -A QOS_DOWNLOAD -p udp -m multiport --dports $UDP_BULK_PORTS \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_BULK_MARK

$IPTMAN -A QOS_DOWNLOAD -p udp -m multiport --dports $UDP_BULK_PORTS \
-m conntrack --ctstate NEW -j RETURN

#low prio traffic
$IPTMAN -A QOS_DOWNLOAD -p tcp -m multiport --dports $TCP_LOW_PRIO_PORTS \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK

$IPTMAN -A QOS_DOWNLOAD -p tcp -m multiport --dports $TCP_LOW_PRIO_PORTS \
-m conntrack --ctstate NEW -j RETURN

$IPTMAN -A QOS_DOWNLOAD -p udp -m multiport --dports $UDP_LOW_PRIO_PORTS \
-m conntrack --ctstate NEW -j CONNMARK --set-mark $DOWN_LOW_PRIO_MARK

$IPTMAN -A QOS_DOWNLOAD -p udp -m multiport --dports $UDP_LOW_PRIO_PORTS \
-m conntrack --ctstate NEW -j RETURN


#In this way i should not need to mark connection for upload,and the mark for download traffic shuold be maintained
$IPTMAN -A QOS_UPLOAD -m mark --mark $DOWN_HIGH_PRIO_MARK -j CLASSIFY --set-class 1:$UP_HIGH_PRIO_MARK
$IPTMAN -A QOS_UPLOAD -m mark --mark $DOWN_HIGH_PRIO_MARK -j RETURN
$IPTMAN -A QOS_UPLOAD -m mark --mark $DOWN_LOW_PRIO_MARK -j CLASSIFY --set-class 1:$UP_LOW_PRIO_MARK
$IPTMAN -A QOS_UPLOAD -m mark --mark $DOWN_LOW_PRIO_MARK -j RETURN
$IPTMAN -A QOS_UPLOAD -m mark --mark $DOWN_BULK_MARK -j CLASSIFY --set-class 1:$UP_BULK_MARK
$IPTMAN -A QOS_UPLOAD -m mark --mark $DOWN_BULK_MARK -j RETURN

# #save mark of the previously marked connections
$IPTMAN -A SAVE-MARK -m conntrack --ctstate NEW -j CONNMARK --save-mark
}

function add_qos_devs_and_classes(){
#######################DOWNLOAD#############################################
if [ $BULK_DEFAULT == "on" ]
  then
    #Defult class is bulk traffic class
    tc qdisc add dev $IFB root handle 1: htb default $DOWN_BULK_MARK
  else
    tc qdisc add dev $IFB root handle 1: htb
fi

#set global download value
tc class add dev $IFB parent 1: classid 1:1 htb rate $WAN_DOWNLOAD burst $BURST

#high priority class
tc class add dev $IFB parent 1:1 classid 1:$DOWN_HIGH_PRIO_MARK htb rate $HIGH_PRIO_DOWN_GUARANTEED  \
ceil $HIGH_PRIO_DOWN_MAX quantum $QUANTUM burst $BURST prio 0

#low priority class
tc class add dev $IFB parent 1:1 classid 1:$DOWN_LOW_PRIO_MARK htb rate $LOW_PRIO_DOWN_GUARANTEED \
ceil $LOW_PRIO_DOWN_MAX quantum $QUANTUM burst $BURST prio 7

#bulk traffic class
tc class add dev $IFB parent 1:1 classid 1:$DOWN_BULK_MARK htb rate $DOWNLOAD_GUARANTEED_DEFAULT \
ceil $DOWNLOAD_MAX_DEFAULT quantum $QUANTUM burst $BURST prio 5

#use class [high prio]
tc filter add dev $IFB parent 1:0 protocol ip handle $DOWN_HIGH_PRIO_MARK fw flowid 1:$DOWN_HIGH_PRIO_MARK

#use class [low prio]
tc filter add dev $IFB parent 1:0 protocol ip handle $DOWN_LOW_PRIO_MARK fw flowid 1:$DOWN_LOW_PRIO_MARK

#use class [bulk traffic]
tc filter add dev $IFB parent 1:0 protocol ip handle $DOWN_BULK_MARK fw flowid 1:$DOWN_BULK_MARK


### if [ $ENABLE_L7 == "on" ]
###   then
###     #use class [high prio]
###     tc filter add dev $IFB parent 1:0 protocol ip handle $APP_HIGH_PRIO_MARK fw flowid 1:$DOWN_HIGH_PRIO_MARK
###     #use class [low prio]
###     tc filter add dev $IFB parent 1:0 protocol ip handle $APP_LOW_PRIO_MARK fw flowid 1:$DOWN_LOW_PRIO_MARK
###     #use class [bulk traffic]
###     tc filter add dev $IFB parent 1:0 protocol ip handle $APP_BULK_MARK fw flowid 1:$DOWN_BULK_MARK
### fi

# Tell which algorithm the classes use
tc qdisc add dev $IFB parent 1:$DOWN_HIGH_PRIO_MARK sfq perturb 10
tc qdisc add dev $IFB parent 1:$DOWN_LOW_PRIO_MARK sfq perturb 10
tc qdisc add dev $IFB parent 1:$DOWN_BULK_MARK sfq perturb 10

#redirect everything to ifb interface,needed for ingress (traffic coming from WAN)
tc qdisc add dev $WAN handle ffff: ingress
tc filter add dev $WAN parent ffff: protocol ip u32 match u32 0 0 action \
connmark action mirred egress redirect dev $IFB

#######################UPLOAD################################################
if [ $BULK_DEFAULT == "on" ]
  then
    #default class is bulk traffic class
    tc qdisc add dev $WAN root handle 1:0 htb default $UP_BULK_MARK
  else
    tc qdisc add dev $WAN root handle 1:0 htb
fi

#set the global upload value
tc class add dev $WAN parent 1: classid 1:1 htb rate $WAN_UPLOAD burst $BURST

#high priority class
tc class add dev $WAN parent 1:1 classid 1:$UP_HIGH_PRIO_MARK htb rate $HIGH_PRIO_UP_GUARANTEED \
ceil $HIGH_PRIO_UP_MAX quantum $QUANTUM burst $BURST prio 0

#low priority class
tc class add dev $WAN parent 1:1 classid 1:$UP_LOW_PRIO_MARK htb rate $LOW_PRIO_UP_GUARANTEED \
ceil $LOW_PRIO_UP_MAX quantum $QUANTUM burst $BURST prio 7

#bulk traffic class
tc class add dev $WAN parent 1:1 classid 1:$UP_BULK_MARK htb rate $UPLOAD_GUARANTEED_DEFAULT \
ceil $UPLOAD_MAX_DEFAULT quantum $QUANTUM burst $BURST prio 5

#Tell which algorithm the classes use
tc qdisc add dev $WAN parent 1:$UP_HIGH_PRIO_MARK sfq perturb 10
tc qdisc add dev $WAN parent 1:$UP_LOW_PRIO_MARK sfq perturb 10
tc qdisc add dev $WAN parent 1:$UP_BULK_MARK sfq perturb 10
}

function del_qos_dev_and_classes(){
#remove tc devices
tc qdisc del dev $WAN ingress
tc qdisc del dev $WAN root
tc qdisc del dev $IFB root
}

function del_iptables_rules(){
#flush iptables rules
$IPTMAN -F SAVE-MARK
$IPTMAN -D POSTROUTING -m mark ! --mark 0 -j SAVE-MARK
$IPTMAN -X SAVE-MARK
$IPTMAN -F RESTORE-MARK
$IPTMAN -D PREROUTING -m connmark ! --mark 0 -j RESTORE-MARK
$IPTMAN -X RESTORE-MARK
if [ $ENABLE_SLOWDOWN == "on" ]
  then
    $IPTMAN -F QOS_SLOWDOWN
    $IPTMAN -D FORWARD -j QOS_SLOWDOWN
    $IPTMAN -X QOS_SLOWDOWN
fi
$IPTMAN -F QOS_DOWNLOAD
$IPTMAN -D FORWARD -m mark --mark 0 -o $WAN -j QOS_DOWNLOAD
$IPTMAN -X QOS_DOWNLOAD
$IPTMAN -F QOS_UPLOAD
$IPTMAN -D FORWARD -o $WAN -m mark ! --mark 0 -j QOS_UPLOAD
$IPTMAN -X QOS_UPLOAD
if [ $ENABLE_L7 == "on" ]
  then
    $IPTMAN -F QOS_DPI
    $IPTMAN -D PREROUTING -j QOS_DPI
    $IPTMAN -X QOS_DPI
fi
if [ $ENABLE_NAT == "on" ]
  then
    iptables -t nat -D POSTROUTING -o $WAN -j MASQUERADE
fi
}

function start(){
add_system_configurations
add_qos_devs_and_classes
add_iptables_rules
}

function stop(){
del_qos_dev_and_classes
del_iptables_rules
del_system_configurations
}

function show(){
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
