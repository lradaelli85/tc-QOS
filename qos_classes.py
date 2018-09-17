#!/usr/bin/python
# -*- coding: utf-8 -*-.
import json
import sys

class qos_class:
    def __init__(self,name,phys_dev,download,upload):
        self.qos_class =    {   'name' : name,
                                'qos_dev' : phys_dev,
                                'download' : download,
                                'upload' : upload
                            }
