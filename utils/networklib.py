#!/usr/bin/python
# -*- coding: utf-8 -*-.

import socket
import sys
from os import listdir
import socket, struct, fcntl
from math import pow

class networklib():
    def __init__(self):
        pass

    def is_valid_ipv4(self,address):
        if len(address.split('.')) == 4:
            try:
                socket.inet_aton(address)
                return True
            except socket.error:
                return False


    def get_cidr_from_bin(self,mask):
        return self.ip_to_bin(mask).count('1')


    def is_valid_cidr(self,address):
        if not address.split('/')[1].isdigit():
            return False
        try:
            cidrString = int(address.split('/')[1])
        except:
            return False
        if int(cidrString) < 0 or int(cidrString) > 31:
            return False
        return True


    def get_cidr_address(self,address):
        try:
            (addrString, cidrString) = address.split('/')
        except:
            return False
        addr = addrString.split('.')
        cidr = int(cidrString)
        mask = [0, 0, 0, 0]
        for i in range(cidr):
            mask[i/8] = mask[i/8] + (1 << (7 - i % 8))
        net = []
        for i in range(4):
            net.append(int(addr[i]) & mask[i])
        return ''.join([".".join(map(str, net)),'/',cidrString])


    def is_valid_port(self,port):
        if not port.isdigit():
           return False
        try:
            port = int(port)
        except ValueError:
            return False
        if port >= 0 and port <= 65535:
            return True
        else:
            return False


    def network_object_type(self,address):
        obj_type = { 'is_ip_address' : False , 'is_network_address': False , 'is_ip_range' : False }
        if '-' in address:
            if len(address.split('-')) == 2:
                obj_type.update({'is_ip_range' : True})
            else:
                return False
        elif '/' in address:
            if len(address.split('/')) == 2:
                obj_type.update({'is_network_address' : True})
            else:
                return False
        else:
            if len(address.split('.')) == 4:
                obj_type.update({'is_ip_address' : True})
            else:
                return False
        return obj_type


    def ip_to_bin(self,address):
        octet_list = address.split(".")
        octet_list_bin = [format(int(i), '08b') for i in octet_list]
        binary = ("").join(octet_list_bin)
        return binary


    def get_mask(self,address_cidr):
        if self.is_valid_cidr(address_cidr):
            cidr = int(address_cidr.split("/")[1])
            mask_str = [0, 0, 0, 0]
            for i in range(cidr):
                mask_str[i/8] = mask_str[i/8] + (1 << (7 - i % 8))
            mask_bin = self.ip_to_bin(".".join(map(str, mask_str)))
            return mask_bin , mask_str


    def get_network_addr(self,address_cidr):
        addr = address_cidr.split("/")[0].split(".")
        mask = self.get_mask(address_cidr)
        if address_cidr.split("/")[1] == "32":
            return False
        net_addr = []
        for i in range(4):
            net_addr.append(int(addr[i]) & int(mask[1][i]))
        return net_addr


    def get_broadcast_addr(self,address_cidr):
        broadcast = self.get_network_addr(address_cidr)
        broadcast_range = 32 - int(address_cidr.split("/")[1])
        for i in range(broadcast_range):
            broadcast[3 - i/8] = broadcast[3 - i/8] + (1 << (i % 8))
        return broadcast


    # def is_in_net(self,ip_address,net_address):
    #     [net_addr, net_size] = net_address.split("/")
    #     if net_size == "32":
    #         return False
    #     addr = net_addr.split('.')
    #     ip_binary = self.ip_to_bin(net_addr)
    #     ip_bin = self.ip_to_bin(ip_address)
    #     mask = self.get_mask(net_address)
    #     for i in range(len(mask[0].strip('0'))):
    #         if int(ip_binary[i]) * int(mask[0][i]) <> int(ip_bin[i]):
    #             return False
    #             break
    #     return True


    def is_usable_ip(self,ip_address,net_address):
        if self.is_in_net(ip_address,net_address):
            broadcast = self.get_broadcast_addr(net_address)
            net_addr = self.get_network_addr(net_address)
            if ( ip_address != ".".join(map(str, net_addr)) and
                 ip_address != ".".join(map(str, broadcast))
                ):
                return True
            else:
                return False


    def usable_ip_range(self,address_cidr):
        net_addr = self.get_network_addr(address_cidr)
        net_addr[3] = net_addr[3]+1
        broad_addr = self.get_broadcast_addr(address_cidr)
        broad_addr[3] = broad_addr[3]-1
        net_size = address_cidr.split("/")[1]
        if int(net_size) >= 0 and int(net_size) < 31:
            usable_ips = {"first_usable_ip":net_addr, "last_usable_ip":broad_addr}
#            print ".".join(map(str, usable_ips["first_usable_ip"])),"-",".".join(map(str, usable_ips["last_usable_ip"]))
            return usable_ips


    def number_of_usable_ips(self,address_cidr):
        cidr = int(address_cidr.split("/")[1])
        return str(pow(2,32-cidr)-2).split('.')[0]


    def get_nics(self):
        try:
            dir_obj = listdir('/sys/class/net/')
        except OSError as err:
            return False,err
        return dir_obj


    def get_nic_ip(self,interface):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sockfd = sock.fileno()
        SIOCGIFADDR = 0x8915
        ifreq = struct.pack('16sH14s', interface, socket.AF_INET, '\x00'*14)
        try:
            res = fcntl.ioctl(sockfd, SIOCGIFADDR, ifreq)
        except:
            return None
        ip_address = struct.unpack('16sH2x4s8x', res)[2]
        return socket.inet_ntoa(ip_address)


    def get_nic_mask(self,interface):
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        return socket.inet_ntoa(fcntl.ioctl(s.fileno(), 0x891b, struct.pack('256s',interface))[20:24])


    def get_nic_net_addr(self,interface):
        addr = self.get_nic_ip(interface).split('.')
        mask = self.get_nic_mask(interface).split('.')
        nic_net_addr = []
        for i in range(4):
            nic_net_addr.append(int(addr[i]) & int(mask[i]))
        return nic_net_addr
