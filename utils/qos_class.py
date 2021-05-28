#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

from utils.pretty_print import table
from utils.libs import tools

class qos_class:
        def __init__(self):
            self.class_settings = tools().global_settings['classes_conf']
            self.base_mark = 85
            #pass

        def list_classes(self):
            class_conf = tools().load_json(self.class_settings)
            class_list = []
            for class_name in class_conf.keys():
                attr_list = []
                for dev_attr,value in class_conf[class_name].items():
                    attr_list.append(value)
                attr_list.append(class_name)
                remark,class_mark,upload_min,upload_max,download_min,download_max,device,prio,class_name = attr_list
                class_list.append([remark,upload_min,upload_max,download_min,download_max,device,prio,class_name])
            table(['Remark','Guaranteed upload','Max upload','Guaranteed download','Max download',
                   'Interface','Priority','Class name'],class_list).print_table()

        def add_class(self,**kwargs):
            #calculate mark
            classes = tools().load_json(self.class_settings)
            class_count = len(classes)
            class_mark = self.base_mark + class_count
            #print(class_mark)
            #dev[dev_name]['ifb_device'] = ifb
