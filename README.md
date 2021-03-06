# QOS with L7 (layer7) support

Linux QoS built with tc and HTB.

# Requirements

- iproute2
- act_mirred and act_connmark kernel support
- {optional} [nDPI](https://github.com/betolj/ndpi-netfilter) for L7 classification

# Features

- Handle Download traffic (i.e traffic coming from WAN)
- Handle Upload traffic (i.e traffic to WAN)
- {optional} Classify L7 traffic
- {optional} Slowdown (set a low priority) those connections that go beyond a fixed amount of traffic (i.e big download)

# Introduction

The aim of this script is to guarantee (bandwidth can't go below this value) , limit (maximum bandwidth usable) and prioritize certain kind of traffic.

It is designed to share the same internet link between different sources using three different kind of classes.

*download/upload/guaranteed/limit/applications values present in qos.cfg have been used only as reference*

#### - Bulk traffic

This class has a low guaranteed bandwidth,medium priority and it can use all the available up/down bandwidth
All low-ports (0-1023, except some) are classified as bulk traffic.
Modify the qos.cfg files if this is not what you want.

#### - Low priority traffic

Traffic that you want to limit (small amount of available bandwidth) with a low priority.
All high-ports (1024-65535, except some) are classified as low priority traffic.
YOUTUBE,TWITTER,FACEBOOK,DROPBOX,SPOTIFY applications if L7 is enabled.
Modify the qos.cfg files if this is not what you want.

#### - High priority traffic

Traffic that you want to prioritize.
This class has an high guaranteed bandwidth, high priority and it can use all the available up/down bandwidth
HTTP(s),SSH,DNS,VOIP,IPsec,OpenVPN are classified as high priority traffic.
STUN,RTP,H323,HANGOUT,SKYPE,OFFICE 365 applications if L7 is enabled.
Modify the qos.cfg files if this is not what you want.

When a class requests less than the amount assigned, the remaining (excess) bandwidth is distributed to other classes which request service.

Classes with higher priority are offered excess bandwidth first. But rules about guaranteed rate (can't go below this value ) and ceil (maximum bandwidth usable by a class) are still met.

This script automatically enables forwarding and source NAT.

If this is not what you want set the `ENABLE_NAT` to `off` in qos.cfg file.

To learn more about HTB take a look to the below links (thanks to the Author)

http://luxik.cdi.cz/~devik/qos/htb/manual/userg.htm

http://luxik.cdi.cz/~devik/qos/htb/manual/theory.htm

# Configuration and usage

Edit the qos.cfg file and set the variables accordingly.For each variable there is a short explanation.

- slowdown feature is enabled by default, to disable it ,set the `ENABLE_SLOWDOWN` value to `off`.
- L7 classification is enabled by default, to disable it ,set the `ENABLE_L7` value to `off`.

To check all the available applications run `iptables -m ndpi --help`

Usually you don't need to change the `iptables mark` parameters ,do it only if you know what are you doing.

**NO FILTER POLICIES ARE PRESENT**

The qos_class_mapping.cfg file contains a mapping (human readable) between the class ID and the class description.
If you will change the `iptables mark` values in the qos.cfg remember to update the qos_class_mapping.cfg accordingly.

To run the script issue the below command

`./QoS.sh start`

If you want to have some statistics about traffic QoS classes run

`./QoS.sh stats`

Below an example of the output

```
## Download QoS classes ##
+---(1:1) htb rate 1Gbit ceil 1Gbit burst 15125b cburst 1375b
     |    Sent 1582 bytes 10 pkt (dropped 0, overlimits 0 requeues 0)
     |    rate 0bit 0pps backlog 0b 0p requeues 0
     |
     +---(High-Priority-Download#1:11) htb prio 0 rate 1Mbit ceil 4Mbit burst 15Kb cburst 1600b
     |                                 Sent 0 bytes 0 pkt (dropped 0, overlimits 0 requeues 0)
     |                                 rate 0bit 0pps backlog 0b 0p requeues 0
     |     
     +---(Low-Priority-Download#1:10) htb prio 7 rate 512Kbit ceil 512Kbit burst 15Kb cburst 1600b
     |                                Sent 0 bytes 0 pkt (dropped 0, overlimits 0 requeues 0)
     |                                rate 0bit 0pps backlog 0b 0p requeues 0
     |     
     +---(Bulk-Download-Traffic#1:12) htb prio 5 rate 256Kbit ceil 1Mbit burst 15Kb cburst 1600b
                                      Sent 1582 bytes 10 pkt (dropped 0, overlimits 0 requeues 0)
                                      rate 0bit 0pps backlog 0b 0p requeues 0



## Upload QoS classes ##
+---(1:1) htb rate 1Gbit ceil 1Gbit burst 15125b cburst 1375b
     |    Sent 1249 bytes 16 pkt (dropped 0, overlimits 0 requeues 0)
     |    rate 0bit 0pps backlog 0b 0p requeues 0
     |
     +---(Bulk-Upload-traffic#1:22) htb prio 5 rate 64Kbit ceil 2Mbit burst 15Kb cburst 1600b
     |                              Sent 1249 bytes 16 pkt (dropped 0, overlimits 0 requeues 0)
     |                              rate 0bit 0pps backlog 0b 0p requeues 0
     |     
     +---(Low-Priority-Upload#1:20) htb prio 7 rate 512Kbit ceil 1Mbit burst 15Kb cburst 1600b
     |                              Sent 0 bytes 0 pkt (dropped 0, overlimits 0 requeues 0)
     |                              rate 0bit 0pps backlog 0b 0p requeues 0
     |     
     +---(High-Priority-Upload#1:21) htb prio 0 rate 512Kbit ceil 2Mbit burst 15Kb cburst 1600b
                                     Sent 0 bytes 0 pkt (dropped 0, overlimits 0 requeues 0)
                                     rate 0bit 0pps backlog 0b 0p requeues 0
```

All low ports traffic (0-1023) are classified as bulk traffic explicitly (except some tcp/udp ports.See Introduction).
Actually,you can also classify as bulk all the not-classified traffic (i.e no high/low prio traffic) setting to on
the value of `BULK_DEFAULT` in qos.cfg file.

# NOTES
If set to on the value of `BULK_DEFAULT` in qos.cfg file, the locally-generated-traffic will be classified as bulk by default.
I personally suggest to keep it off to have a full control.
