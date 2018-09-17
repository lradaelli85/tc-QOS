#!/usr/bin/python
# -*- coding: utf-8 -*-.
import json
import sys
class qos_device:
    def __init__(self,name,phys_dev,download,upload):
        self.qos_dev =  {   'name' : name,
                            'qos_dev' : phys_dev,
                            'qos_dev_download' : download,
                            'qos_dev_upload' : upload
                        }

    def write_qos_dev_conf(self):
            exists = False
            qos_data = json.dumps(self.qos_dev)
            json_data = json.loads(qos_data)
            try:
                with open('qos_devices.json', 'r') as f:
                    j_file = json.load(f)
                    if json_data['qos_dev'] in j_file[str(len(j_file))].values():
                        print 'error,device {} already used'.format(json_data['qos_dev'])
                        sys.exit(1)
                    else:
                        j_file[len(j_file)+1] = json_data
                exists = True
            except :
                pass
            with open('qos_devices.json', 'w') as f:
                if not exists:
                    json_dat = {}
                    json_dat['1'] = json_data
                    json.dump(json_dat, f)
                else:
                    json.dump(j_file, f)
