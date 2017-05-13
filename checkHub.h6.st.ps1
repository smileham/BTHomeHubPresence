function md5_hex ($theString) {
$utf8 = [system.Text.Encoding]::UTF8;
$stream = [System.IO.MemoryStream]::new($utf8.GetBytes($theString));
$theHash = Get-FileHash -Algorithm MD5 -InputStream $stream | Select-Object -ExpandProperty Hash;
return $theHash.ToLower();
}

# Declare variables
$stURL = "https://graph-eu01-euwest1.api.smartthings.com/api/smartapps/installations/";

$logLocation = "c:\scripts\devices.h6.st.log";
$scriptLocation = "c:\scripts\";
$newUrl = -join ($scriptLocation,"devices.h6.st.csv");
$oldUrl = -join ($scriptLocation,"devices.h6.st.old.csv");

# Required for execution via Task Scheduler
[System.Net.ServicePointManager]::Expect100Continue=$false;


$authCookie = @{
	req_id = 1;
	sess_id = 0;
	basic = $false;
	user = "guest";
	dataModel = @{
		name = "Internal";
		nss = @(@{name="gtw"; uri="http://sagemcom.com/gateway-data"})
	};
	ha1= "ca6e4940afd41d8cd98f00b204e9800998ecf8427e830e7a046fd8d92ecec8e4";
	nonce="";
}
$authRequestObj = @{
	request= @{
		id= 0;
		"session-id"= "0";
		priority= $true;
		actions= @(
			@{
				id= 0;
				method= "logIn";
				parameters= @{
					user= "guest";
					persistent= "true";
					"session-options"= @{
						nss= @(
							@{
								name= "gtw";
								uri= "http://sagemcom.com/gateway-data";
							}
						);
						language= "ident";
						"context-flags"= @{
							"get-content-name"= $true;
							"local-time"= $true
						};
						"capability-depth"= 2;
						"capability-flags"= @{
							name= $true;
							"default-value"= $false;
							restriction= $true;
							description= $false;
						};
						"time-format"= "ISO_8601"
					}
				}
			}
		);
		cnonce= 745670196;
		"auth-key"= "06a19e589dc848a89675748aa2d509b3"
	}
};
Start-Transcript ($logLocation);
$loginHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$cookieJson = $authCookie | ConvertTo-Json -Depth 3 -compress
$cookieEncoded = [System.Web.HttpUtility]::UrlEncode($cookieJson);
$loginHeaders.Add("Cookie",-join("lang=en; session=",$cookieEncoded));
$authRequestObjJson = $authRequestObj | ConvertTo-Json -Depth 7 -compress;
$authEncoded = -join("req=",[System.Web.HttpUtility]::UrlEncode($authRequestObjJson));

$response = Invoke-RestMethod -Method Post -Uri "http://bthomehub.home/cgi/json-req" -Headers $loginHeaders -Body $authEncoded;

if ($response) {

	$requestId=1;
	$clientNonce = Get-Random;
	$user ="guest";
	$pass="d41d8cd98f00b204e9800998ecf8427e"; # MD5 of an empty string

	$serverNonce = $response.reply.actions.callbacks.parameters.nonce;
	$authHash = md5_hex(-join($user,":",$serverNonce,":",$pass));
	$authKey = md5_hex(-join($authHash,":",$requestId,":",$clientNonce,":JSON:/cgi/json-req"));


	$listCookie = @{
		req_id = $requestId;
		sess_id = $response.reply.actions.callbacks.parameters.id;
		basic = $false;
		user = "guest";
		dataModel = @{
			name = "Internal";
			nss = @(@{name="gtw"; uri="http://sagemcom.com/gateway-data"})
		};
		ha1= "2d9a6f39b6d41d8cd98f00b204e9800998ecf8427eba8d73fbd3de28879da7dd";
		nonce= $serverNonce;
	}

	$listReqObj = @{
		request= @{
			id= $requestId;
			"session-id"= $response.reply.actions.callbacks.parameters.id;
			priority= $false;
			actions= @(
				@{
					id= 1;
					method= "getValue";
					xpath= "Device/Hosts/Hosts";
					options= @{
						"capability-flags"= @{
							interface= $true
						}
					}
				}
			);
			cnonce= $clientNonce;
			"auth-key"= $authKey;
		}
	};

	$listHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$listCookieJson = $listCookie | ConvertTo-Json -Depth 3 -compress
	$listCookieEncoded = [System.Web.HttpUtility]::UrlEncode($listCookieJson);
	$listHeaders.Add("Cookie",-join("lang=en; session=",$listCookieEncoded));

	$listRequestObjJson = $listReqObj | ConvertTo-Json -Depth 6 -compress;
	$listEncoded = -join("req=",[System.Web.HttpUtility]::UrlEncode($listRequestObjJson));

	$listResponse = Invoke-RestMethod -Method Post -Uri "http://bthomehub.home/cgi/json-req" -Headers $listHeaders -Body $listEncoded;
	
	if ($listResponse) {
	
		$devices = $listResponse.reply.actions.callbacks.parameters | Select-Object -Expand value;

		$devices | Select InterfaceType, HostName, UserFriendlyName, PhysAddress, IPAddress, Active | Where {$_.Active -eq $true} |Export-Csv $newUrl;

		$deviceUpdate=$true;
	}
}

if ($deviceUpdate) {		
	# Load Device files
	
	$new = import-csv $newUrl;
	
	$old = import-csv $oldUrl;
	#$ignore = import-csv -join ($scriptLocation,"devices.h6.ignore.csv");
	$presenceUrl = -join ($scriptLocation,"devices.h6.presence.csv");
	$presenceList = import-csv $presenceUrl
	#copy-item -join ($scriptLocation,"devices.h6.st.old.csv") -join ($scriptLocation,"devices.h6.st.archive.csv") -force;
	copy-item $newUrl $oldUrl -force;
	
	if ($new -and $old) {

		foreach ($device in $new) {
		  if (!$old.PhysAddress.contains($device.PhysAddress) -and $presenceList.PhysAddress.contains($device.PhysAddress)) {
		    #Still need to find the exact row
			$smartApp = $presenceList | Where({$PSItem.PhysAddress -eq $device.PhysAddress});
		    $stWebRequestURL = -join($stURL,$smartApp.AppID,"/Phone/home?access_token=",$smartApp.Token);
			Invoke-WebRequest -uri $stWebRequestURL;
		  }
		}

		foreach ($device in $old) {
		  if (!$new.PhysAddress.contains($device.PhysAddress) -and $presenceList.PhysAddress.contains($device.PhysAddress)) {
		    $smartApp = $presenceList | Where({$PSItem.PhysAddress -eq $device.PhysAddress});
		    $stWebRequestURL = -join($stURL,$presenceList.AppID,"/Phone/away?access_token=",$presenceList.Token);
			Invoke-WebRequest -uri $stWebRequestURL;
		  }
		}
	}
}
Stop-Transcript;
exit $lastexitcode;
