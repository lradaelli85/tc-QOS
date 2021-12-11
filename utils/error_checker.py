#!/usr/bin/env python3
# -*- coding: utf-8 -*-.


def qos_errors(error_value):
    err = { 'QOS_DEV_ALREADY_EXISTS': '[ERROR]: QoS device already exists\n',
            'DEV_NOT_EXISTS' : '[ERROR]: Network interface doesn\'t exists\n',
            'QOS_DEV_NOT_EXISTS' : '[ERROR]: No QoS devices found \n',
            'INVALID_UPLOAD_VAL' : '[ERROR]: Value not accepted.\nAccepted values: kb,KB,mb\n',
            'INVALID_DOWNLOAD_VAL' : '[ERROR]: Value not accepted.\nAccepted values: kb,KB,mb\n',
            'NO_QOS_DEV' : '[ERROR]: No QoS device found on this interface\n',
            'QOS_CLASS_ALREADY_EXISTS' : '[ERROR]: Class already exists\n',
            'NO_QOS_CLASS' : '[ERROR]: Class does not exists\n'
          }
    return err[error_value]
