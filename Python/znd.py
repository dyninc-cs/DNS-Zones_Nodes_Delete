#! /usr/bin/env python

''' 
    This script searches a users account for all thier zones.
    Then the script prints out the zones and their related nodes.

    The credentials are read from a configuration file in the 
    same directory named credentials.crg in the format:

    [Dynect]
    user : user_name
    customer : customer_name
    password : password

    Usage: %python znd.py [-l|-z|-n|-N|-Z|-h]

    Options:
      -h, --help        show the help message and exit
      -l, --lists       list the zone and nodes in account
      -z, --zones       zone delete
      -n, --nodes       node delete
      -N NODE_NAME, --node_name=NODE_NAME
                        name of node
      -Z ZONE_NAME, --zone_name=ZONE_NAME
                        name of zone
    
    The library is available at: 
    https://github.com/dyninc/Dynect-API-Python-Library
'''

import sys
import ConfigParser
from DynectDNS import DynectRest
from optparse import OptionParser

# creating an instance of the api reference library to use
dynect = DynectRest()

def login(cust, user, pwd):
    '''
    This method will do a dynect login

    @param cust: customer name
    @type cust: C{str}

    @param user: user name
    @type user: C{str}

    @param pwd: password
    @type: pwd: C{str}

    @return: the function will exit the script on failure to login
    @rtype: None

    '''

    arguments = {
            'customer_name': cust,
            'user_name': user,
            'password': pwd,
    }

    response = dynect.execute('/Session/', 'POST', arguments)

    if response['status'] != 'success':
        sys.exit("incorrent credentials")

    if response['status'] == 'success':
        print "Logged Into the DynECT API"
        print "\n"

def zones_delete(zone):
    '''
    This method takes in the zone name
    from the user and deletes the zone for them.
        
    @parami zone: zone name
    @type zone: C{str}
        
    @return: Prints to user that the Zone was deleted or not deleted.
        
    '''
        
    ending = '/' + zone + '/'
    print ending
    response = dynect.execute('/REST/Zone' + ending, 
            'DELETE')
    if response['status'] != 'success':
        print "Your ZONE: " + zone + " was NOT deleted"
        dynect.execute('/Session/', 'DELETE')
    elif response['status'] == 'success':
        print "Your ZONE: " + zone + " was deleted"
    
def nodes_delete(zone, node):
    '''
    This method takes the name of the zone
    from the user and looks up the nodes under 
    that zone. The deletes the node.
        
    @param zone: zone Name
    @type zone: C{str}
    
    @param node: node name
    @type node: C{str}

    @return: Print to the user that the Node is deleted or not deleted.
        
    '''
    zone_name = '/' + zone + '/'
    publish_args = {
            "publish": True
            }
    ending = zone_name + node + '/'
    response = dynect.execute('/REST/Node' + ending, 'DELETE')
    publish = dynect.execute('/REST/Zone' + zone_name, 'PUT', publish_args)

    if response['status'] != 'success':
        print "Your NODE: " + node + " was NOT deleted"
        dynect.execute('/Session/', 'DELETE')
        sys.exit('Program Ending')
    elif response['status'] == 'success' and publish['status'] == 'success':
        print "Your NODE: " + node + " was deleted"

def zones_nodes_print():
    '''
    This method searches the user account and prints out the zones and their nodes.

    @param: None

    @return: The list of zones and nodes.
    
    '''

    response = dynect.execute('/REST/Zone/', 'GET')
    zones = response['data']
    for zone_uri in zones:
        zone = zone_uri
        nodes = zone
        zone_uri = zone_uri.strip('/')
        parts = zone_uri.split('/')
        zone = parts[len(parts) - 1]
        print '\n'
        print "ZONE: " + zone
        ending = '/' + zone + '/'
        ending = ending + zone + '/'
        response_nodes = dynect.execute('/REST/NodeList' + ending, 'GET')
        
        if response_nodes['status'] != 'success':
            print 'Failed to get nodelist!'
        nodes = response_nodes['data'] 
        for node in nodes:
            fqdn = node
            fqdn = fqdn.strip('/')
            parts = fqdn.split('/')
            node = parts[len(parts) - 1]
            print "    NODE: " + node
        
parser = OptionParser(usage="Usage: %python znd.py [-l|-z|-n|-N|-Z|-h]")
parser.add_option("-l", "--lists", action="store_true", dest="lists", default=False, help="list the zones and nodes in account")
parser.add_option("-z", "--zones", action="store_true", dest="zones", default=False, help="zone delete")
parser.add_option("-n", "--nodes", action="store_true", dest="nodes", default=False, help="node delete")
parser.add_option("-N", "--node_name", dest="node_name", help="name of node")
parser.add_option("-Z", "--zone_name", dest="zone_name", help="name of zone")
(options, args) = parser.parse_args()
val = int(options.lists) + int(options.zones) + int(options.nodes)

if val != 1:
    parser.error("You must specify one of -l|-z|-n|-N|-Z|-h")
if options.zones and options.zone_name == None:
    parser.error("You must specify a zone name(-Z) when using the -z flag")
if options.nodes and options.zone_name == None and options.node_name:
    parser.error("You must specify a zone name(-Z) and a node name(-N) when using the -n flag")

#reading in the DynECT user credentials
config = ConfigParser.ConfigParser()

try:
    config.read('credentials.cfg')
except ValueError:
    sys.exit("Error Reading Config file")
try:
    login(config.get('Dynect', 'customer', 'none'),
            config.get('Dynect', 'user', 'none'),
            config.get('Dynect', 'password', 'none'))
except ValueError:
    sys.exit("Error Logging In")

if options.lists:
    try:
        zones_nodes_print()
        print '\n'
    except ValueError:
        sys.exit("Error Program Exiting")

elif options.zones:
    
    try:
        zones_delete(options.zone_name)
    except ValueError:
        sys.exit("Error Program Exiting")

elif options.nodes:
    try:
        nodes_delete(options.zone_name, options.node_name)
    except ValueError:
        sys.exit("Error Program Exiting")

# Log out, to be polite
dynect.execute('/Session/', 'DELETE')
