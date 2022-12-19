#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

from utils.pretty_print import table
from utils.libs import tools
from utils.run import command


class qos_class:
        def __init__(self):
            self.class_settings = tools().global_settings['classes_conf']
            self.base_mark = 85
            self.prio_map = {'high' : 0 , 'low' : 7 , 'bulk' : 5 }

        def list_classes(self):
            class_conf = tools().load_json(self.class_settings)
            class_list = []
            for class_name in class_conf.keys():
                attr_list = []
                for dev_attr,value in class_conf[class_name].items():
                    if dev_attr == 'priority':
                        attr_list.append(list(class_conf[class_name].keys())[list(class_conf[class_name].values()).index(value)])
                    else:
                        attr_list.append(value)
                attr_list.append(class_name)
                remark,class_mark,upload_min,upload_max,download_min,download_max,device,prio,burst,quantum,ifb,class_name = attr_list
                class_list.append([remark,upload_min,upload_max,download_min,download_max,device,prio,class_name])
            table(['Remark','Guaranteed upload','Max upload','Guaranteed download','Max download',
                   'Interface','Priority','Class name'],class_list).print_table()


        def add_class(self, name, attach_to, up_min, up_max, down_min, down_max, prio, remark):
            if not tools().item_exists(self.class_settings,name):
               qos_class = {}
               qos_class[name] = {}
            else:
                return False,'QOS_CLASS_ALREADY_EXISTS'
            if remark:
                qos_class[name]['remark'] = remark
            class_count = len(tools().load_json(self.class_settings))
            qos_class[name]['mark'] = self.base_mark + class_count
            if up_min.endswith('kb') or up_min.endswith('kB') or up_min.endswith('mb'):
                qos_class[name]['up_min'] = up_min
            else:
                return False,'INVALID_UPLOAD_VAL'
            if up_max.endswith('kb') or up_max.endswith('kB') or up_max.endswith('mb'):
                qos_class[name]['up_max'] = up_max
            else:
                return False,'INVALID_UPLOAD_VAL'
            if down_min.endswith('kb') or down_min.endswith('kB') or down_min.endswith('mb'):
                qos_class[name]['down_min'] = down_min
            else:
                return False,'INVALID_DOWNLOAD_VAL'
            if down_max.endswith('kb') or down_max.endswith('kB') or down_max.endswith('mb'):
                qos_class[name]['down_max'] = down_max
            else:
                return False,'INVALID_DOWNLOAD_VAL'
            qos_class[name]['device'] = attach_to
            qos_class[name]['priority'] = self.prio_map[prio]
            qos_class[name]['burst'] = '15k'
            qos_class[name]['quantum'] = '1514'
            if tools().item_exists(tools().global_settings['devices_conf'],attach_to):
                dev_conf = tools().load_json(tools().global_settings['devices_conf'])
                qos_class[name]['ifb'] = dev_conf[attach_to]['ifb_device']
            else:
                return False,'QOS_DEV_NOT_EXISTS'
            tools().add_item(self.class_settings,qos_class)
            #download
            command('tc class add dev {} parent 1:1 classid 1:{} htb rate {} \
                     ceil {} quantum {} burst {} prio {}'.format(
                     qos_class[name]['ifb'] , qos_class[name]['mark'] ,down_min , down_max,
                     qos_class[name]['quantum'], qos_class[name]['burst'], prio)).run()
            command('tc filter add dev {} parent 1:0 protocol ip handle {} fw flowid  1:{}'.format(
                     qos_class[name]['ifb'], qos_class[name]['mark'], qos_class[name]['mark'])).run()
            command('tc qdisc add dev {} parent 1:{} sfq perturb 10'.format(
                    qos_class[name]['ifb'] , qos_class[name]['mark'])).run()
            #upload
            command('tc class add dev {} parent 1:1 classid 1:{} htb rate {} \
                     ceil {} quantum {} burst {} prio {}'.format(
                     attach_to , qos_class[name]['mark'] ,up_min , up_max,
                     qos_class[name]['quantum'], qos_class[name]['burst'], prio)).run()
            command('tc qdisc add dev {} parent 1:{} sfq perturb 10'.format(
                    attach_to , qos_class[name]['mark'])).run()
            return True,'OK'

        def del_qos_class(self,name):
            if tools().item_exists(self.class_settings,name):
                class_config = tools().get_item(self.class_settings,name)
                command('tc class del dev {} classid 1:{}'.format(class_config['ifb'],class_config['mark'])).run()
                command('tc class del dev {} classid 1:{}'.format(class_config['device'],class_config['mark'])).run()
                tools().del_item(self.class_settings,name)
                return True,'OK'
            else:
                return False,'NO_QOS_DEV'
