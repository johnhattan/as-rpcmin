<?php

function paramfault ()
{
	# xmlrpc-epi-php translates this into a real <fault>
	$fault["faultCode"] = -32602;
	$fault["faultString"] = "bad parameter";
	return $fault;
}

function sum ($method_name, $params, $app_data)
{
	if (xmlrpc_get_type ($params[0]) != "array")
		return paramfault();

	$sum = 0;
	foreach ($params[0] as $val)
	{
		if (xmlrpc_get_type ($val) != "int")
			return paramfault();

		$sum = $sum + $val;
	}
	return $sum;
}

function md5sum ($method_name, $params, $app_data)
{
	$val = md5 ($params[0]->scalar, true);
	xmlrpc_set_type ($val, "base64");
	return $val;
}

// helper function because my host doesn't have PHP 5.3 yet. Once you get that, use the internal one
function createFromFormat ($format, $time){
    assert ($format!="");
    if($time==""){
        return new DateTime();
    }

    $regexpArray['Y'] = "(?P<Y>19|20\d\d)";       
    $regexpArray['m'] = "(?P<m>0[1-9]|1[012])";
    $regexpArray['d'] = "(?P<d>0[1-9]|[12][0-9]|3[01])";
    $regexpArray['-'] = "[-]";
    $regexpArray['.'] = "[\. /.]";
    $regexpArray[':'] = "[:]";           
    $regexpArray['space'] = "[\s]";
    $regexpArray['H'] = "(?P<H>0[0-9]|1[0-9]|2[0-3])";
    $regexpArray['i'] = "(?P<i>[0-5][0-9])";
    $regexpArray['s'] = "(?P<s>[0-5][0-9])";

    $formatArray = str_split ($format);
    $regex = "";

    // create the regular expression
    foreach($formatArray as $character){
        if ($character==" ") $regex = $regex.$regexpArray['space'];
        elseif (array_key_exists($character, $regexpArray)) $regex = $regex.$regexpArray[$character];
    }
    $regex = "/".$regex."/";

    // get results for regualar expression
    preg_match ($regex, $time, $result);

    // create the init string for the new DateTime
    $initString = $result['Y']."-".$result['m']."-".$result['d'];

// if no value for hours, minutes and seconds was found add 00:00:00
    if (isset($result['H'])) $initString = $initString." ".$result['H'].":".$result['i'].":".$result['s'];
    else {$initString = $initString." 00:00:00";}

    $newDate = new DateTime ($initString);
    return $newDate;
}

function nextDay ($method_name, $params, $app_data)
{	// note that createFromFormat is part of PHP, but only > 5.3
	$dt = createFromFormat(DateTime::ISO8601, $params[0]->string);
	$dt->modify('+1 day');

	$ret = $dt->format('c');
	xmlrpc_set_type ($ret, "datetime");
	
	return $ret;
}

function concat($method_name, $params, $app_data)
{
	$concat = '';
	foreach ($params as $val)
		$concat .= $val;
	return $concat;
}

function reverse($method_name, $params, $app_data)
{
	return array_reverse($params);
}

# Work around xmlrpc-epi-php lossage; otherwise the datetime values we return will sometimes get a DST adjustment we don't want.
putenv ("TZ=");

$xmlrpc_server = xmlrpc_server_create ();

xmlrpc_server_register_method($xmlrpc_server, "sum", "sum");
xmlrpc_server_register_method($xmlrpc_server, "md5sum", "md5sum");
xmlrpc_server_register_method($xmlrpc_server, "nextDay", "nextDay");
xmlrpc_server_register_method($xmlrpc_server, "concat", "concat");
xmlrpc_server_register_method($xmlrpc_server, "reverse", "reverse");

echo (xmlrpc_server_call_method ($xmlrpc_server, implode("\r\n", file('php://input')), 0, array ("output_type" => "xml")));

xmlrpc_server_destroy ($xmlrpc_server);

?>