#!/usr/bin/env python3
# -*- coding: utf-8 -*-.


def dev_errors(error_value):
    err = { 'QOS_DEV_ALREADY_EXISTS': 'QoS device already exists',
            'DEV_NOT_EXISTS' : 'Network interface doesn\'t exists',
            'INVALID_UPLOAD_VAL' : 'Value not accepted.\nAccepted values: kb,KB,mb',
            'INVALID_DOWNLOAD_VAL' : 'Value not accepted.\nAccepted values: kb,KB,mb',
            'NO_QOS_DEV' : 'No QoS device found on this interface'
          }
    return err[error_value]
