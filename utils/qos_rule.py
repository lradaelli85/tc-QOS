#!/usr/bin/env python3
# -*- coding: utf-8 -*-.


from utils.libs import tools
from utils.run import command
from utils.pretty_print import table
from os import system

class qos_rule():
    def __init__(self):
        self.rule_settings = tools().global_settings['rules_conf']
        
    def build_ipt_chains(self):
        ipt_cmd='iptables-nft -t MANGLE'
        command('{} -N QOS_UPLOAD'.format(ipt_cmd)).run()
        command('{} -N QOS_DOWNLOAD'.format(ipt_cmd)).run()
        command('{} -N RESTORE-MARK'.format(ipt_cmd)).run()
        command('{} -N SAVE-MARK'.format(ipt_cmd)).run()
        command('{} -A FORWARD -m mark --mark 0 -o $WAN -j QOS_DOWNLOAD'.format(ipt_cmd)).run()
        command('{} -A FORWARD -o $WAN -m mark ! --mark 0 -j QOS_UPLOAD'.format(ipt_cmd)).run()
        command('{} -A PREROUTING -m connmark ! --mark 0 -j RESTORE-MARK'.format(ipt_cmd)).run()
        command('{} -A POSTROUTING -m mark ! --mark 0 -j SAVE-MARK'.format(ipt_cmd)).run()
        command('{} -A RESTORE-MARK -m conntrack ! --ctstate NEW -j CONNMARK --restore-mark'.format(ipt_cmd)).run()
        command('{} -A SAVE-MARK -m conntrack --ctstate NEW -j CONNMARK --save-mark'.format(ipt_cmd)).run()
        
    def add_ipt_rule(self, src, dst, proto, dport, sport, ifin, ifout, classify, remark, direction):
        ipt_cmd='iptables-nft -t MANGLE'
        rule_count = len(tools().load_json(self.rule_settings))
        rule_n=rule_count+1
        qos_rule = {}
        qos_rule[rule_n] = {}
        ipt_str=''
        if not src:
            src='0.0.0.0/0'
        qos_rule[rule_n]['src_ip'] = src
        ipt_str='-s '+src
        if not dst:
            dst='0.0.0.0/0'
        ipt_str=ipt_str+' -d '+dst
        qos_rule[rule_n]['dst_ip'] = dst
        if not proto:
            proto = 'all'
        ipt_str=ipt_str+' -p '+proto
        qos_rule[rule_n]['proto'] = proto
        if proto and proto != 'icmp' and dport:
            qos_rule[rule_n]['dst_port'] = dport
            ipt_str=ipt_str+' -m multiport --dports '+dport
        if proto and proto != 'icmp' and sport:
            qos_rule[rule_n]['src_port'] = sport
            ipt_str=ipt_str+' -m multiport --sports '+sport
        if not ifin:
            ifin = 'any'
        else:
            ipt_str=ipt_str+' -i '+ifin
        qos_rule[rule_n]['if-in'] = ifin
        if not ifout:
            ifout = 'any'
        else:
            ipt_str=ipt_str+' -o '+ifout
        qos_rule[rule_n]['if-out'] = ifout
        if not remark:
            remark = 'rule {}'.format(rule_n)
        ipt_str=ipt_str+' -m comment --comment \"'+remark+'\"'
        qos_rule[rule_n]['remark'] = remark
        if tools().item_exists(tools().global_settings['classes_conf'],classify):
            class_file=tools().global_settings['classes_conf']
            classes=tools().load_json(class_file)
            mark = classes[classify]['mark']
            qos_rule[rule_n]['class'] = classify
        else:
            print('error')
        if direction == 'upload':
            qos_rule[rule_n]['chain'] = 'QOS_UPLOAD'
            connmark_args=' -m mark --mark ' + str(mark) +' -j CLASSIFY --set-class 1:'+str(mark)
        else:
            qos_rule[rule_n]['chain'] = 'QOS_DOWNLOAD'
            connmark_args=' -m conntrack --ctstate NEW -j CONNMARK --set-mark '+str(mark)
        ipt_str=ipt_str+' -I '+qos_rule[rule_n]['chain']+' '+str(rule_n)+connmark_args    
        tools().add_item(self.rule_settings,qos_rule)
        command('{} {}'.format(ipt_cmd,ipt_str))
        
        
    #def del_ipt_rule(self):
        
    def list_ipt_rules(self):
        ipt_cmd='iptables-nft -t MANGLE'
        command('{} -nvL QOS_UPLOAD'.format(ipt_cmd)).run()
        command('{} -nvL QOS_DOWNLOAD'.format(ipt_cmd)).run()

        
