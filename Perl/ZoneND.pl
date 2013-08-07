#!/usr/bin/perl
#This script searches and prints out the zones and their related nodes.
#This will delete a zone or node depending on which flag is set (-z or -n).
#The upper case flag (-Z or -N) needs to be set to the name of zone and node (if used).
#The credentials are read from a configuration file in the 
#same directory named config.cfg in the format:

#[Dynect]
#user : user_name
#customer : customer_name
#password : password

#Usage: 
#This will print out the list of zones & nodes
#perl znd.py [-l]

#This will delete the node "node.example.com" 
#perl znd.py -Z example.com [-n] -N node.example.com

#This will delete the zone and all of its nodes
#perl znd.py [-z] -Z example.com 

#Options:
#-h, --help          Show the help message and exit
#-l, --lists         List all of the zone and nodes in an account
#-z, --zones         Set the zone to delete
#-n, --nodes         Set the node to delete
#-N  --node_name     Name of the node [Required for node delete]
#-Z  --zone_name     Name of the zone [Required]

use warnings;
use strict;
use XML::Simple;
use Config::Simple;
use Getopt::Long qw(:config no_ignore_case);
use LWP::UserAgent;
use JSON;

#Import DynECT handler
use FindBin;
use lib "$FindBin::Bin/DynECT";  # use the parent directory
require DynECT::DNS_REST;

#Get Options
my $opt_list;
my $opt_zoneDel;
my $opt_nodeDel;
my $opt_nodeName="";
my $opt_zoneName="";
my $opt_help;
my %api_param = ();

GetOptions(
	'help' => \$opt_help,
	'lists' => \$opt_list,
	'zones' => \$opt_zoneDel,
	'nodes' => \$opt_nodeDel,
	'NODE_NAME=s' =>\$opt_nodeName,
	'ZONE_NAME=s' =>\$opt_zoneName,
);

#Printing help menu
if ($opt_help) {
	print "Options:\n";
	print "\t-h, --help\t\t Show the help message and exit\n";
	print "\t-l, --lists\t\t List all of the zone and nodes in an account\n";
	print "\t-z, --zones\t\t Set the zone to delete\n";
	print "\t-n, --nodes\t\t Set the node to delete\n";
	print "\t-N, --NODE_NAME\t\t Name of node [Required for node delete]\n";
	print "\t-Z, --ZONE_NAME\t\t Name of zone [Required]\n\n";
	exit;
}

#Create config reader
my $cfg = new Config::Simple();

# read configuration file (can fail)
$cfg->read('config.cfg') or die $cfg->error();

#dump config variables into hash for later use
my %configopt = $cfg->vars();
my $apicn = $configopt{'cn'} or do {
print "Customer Name required in config.cfg for API login\n";
exit;
};

my $apiun = $configopt{'un'} or do {
print "User Name required in config.cfg for API login\n";
exit;
};

my $apipw = $configopt{'pw'} or do {
print "User password required in config.cfg for API login\n";
exit;
};

#API login
my $dynect = DynECT::DNS_REST->new;
$dynect->login( $apicn, $apiun, $apipw) or
	die $dynect->message;


#Listing Zone/Nodes
if($opt_list)
{
	#Set param to empty
	%api_param = ();
	$dynect->request( "/REST/Zone", 'GET',  \%api_param) or die $dynect->message;

	foreach my $zoneIn (@{$dynect->response->{'data'}})
	{
		#Getting the zone name out of the response.
		$zoneIn =~ /\/REST\/Zone\/(.*)\/$/;
		#Print each zone	
		print "\nZone: $1\n";

		%api_param = ();
		$dynect->request( "/REST/NodeList/$1", 'GET',  \%api_param) or die $dynect->message;

		#Print each node in zone
		print "Nodes: \n";
		foreach my $nodeIn (@{$dynect->request->{'data'}})
			{print "\t$nodeIn\n";}
	}
}


#Zone delete
if($opt_zoneDel)
{
	#If -z is set but -Z is not, tell the user.
	if($opt_zoneName eq "")
		{print "\nNo zone name specified, please use: \n\t\t -z -Z <Name of zone here>\n";}
	
	#If -Z is set, delete the zone
	else{
		%api_param = ();
		$dynect->request( "/REST/Zone/$opt_zoneName", 'DELETE',  \%api_param) or die $dynect->message;
		print "Zonefile: $opt_zoneName successfully deleted.\n";
	}
}

#Node delete
if($opt_nodeDel)
{
	#If -n is set but -N is not, tell the user.
	if($opt_nodeName eq "")
		{print "\nNo node name specified, please use: \n\t\t -n -N <Name of node here>\n";}
	#If -n is set and -N is set but -Z is not set, tell the user.
	elsif($opt_zoneName eq "")
		{print "\nNo zone name specified, please use: \n\t\t -n -N <Name of node here> -Z <Name of zone here>\n";}
	#If -z -Z -N are set, delete the node
	else{
		%api_param = ();
		$dynect->request( "/REST/Node/$opt_zoneName/$opt_nodeName", 'DELETE',  \%api_param) or die $dynect->message;
		print "Node: $opt_nodeName sucessfully deleted.\n";
		%api_param = ( 'publish' => 1);
		$dynect->request( "/REST/Zone/$opt_zoneName", 'PUT',  \%api_param) or die $dynect->message;
	}
}

#API logout
$dynect->logout;
