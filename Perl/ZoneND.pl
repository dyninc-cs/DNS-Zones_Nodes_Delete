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

#Get Options
my $opt_list;
my $opt_zoneDel;
my $opt_nodeDel;
my $opt_nodeName="";
my $opt_zoneName="";
my $opt_help;

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
my $session_uri = 'https://api2.dynect.net/REST/Session';
my %api_param = ( 
'customer_name' => $apicn,
'user_name' => $apiun,
'password' => $apipw,);
my $api_request = HTTP::Request->new('POST',$session_uri);
$api_request->header ( 'Content-Type' => 'application/json' );
$api_request->content( to_json( \%api_param ) );
my $api_lwp = LWP::UserAgent->new;
my $api_result = $api_lwp->request( $api_request );
my $api_decode = decode_json ( $api_result->content ) ;
my $api_token = $api_decode->{'data'}->{'token'};


#Listing Zone/Nodes
if($opt_list)
{
	#Set param to empty
	%api_param = ();
	$session_uri = "https://api2.dynect.net/REST/Zone/";
	$api_decode = &api_request($session_uri, 'GET', $api_token ,  %api_param); 
	foreach my $zoneIn (@{$api_decode->{'data'}})
	{
		#Getting the zone name out of the response.
		$zoneIn =~ /\/REST\/Zone\/(.*)\/$/;
		#Print each zone	
		print "\nZone: $1\n";

		%api_param = ();
		$session_uri = "https://api2.dynect.net/REST/NodeList/$1";
		$api_decode = &api_request($session_uri, 'GET', $api_token,  %api_param); 
		
		#Print each node in zone
		print "Nodes: \n";
		foreach my $nodeIn (@{$api_decode->{'data'}})
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
		$session_uri = "https://api2.dynect.net/REST/Zone/$opt_zoneName/";
		&api_request($session_uri, 'DELETE', $api_token, %api_param); 
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
		$session_uri = "https://api2.dynect.net/REST/Node/$opt_zoneName/$opt_nodeName/";
		&api_request($session_uri, 'DELETE', $api_token, %api_param); 
		print "Node: $opt_nodeName sucessfully deleted.\n";
		&api_publish($api_token); #Publish zone
	}
}

#api logout
%api_param = ();
$session_uri = 'https://api2.dynect.net/REST/Session';
&api_request($session_uri, 'DELETE', $api_token, %api_param); 

#Accepts Zone URI, Request Type, and Any Parameters
sub api_request{
	#Get in variables, send request, send parameters, get result, decode, display if error
	my ($zone_uri, $req_type, $api_key, %api_param) = @_;
	$api_request = HTTP::Request->new($req_type, $zone_uri);
	$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $api_key );
	$api_request->content( to_json( \%api_param ) );
	$api_result = $api_lwp->request($api_request);
	$api_decode = decode_json( $api_result->content);
	$api_decode = &api_fail(\$api_key, $api_decode) unless ($api_decode->{'status'} eq 'success');
	return $api_decode;
}

sub api_publish{
	#Check if the zone exists and is ready to publish
	my ( $api_key) = @_;
	do {
		sleep(5);
		$api_decode = &api_request("https://api2.dynect.net/REST/Zone/$opt_zoneName/", 'GET', $api_key,  %api_param); 
		$api_decode = &api_fail(\$api_key, $api_decode) unless ($api_decode->{'status'} eq 'success');
	} while ( $api_decode->{'data'}->{'serial'} == 0 );

	#Publishing the zone
	my $zone_uri = "https://api2.dynect.net/REST/Zone/$opt_zoneName/";
	%api_param = ( 'publish' => 1);
	$api_decode = &api_request("$zone_uri", 'PUT', $api_key, %api_param); 
	$api_decode = &api_fail(\$api_key, $api_decode) unless ($api_decode->{'status'} eq 'success');
}

#Expects 2 variable, first a reference to the API key and second a reference to the decoded JSON response
sub api_fail {
	my ($api_keyref, $api_jsonref) = @_;
	#set up variable that can be used in either logic branch
	my $api_request;
	my $api_result;
	my $api_decode;
	my $api_lwp = LWP::UserAgent->new;
	my $count = 0;
	#loop until the job id comes back as success or program dies
	while ( $api_jsonref->{'status'} ne 'success' ) {
		if ($api_jsonref->{'status'} ne 'incomplete') {
			foreach my $msgref ( @{$api_jsonref->{'msgs'}} ) {
				print "API Error:\n";
				print "\tInfo: $msgref->{'INFO'}\n" if $msgref->{'INFO'};
				print "\tLevel: $msgref->{'LVL'}\n" if $msgref->{'LVL'};
				print "\tError Code: $msgref->{'ERR_CD'}\n" if $msgref->{'ERR_CD'};
				print "\tSource: $msgref->{'SOURCE'}\n" if $msgref->{'SOURCE'};
			};
			#api logout or fail
			$api_request = HTTP::Request->new('DELETE','https://api2.dynect.net/REST/Session');
			$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $$api_keyref );
			$api_result = $api_lwp->request( $api_request );
			$api_decode = decode_json ( $api_result->content);
			exit;
		}
		else {
			sleep(5);
			my $job_uri = "https://api2.dynect.net/REST/Job/$api_jsonref->{'job_id'}/";
			$api_request = HTTP::Request->new('GET',$job_uri);
			$api_request->header ( 'Content-Type' => 'application/json', 'Auth-Token' => $$api_keyref );
			$api_result = $api_lwp->request( $api_request );
			$api_jsonref = decode_json( $api_result->content );
		}
	}
	$api_jsonref;
}

