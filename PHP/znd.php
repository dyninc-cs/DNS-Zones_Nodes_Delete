#!/usr/bin/php
<?php

#This script searches and prints out the zones and their related nodes. 
#This will delete a zone or node depending on which flag is set (-z or -n). 
#The upper case flag (-Z or -N) needs to be set to the name of zone and node (if used).

#[Dynect] 
#un: user_name 
#cn: customer_name 
#pw: password

#Options:
#-h, --help          show the help message and exit
#-l, --lists         list the zone and nodes in account
#-z, --zones         zone delete
#-n, --nodes         node delete
#-N  --node_name     name of node
#-Z  --zone_name     name of zone

#Example Usage Scenarios:
#Want to print all Zones and Nodes
#php znd.php -l
#Want to delete a Zone\n
#php znd.php -z -Z <name of zone here>
#Want to delete a Node\n
#php znd.php -n -Z <name of zone here> -N <name of node here>

#Get options from command line
$shortopts .= "Z:";  
$shortopts .= "z"; 
$shortopts .= "N:";  
$shortopts .= "n";  
$shortopts .= "h"; 
$shortopts .= "l"; 
$options = getopt($shortopts, $longopts);

$opt_zoneName .= $options["Z"]; 
$opt_zoneName .= $options["ZONE_NAME"]; 
$opt_nodeName .= $options["N"]; 
$opt_nodeName .= $options["NODE_NAME"]; 

#Print help menu
if (is_bool($options["h"])) {

	print "\tAPI integration requires paramaters stored in config.ini\n\n";

	print "\tOptions:\n";
	print "\t\t-h, --help\t\t Show the help message and exit\n";
	print "\t\t-l, --lists\t\t List all of the zone and nodes in an account\n";
	print "\t\t-z, --zones\t\t Set the zone to delete\n";
	print "\t\t-n, --nodes\t\t Set the node to delete\n";
	print "\t\t-N, --NODE_NAME\t\t Name of node\n";
	print "\t\t-Z, --ZONE_NAME\t\t Name of zone\n\n";

	print "\tExample Usage Scenarios:\n";
	print "\t\tWant to print all Zones and Nodes\n";
	print "\t\t\$ php znd.php -l\n\n";
	print "\t\tWant to delete a Zone\n";
	print "\t\t\$ php znd.php -z -Z <name of zone here>\n\n";
	print "\t\tWant to delete a Node\n";
	print "\t\t\$ php znd.php -n -Z <name of zone here> -N <name of node here>\n\n";
	exit;

}
# Parse ini file (can fail)
$ini_array = parse_ini_file("config.ini") or die;

#Set the values from file to variables or die
$api_cn = $ini_array['cn'] or die("Customer Name required in config.ini for API login\n");
$api_un = $ini_array['un'] or die("User Name required in config.ini for API login\n");
$api_pw = $ini_array['pw'] or die("Password required in config.ini for API login\n");	

# Set opt_node to true if user enters -n or -nodes
if (is_bool($options["n"]) || is_bool($options["nodes"])) {$opt_node = true;}

# Set opt_zone to true if user enters -z or -zones
if (is_bool($options["z"]) || is_bool($options["zones"])) {$opt_zone = true;}

# Set opt_zone to true if user enters -z or -zones
if (is_bool($options["l"]) || is_bool($options["list"])) {$opt_list = true;}

# Prevent the user from proceeding if they have not entered -n or -z
if(!$opt_zone == true && !$opt_node == true && !$opt_list)
{
	print "You must enter either \"-z\" or \"-n\" or \"-l\"\n";
	exit;
}


# Log into DYNECT
# Create an associative array with the required arguments
$api_params = array(
			'customer_name' => $api_cn,
			'user_name' => $api_un,
			'password' => $api_pw);
$session_uri = 'https://api2.dynect.net/REST/Session/'; 
$decoded_result = api_request($session_uri, 'POST', $api_params, $token);	

#Set the token
if($decoded_result->status == 'success'){
	$token = $decoded_result->data->token;
}

