# tc-QOS

Linux Qos built with tc and HTB.

In order to run correctly this script you need the latest kernel and iproute2 package.
Support for act_mirred and act_connmark is required.
This script has been tested and built on a standard debian 9.
If you want to be able to detect applications you need to compile nDPI.
https://github.com/ntop/nDPI
On each class there are values that define the guaranteed bandwith , the bandwith limit (ceil) and the priority.
The logic is that Bulk should be used for traffic that does not need to be classified.
This script set as bulk traffic all the traffic that is not classified as High/Low priority.
High/Low priority classes are self-explained.
When a class requests less than the amount assigned, the remaining (excess) bandwidth is distributed to other classes which request service.
Classes with higher priority are offered excess bandwidth first. But rules about guaranteed rate (can't go below this value ) and ceil (maximum bandwith usable by a class) are still met.
To learn more about HTB take a look to the below links (thanks to the Author)

http://luxik.cdi.cz/~devik/qos/htb/manual/userg.htm

http://luxik.cdi.cz/~devik/qos/htb/manual/theory.htm

Confguration and usage

Edit the qos.cfg file and set the variables accordingly.
For each variable there is a short explanation

This script has been designed to use three different kind classes:

-Bulk traffic
-Low priority traffic
-High priority traffic

There are also some rules that will slow down the connection if a big download is running (value SLOWDOWN_QUOTA in qos.cfg file).
This script automatically enable forwarding and SOURCE NAT.
*NO FILTER POLICY HAVE BEEN ADDED*
The qos_class_mapping.cfg file contains a mapping between the class ID and the class Description.
If you will change the classes marks values in the qos.cfg remember to update the qos_class_mapping.cfg accordingly.
