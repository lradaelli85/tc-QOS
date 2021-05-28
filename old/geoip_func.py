#!/bin/env python3
# -*- coding: utf-8 -*-.

from geoip_libs.geoip_utils import utils
from geoip_libs.run import command
from json import load , dump
from sys import argv , exit
from re import search
from os import listdir , remove

class geoip:
        def __init__(self):
            pass

        def list_countries(self,countries_json):
            data = utils().load_json(countries_json)
            return data['countries']


        def list_blocked(self,to_print):
            c1_size , c2_size = utils().find_max_lenght()
            blocked_list = []
            geoip_blacklist = utils().settings['geoip_blacklist']
            bl_countries = utils().load_json(geoip_blacklist)
            countries_file = utils().settings['geoip_cctld_list']
            data = self.list_countries(countries_file)
            if len(bl_countries['bl_countries']) > 0:
                for country in bl_countries['bl_countries']:
                    if to_print:
                        utils().print_table([key.upper() for key in data.keys()][list(data.values()).index(country)],
                                            [value for value in data.values()][list(data.values()).index(country)],
                                            c1_size , c2_size)
                    else:
                        blocked_list.append([value for value in data.values()][list(data.values()).index(country)])
            elif len(bl_countries['bl_countries']) == 0 and to_print:
                print('No blacklisted countries')
            return blocked_list


        def find_country(self,country):
            countries = utils().settings['geoip_cctld_list']
            data = self.list_countries(countries)
            c1_size , c2_size = utils().find_max_lenght()
            utils().print_table('COUNTRY' , 'ccTLD', c1_size , c2_size)
            utils().print_headers()
            for c in data:
                if c.startswith(country.lower()):
                    utils().print_table(c.upper() , data[c],c1_size , c2_size)


        def add_countries_subnet(self,country):
            country_networks = utils().get_country_tmp_file(country)
            utils().set_ipset_country(country_networks,country)
            utils().set_geoip_nft()
            utils().apply_geoip()


        def del_countries_subnet(self,country):
            country = country.lower()
            geoip_settings_folder = utils().settings['geoip_settings_folder']
            utils().del_json_country(country)
            try:
                remove('{}{}-aggregated.zone.set'.format(geoip_settings_folder,country))
            except OSError as e:
                print(e)
            utils().set_geoip_nft()
            command('{} delete set inet filter {}_set'.format(utils().ipset_bin(),country)).run()
            utils().apply_geoip()


        def update_subnets(self):
            #utils().generate_cctld_list()
            blocked_country = self.list_blocked(to_print=False)
            if len(blocked_country) > 0:
                for country in blocked_country:
                    utils().download_file(country)
                    utils().set_ipset_country('/tmp/{}-aggregated.zone'.format(country),country)
                print('Update completed!')
            else:
                print('No blacklisted country.Nothing to update!')


        # def list_blacklist_ip(self):
        #     bl_countries = self.list_blocked(to_print=False)
        #     if len(bl_countries) > 0:
        #         for country in bl_countries:
        #             print(command('{} list set inet filter {}_set'.format(utils().ipset_bin(),country)).print_output())
        #     else:
        #         print('No blacklisted country.Nothing to print')
