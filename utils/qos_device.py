#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

from utils.libs import tools
from utils.run import command
from utils.pretty_print import table
from os import system

class qos_device:
    def __init__(self):
        self.dev_settings = tools().global_settings['devices_conf']

    def list_devices(self):
        dev_conf = tools().load_json(self.dev_settings)
        dev_list = []
        for dev_name in dev_conf.keys():
            attr_list = []
            for dev_attr,value in dev_conf[dev_name].items():
                attr_list.append(value)
            attr_list.append(dev_name)
            upload,download,ifb,dev_name = attr_list
            dev_list.append([upload,download,dev_name])
        table(['Upload','Download','Interface'],dev_list).print_table()

    def del_device(self,dev_name):
        if tools().item_exists(self.dev_settings,dev_name):
            command('tc qdisc del dev {} ingress'.format(dev_name)).run()
            command('tc qdisc del dev {} root'.format(dev_name)).run()
            qos_dict = tools().get_item(self.dev_settings,dev_name)
            command('tc qdisc del dev {} root'.format(qos_dict['ifb_device']))
            command('ip link del dev {}'.format(qos_dict['ifb_device']))
            tools().del_item(self.dev_settings,dev_name)
            return True,'OK'
        else:
            return False,'NO_QOS_DEV'

    def add_device(self,dev_name,upload,download):
            if tools().nic_exists(dev_name):
                if not tools().item_exists(self.dev_settings,dev_name):
                    dev = {}
                    dev[dev_name] = {}
                else:
                    return False,'QOS_DEV_ALREADY_EXISTS'
            else:
                return False,'DEV_NOT_EXISTS'
            if upload.endswith('kb') or upload.endswith('kB') or upload.endswith('mb'):
                dev[dev_name]['upload'] = upload
            else:
                return False,'INVALID_UPLOAD_VAL'
            if download.endswith('kb') or download.endswith('kB') or download.endswith('mb'):
                dev[dev_name]['download'] = download
            else:
                return False,'INVALID_DOWNLOAD_VAL'
            dev_count = tools().load_json(self.dev_settings)
            str_dev_count = str(len(dev_count))
            ifb = 'ifb{}'.format(str(len(dev_count)))
            dev[dev_name]['ifb_device'] = ifb
            tools().add_item(self.dev_settings,dev)
            if len(dev_count) == 0:
                command('modprobe ifb numifbs=1').run()
                command('modprobe act_mirred').run()
            else:
                command('ip link add {} type ifb'.format(ifb)).run()
            command('ip link set dev {} up'.format(ifb)).run()
            command('tc qdisc add dev {} root handle {}: htb'.format(ifb,str_dev_count))
            command('tc qdisc add dev {} handle ffff: ingress'.format(dev_name)).run()
            command('tc filter add dev {} parent ffff: protocol ip u32 match u32 0 0 action \
                    connmark action mirred egress redirect dev {}'.format(dev_name,ifb)).run()
            command('tc qdisc add dev {} root handle {}:0 htb'.format(dev_name,str_dev_count)).run()
            return True,'OK'
