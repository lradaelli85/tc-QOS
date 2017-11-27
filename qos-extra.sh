#!/bin/bash
#could be yes or no.If yes DropBox and WindowsUpdate will have low prio
. qos_devices.conf
. qos_classes.conf

LOW_PRIO="yes"

cp ipset.conf /etc/dnsmasq.d/
ipset create WindowsUpdate hash:ip
ipset create DropBox hash:ip
iptables -t mangle -N QOS_APP
iptables -t mangle -I FORWARD -j QOS_APP

if [ $LOW_PRIO == "yes" ]
then
iptables -t mangle -A QOS_APP -m comment --comment "winupdate" -m mark --mark 0 -o $WAN -m set --match-set WindowsUpdate dst \
-m conntrack --ctstate NEW -j MARK --set-mark 11
iptables -t mangle -A QOS_APP -o $WAN -m set --match-set WindowsUpdate dst -m conntrack --ctstate NEW -j RETURN
iptables -t mangle -A QOS_APP -m comment --comment "dropbox" -m mark --mark 0 -o $WAN -m set --match-set DropBox dst \
-m conntrack --ctstate NEW -j MARK --set-mark 11
iptables -t mangle -A QOS_APP -o $WAN -m set --match-set DropBox dst -m conntrack --ctstate NEW -j RETURN
else
iptables -t mangle -A QOS_APP -m comment --comment "winupdate" -m mark --mark 0 -o $WAN -m set --match-set WindowsUpdate dst \
-m conntrack --ctstate NEW -j MARK --set-mark 10
iptables -t mangle -A QOS_APP -o $WAN -m set --match-set WindowsUpdate dst -m conntrack --ctstate NEW -j RETURN
iptables -t mangle -A QOS_APP -m comment --comment "dropbox" -m mark --mark 0 -o $WAN -m set --match-set DropBox dst \
-m conntrack --ctstate NEW -j MARK --set-mark 10
iptables -t mangle -A QOS_APP -o $WAN -m set --match-set DropBox dst -m conntrack --ctstate NEW -j RETURN
fi
