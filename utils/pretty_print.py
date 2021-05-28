#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

from sys import exit

class table:
    def __init__(self,header='Null',body='Null'):
        self.header = header
        self.body = body
        self.col_size = self.get_max_lenght()
        self.separator = '-'

    def get_max_lenght(self):
        row_number = len(self.body)
        counter = 0
        row_list = {}
        for row in self.body:
            row_list['row'+str(counter)] = row
            counter +=1
        row_list['row'+str(row_number)] = self.header
        max_len=0
        for value in row_list.values():
            for i in value:
                if len(i) > max_len:
                    max_len=len(i)
        return max_len

    def __check_num_element__(self,header,body):
        if len(body) == len(header):
            return True
        else:
            return False

    def print_table(self):
        if len(self.body) == 0 or len(self.header) == 0:
            print('Empty')
            return
        width = self.col_size
        if type(self.header) is list:
            for header_element in self.header:
                if header_element == self.header[-1]:
                    print ("{0:{width}}".format(header_element,width=width),end='\n')
                else:
                    print ("{0:{width}}".format(header_element,width=width),end=' ')
        else:
            raise TypeError('Not a list type')
        i=0
        while i < len(self.header):
            l=0
            while l < self.col_size:
                if l == self.col_size-1 and i == len(self.header)-1:
                    print(self.separator,end='\n')
                else:
                    print(self.separator,end='')
                l+=1
            if i < len(self.header)-1:
                print(end=' ')
            i+=1
        if type(self.body[0]) is not list:
            if not self.__check_num_element__(self.header,self.body):
                print('[ERROR]:header columns number differ from body columns numbers')
                exit(1)
            for body_element in self.body:
                print ("{0:{width}}".format(body_element,width=width),end='')
            print(end=' ')
        elif type(self.body[0]) is list:
            for body_list in self.body:
                if not self.__check_num_element__(self.header,body_list):
                    print('[ERROR]:header columns number differ from body columns numbers')
                    exit(1)
                for body_element in body_list:
                    if body_element == body_list[-1]:
                        print ("{0:{width}}".format(body_element,width=width),end='\n')
                    else:
                        print ("{0:{width}}".format(body_element,width=width),end='')
                        print(end=' ')
