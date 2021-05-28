#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

from os import getuid   #, system
from json import load, dump
from sys import exit
from utils.networklib import networklib

class tools:
        def __init__(self):
            self.global_settings = self.load_json('conf.d/global_settings.json')
            #pass


        def am_i_root(self):
            if getuid() != 0:
                return False
            else:
                return True


        def load_json(self,json_file):
            try:
                with open(json_file, 'r') as json_f:
                    data = load(json_f)
            except IOError as e:
                print(e)
                exit(1)
            return data


        def write_json(self,json_file,data):
            try:
                with open(json_file, 'w') as json_f:
                    dump(data, json_f, indent=4)
            except IOError as e:
                print(e)


        def item_exists(self,cfg_file,s_key):
             data = self.load_json(cfg_file)
             if s_key in data.keys():
                 return True
             else:
                 return False


        def get_item(self,cfg_file,s_key):
            data = self.load_json(cfg_file)
            if s_key in data.keys():
                return data[s_key]


        def add_item(self,cfg_file,qos_obj):
            data = self.load_json(cfg_file)
            data.update(qos_obj)
            self.write_json(cfg_file,data)


        def del_item(self,cfg_file,s_key):
            data = self.load_json(cfg_file)
            if s_key in data.keys():
                data.pop(s_key)
                self.write_json(cfg_file,data)


        def nic_exists(self,nic):
            choice = networklib().get_nics()
            if nic in choice:
                return True
            else:
                return False
