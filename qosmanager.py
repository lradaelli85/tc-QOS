#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

import argparse
from sys import exit,argv
from utils.qos_device import qos_device
from utils.qos_class import qos_class
from utils.error_checker import dev_errors

def add_qos_dev(args):
    print('Adding QoS device on: {}....'.format(args.name))
    result = qos_device().add_device(args.name,args.upload,args.download)
    if not result[0]:
        print(dev_errors(result[1]))
    else:
        print('Device added')

def del_qos_dev(args):
    print('Deleting QoS device from: {}....'.format(args.name))
    result=qos_device().del_device(args.name)
    if not result[0]:
        print(dev_errors(result[1]))
    else:
        print('Device removed')

def list_qos_dev(args):
    qos_device().list_devices()

def add_qos_class(args):
    #print('Add QoS class')
    qos_class().add_class()
    #print(args)

def del_qos_class(args):
    print('Del QoS class')
    #print(args)

def list_qos_class(args):
    qos_class().list_classes()

def add_qos_rule(args):
    print('Add QoS rule')

def del_qos_rule(args):
    print('del QoS rule')

def list_qos_rules(args):
    print('List QoS rule')

def CheckArgs():
    qos_classes_type = ['upload','download','slowdown']
    protocols = ['tcp','udp','icmp']
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers()
    parser_add = subparsers.add_parser('add')
    parser_add_object = parser_add.add_subparsers()
    parser_del = subparsers.add_parser('delete')
    parser_del_object = parser_del.add_subparsers()
    parser_list = subparsers.add_parser('list')
    parser_list_object = parser_list.add_subparsers()
    ##############Device###############
    #Add
    add_dev = parser_add_object.add_parser('device')
    add_dev.add_argument('--name',required=True, help='Network interface Name',metavar='interface')
    add_dev.add_argument('--upload',required=True, help='Upload bandwith in kb,KB,mb')
    add_dev.add_argument('--download',required=True, help='Download bandwith in kb,KB,mb')
    add_dev.set_defaults(func=add_qos_dev)
    #Delete
    del_dev = parser_del_object.add_parser('device')
    del_dev.add_argument('--name',required=True, help='Network interface Name',metavar='interface')
    del_dev.set_defaults(func=del_qos_dev)
    #List
    list_dev = parser_list_object.add_parser('devices')
    list_dev.set_defaults(func=list_qos_dev)
    #############Class##################
    #Add
    add_class = parser_add_object.add_parser('class')
    add_class.add_argument('--kind',required=True,choices=qos_classes_type ,metavar='Class_type',
                            help=','.join(qos_classes_type))
    add_class.add_argument('--name',required=True, help='QoS class name',metavar='Class_name')
    add_class.add_argument('--attach',required=True, help='Attach class to network interface',
                            metavar='interface')
    add_class.add_argument('--guaranteed',required=True, help='Class guarateed bandwidth',
                            metavar='amount')
    add_class.add_argument('--max',required=True, help='Class maximum bandwith',
                            metavar='amount')
    add_class.set_defaults(func=add_qos_class)
    #Delete
    del_class = parser_del_object.add_parser('class')
    del_class.add_argument('--name',required=True, help='QoS class name',metavar='Class_name')
    del_class.set_defaults(func=del_qos_class)
    #List
    list_class = parser_list_object.add_parser('classes')
    list_class.set_defaults(func=list_qos_class)
    #############Rule###################
    #Add
    add_rule = parser_add_object.add_parser('rule')
    add_rule.add_argument('--src', help='Source IP/Network')
    add_rule.add_argument('--dst', help='Destination IP/Network')
    add_rule.add_argument('--proto', choices=protocols)
    add_rule.add_argument('--dport', help='Port number')
    add_rule.add_argument('--classify', help='QoS Class name')
    #Delete
    #List
    list_rule = parser_list_object.add_parser('rules')
    list_rule.set_defaults(func=list_qos_rules)
    ####################################
    args = parser.parse_args()
    #try:
    args.func(args)
    #except AttributeError:
    #    print('missing parameter,run {} {} -h'.format(argv[0],' '.join(argv[1:])))


if __name__ == "__main__":
    CheckArgs()
