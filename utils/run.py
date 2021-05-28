#!/bin/env python3
# -*- coding: utf-8 -*-.

import subprocess
from shlex import split
from sys import exc_info
from os import devnull

class command:
        def __init__(self,command):
            self.command = command
            self.FNULL = open(devnull, 'w')

        def run(self):
            try:
                process = subprocess.Popen(split(self.command),stderr=self.FNULL,stdout=self.FNULL)
                output = process.communicate()
                exit_status = process.wait()
            except:
                exit_status = exc_info()[1]
            return exit_status

        def print_output(self):
            try:
                output_ret = subprocess.check_output(split(self.command),stderr=self.FNULL)
            except subprocess.CalledProcessError as e:
                output_ret = e
            return output_ret
