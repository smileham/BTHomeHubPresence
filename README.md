# BTHomeHubPresence
This powershell script logs into your BT HomeHub 6 (or SmartHub), grabs a list of current devices registered to the network, compares that to a list from the last time the script ran, and then for any changes, looks into a list of devices in a file to know whether to trigger the Samsung SmartThings smart app.

The SmartThings integration just uses the ASUSWRT code from here;

https://community.smartthings.com/t/release-asuswrt-wifi-presence/37802

I run this script from "c:\scripts" although this can be changed in the script.
You will need three files, the first two can be blank;

c:\script\devices.h6.st.csv
c:\script\devices.h6.st.old.csv
c:\script\devices.h6.presence.csv

The "devices.h6.presence.csv" has the following format;
"PhysAddress","AppID","Token"

PhysAddress is the MAC address for the device, the AppID and Token are from the SmartThings App (follow the ASUSWRT tutorial)
