#!/bin/bash
 
###################################################
## Requesting user inputs and creating variables ##
###################################################
 
echo -e "This script is designed to create Org VDC Networks in VMware Cloud Director using information in a pre-built CSV file."
echo -e "You will be prompted for some values before you begin. Please exit the script using CTRL + C if you cannot provide the inputs.\n\n\n"
 
read -p 'Enter the IP/FQDN of the VMware Cloud Director instance: ' vcdvar
read -p 'Enter the username to connect to VCD (example: administrator@system): ' uservar
read -sp 'Enter the password for the VCD user: ' vcdpassvar
echo -e '\n'
read -p 'Enter full path to CSV file continaing the list of External Networks: ' csvPath
read -p 'Enter the IP/FQDN of the NSX-T Manager: ' nsxtmanvar
read -sp 'Enter the admin password for the NSX-T Manager: ' nsxtpassvar
echo -e '\n'
read -p 'Enter the full path to the template JSON file: ' jsonpathvar
echo -e '\n\n\n'
 
jsonSuffix="-modified"
modjsonpath="${jsonpathvar}${jsonSuffix}"
 
################################################################
## Connect to VCD to obtain bearer token for the entered user ##
################################################################
 
echo -e "Connecting to $vcdvar with $uservar credentials to obtain a bearer token."
TOKEN=`curl -s -I -u "$uservar:$vcdpassvar" -X POST https://$vcdvar/cloudapi/1.0.0/sessions/provider -k -H 'Accept: application/json;version=36.3' | grep X-VMWARE-VCLOUD-ACCESS-TOKEN | sed 's/X-VMWARE-VCLOUD-ACCESS-TOKEN: //'`
TOKEN1=${TOKEN//$'\r'/}
echo -e "Retrieved bearer token:"
echo "$TOKEN1"
 
sleep 5
 
 
############################################################################################################## ##
## Parse through the CSV file and pull variables from each column, one row at a time (exluding the first row). ## 
## Replace values in a JSON file with the variables.                                                           ##
## Use the modified JSON file as input for the Create Segments command.                                        ##
#################################################################################################################
 
IFS=","
 
while read -r orgNetworkName defaultGateway prefixLength startAddress endAddress orgVdc nsxtSegmentName
do
 
# Retrieve OrgVDC URN
orgVdcUrn=`curl -X GET https://$vcdvar/cloudapi/1.0.0/vdcs -H "Accept: application/json;version=36.3" -H "Authorization: Bearer $TOKEN1" -k | jq '.values[] | .id,.name' | grep -B 1 $orgVdc | grep -v $orgVdc | sed 's/"//g'`
 
# Get the Sement Profile Template URN from VCD
segmentProfileTemplate="Isolated-Template"
segmentProfileTemplateURN=`curl -X GET https://$vcdvar/cloudapi/1.0.0/segmentProfileTemplates -k -H 'Accept: application/json;version=36.3' -H "Authorization: Bearer $TOKEN1" | jq '.values[] | .name,.id' | grep -A1 $segmentProfileTemplate | grep -v $segmentProfileTemplate | sed 's/"//g'`
 
# Create a JSON input for the creation of the OrgNet using the values from the CSV file
sed "s/#orgNetworkName#/$orgNetworkName/g;s/#defaultGateway#/$defaultGateway/g;s/#prefixLength#/$prefixLength/g;s/#startAddress#/$startAddress/g;s/#endAddress#/$endAddress/g;s/#segmentProfileTemplate#/$segmentProfileTemplate/g;s/#segmentProfileTemplateURN#/$segmentProfileTemplateURN/g;s/#orgVdc#/$orgVdc/g;s/#orgVdcUrn#/$orgVdcUrn/g" $jsonpathvar > $modjsonpath
 
# Create the OrgNet
echo -e "Creating an Organization Network with the following configuration:"
echo -e $(cat $modjsonpath)
echo -e "\n\nCreating now...."
 
curl -X POST https://$vcdvar/cloudapi/1.0.0/orgVdcNetworks -k -H 'Accept: application/json;version=36.3' -H 'Content-Type: application/json' -H "Authorization: Bearer $TOKEN1" -d @$modjsonpath
 
echo -e "Complete.\n\n\n\n"
sleep 5
 
done < $csvPath
