#!/usr/bin/env python3
# -*- coding: utf-8 -*-.

from shutil import get_terminal_size
from os import system
from utils.device import qos_device


class menu:
   def __init__(self):
        self.columns = get_terminal_size().columns
        self.navigate = {'1' : 'Back',
                         '2' : 'Main menu',
                         '3' : 'Exit'
                        }
        #pass

   def show(self,options='main',footer=False):
       is_main = False
       if not footer:
           system('clear')
           print("-------- QOS MANAGER --------\n".center(self.columns))
       if options == 'main':
           is_main = True
           options = {'1':'Manage QoS devices' ,
                      '2':'Manage QoS classes' ,
                      '3':'Manage QoS rules' ,
                      '4':'Traffic' ,
                      '5':'Exit'
                     }
       for k,v in options.items():
           #print(footer)
           if footer:
               #print("{}) {}".format(k,v).center(self.columns))
               print("[{} - {}]".format(k,v),end=" ")
           else:
               print("{}) {}".format(k,v).center(self.columns))
       while True:
           choice = input("\n>>>>> ")
           try:
               int_choice = int(choice)
               if int_choice > 0 and int_choice <= len(options):
                   break
           except:
               pass
       if is_main:
           self.run_action(int_choice)
       else:
           return int_choice


   def run_action(self,choice):
       if choice == 1:
           self.menu_devices()
       elif choice == 2:
           # qos_classes()
           pass
       elif choice == 3:
           # qos_rules()
           pass
       elif choice == 4:
           # qos_traffic()
           pass
       else:
           exit(0)

   def menu_navigate_actions(self,back_action,choice):
       #print(choice)
       if choice == 1:
           #self.back_action
           back_action()
           #result = back_action()
           #return result
       elif choice == 2:
           self.show()
       elif choice == 3:
           exit(0)

   def menu_devices(self):
       options = {'1':'Add device' ,
                  '2':'Delete device' ,
                  '3':'Modify device' ,
                  '4':'List devices',
                  '5':'Main menu' ,
                  '6':'Exit'
                  }
       choice = self.show(options)
       if choice == 1:
           qos_device().add_device()
           print('device added')
           choice = self.show(self.navigate,footer=True)
           self.menu_navigate_actions(self.menu_devices(),choice)
       elif choice == 2:
           qos_device().del_device()
           choice = self.show(self.navigate,footer=True)
           self.menu_navigate_actions(self.menu_devices(),choice)
       elif choice == 3:
           #self.edit_device()
           pass
       elif choice == 4:
           qos_device().list_devices()
           sub_choice = self.show(self.navigate,footer=True)
           self.menu_navigate_actions(self.menu_devices(),sub_choice)
       elif choice == 5:
           self.show()
       elif choice == 6:
           exit(0)
