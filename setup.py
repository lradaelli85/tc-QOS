#!/usr/bin/python
# -*- coding: utf-8 -*-.

from utils.RunCommand import Command
import qos_dev
qos_table = 'iptables -t mangle'
qos_chains = {'FORWARD': ['QOS_UPLOAD','QOS_DOWNLOAD','QOS_SLOWDOWN'],
              'PREROUTING' : 'RESTORE-MARK','POSTROUTING':'SAVE-MARK'}

def add_qos_chains():
    action = '-N'
    for chain in qos_chains.itervalues():
        if type(chain) is list:
            for c in chain:
                ipt_cmd = ' '.join([qos_table,action,c])
                Command(ipt_cmd).run()
                #print ipt_cmd
        else:
            ipt_cmd = ' '.join([qos_table,action,chain])
            Command(ipt_cmd).run()
            #print ipt_cmd

def jump_to_qos_chains():
    action = '-A'
    for table in qos_chains.iterkeys():
        if type(qos_chains[table]) is list:
            for qos_chain in qos_chains[table]:
                ipt_cmd = ' '.join([qos_table,action,table,'-j',qos_chain])
                Command(ipt_cmd).run()
                #print ipt_cmd
        else:
            ipt_cmd = ' '.join([qos_table,action,table,'-j',qos_chains[table]])
            Command(ipt_cmd).run()
            #print ipt_cmd

def add_qos_mark_rules():
    Command(' '.join([qos_table,'-A RESTORE-MARK -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark'])).run()
    Command(' '.join([qos_table,'-A SAVE-MARK -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark'])).run()

def load_modules():
    Command('modprobe ifb').run()
    Command('modprobe act_mirred').run()


def setup_qos():
    load_modules()
    add_qos_chains()
    jump_to_qos_chains()
    add_qos_mark_rules()
    qos_dev.qos_device("lan","br0","100","100").write_qos_dev_conf()

if __name__ == "__main__":
    setup_qos()