# Print list of zones & nodes
if($opt_list)
{
	# Zone URI & Empty Params	
	$session_uri = 'https://api2.dynect.net/REST/Zone/'; 
	$api_params = array (''=>'');
	$decoded_result = api_request($session_uri, 'GET', $api_params,  $token);	

	# For each zone print the zone name & nodes if requested
	foreach($decoded_result->data as $zonein){

		# Getting ZoneName out of result
		preg_match("/\/REST\/Zone\/(.*)\/$/", $zonein, $matches);
		$zoneName = $matches[1];

		# Print out each zone
		print "ZONE: ".$zoneName . "\n";

		# Zone URI & Empty Params	
		$session_uri = 'https://api2.dynect.net/REST/NodeList/'. $zoneName . '/'; 
		$api_params = array (''=>'');
		$decoded_result = api_request($session_uri, 'GET', $api_params,  $token);	
		#Print Nodes
		foreach($decoded_result->data as $nodein){
			print "\tNODE: " . $nodein. "\n";
		}
	}
exit;
}

#Delete Zone
if($opt_zone == true)
{
	# If -Z is not set, tell the user
	if($opt_zoneName == "")
	{print "\nNo zone name specified, please use: \n\t\t -z -z <Name of zone here>\n";}
	
	else
	{
		# Zone URI & Empty Params	
		$session_uri = "https://api2.dynect.net/REST/Zone/$opt_zoneName/"; 
		$api_params = array (''=>'');
		$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	
	}
}


#Delete Nodes 
if($opt_node == true)
{
	# If -N is not set, tell the user
	if($opt_nodeName == "")
	{print "\nNo node name specified, please use: \n\t\t -n -N <Name of node here>\n";}
	else
	{
		# Zone URI & Empty Params	
		$session_uri = "https://api2.dynect.net/REST/Node/$opt_zoneName/$opt_nodeName/"; 
		$api_params = array (''=>'');
		$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	
	}
	api_publish($opt_zoneName, $token);
}

# Logging Out
$session_uri = 'https://api2.dynect.net/REST/Session/'; 
$api_params = array (''=>'');
$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	

function api_publish($opt_zoneName, $token){
	do{
		sleep(5);
		$session_uri = "https://api2.dynect.net/REST/Zone/$opt_zoneName/"; 
		$api_params = array (''=>'');
		$decoded_result = api_request($session_uri, 'GET', $api_params,  $token);	
	} while($decoded_result->data->serial == 0);

	$session_uri = "https://api2.dynect.net/REST/Zone/$opt_zoneName/"; 
	$api_params = array ('publish' => 1);
	$decoded_result = api_request($session_uri, 'PUT', $api_params,  $token);
	//print_r($decoded_result);	

}

# Function that takes zone uri, request type, parameters, and token.
# Returns the decoded result
function api_request($zone_uri, $req_type, $api_params, $token)
{
	$ch = curl_init();
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);  # TRUE to return the transfer as a string of the return value of curl_exec() instead of outputting it out directly.
	curl_setopt($ch, CURLOPT_FAILONERROR, false); # Do not fail silently. We want a response regardless
	curl_setopt($ch, CURLOPT_HEADER, false); # disables the response header and only returns the response body
	curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json','Auth-Token: '.$token)); # Set the token and the content type so we know the response format
	curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $req_type);
	curl_setopt($ch, CURLOPT_URL, $zone_uri); # Where this action is going,
	if($api_params != array(''=> '')) # If the api parmas are not empty
	{curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($api_params));}

	$http_result = curl_exec($ch);

	$decoded_result = json_decode($http_result); # Decode from JSON as our results are in the same format as our request
	api_fail($token, $decoded_result);

	return $decoded_result;
}

#Expects 2 variable, first a reference to the API key and second a reference to the decoded JSON response
function api_fail($token, $api_jsonref) 
{
	#loop until the job id comes back as success or program dies
	while ( $api_jsonref->status != 'success' ) {
        	if ($api_jsonref->status != 'incomplete') {
                       foreach($api_jsonref->msgs as $msgref) {
                                print "API Error:\n";
                                print "\tInfo: " . $msgref->INFO . "\n";
                                print "\tLevel: " . $msgref->LVL . "\n";
                                print "\tError Code: " . $msgref->ERR_CD . "\n";
                                print "\tSource: " . $msgref->SOURCE . "\n";
                        };
                        #api logout or fail
			$session_uri = 'https://api2.dynect.net/REST/Session/'; 
			$api_params = array (''=>'');
			# If token isnt empty, logout
			if($token != "")
				$decoded_result = api_request($session_uri, 'DELETE', $api_params,  $token);	
                        exit;
                }
                else {
                        sleep(5);
                        $session_uri = "https://api2.dynect.net/REST/Job/" . $api_jsonref->job_id ."/";
			$api_params = array (''=>'');
			$decoded_result = api_request($session_uri, 'GET', $api_params,  $token);	
               }
        }
        return $api_jsonref;
}
?>


