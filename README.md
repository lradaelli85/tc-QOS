# QOS with L7 (layer7) support

Linux QoS built with tc and HTB.

# Requirements

- iproute2
- act_mirred and act_connmark kernel support
- nftables

# Features

- Handle Download traffic (i.e traffic coming from WAN)
- Handle Upload traffic (i.e traffic to WAN)
- {optional} Slowdown (set a low priority) those connections that go beyond a fixed amount of traffic (i.e big download)
