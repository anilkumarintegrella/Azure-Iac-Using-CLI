#!/bin/bash

# Variables
resourceGroupName="rg-anil-vaghari-playground"
location="westeurope"
vnetName="App-vnet"
subnet1Name="App-Subnet"
subnet2Name="AppGW-Subnet"
appGatewayName="AppGW"
vmName="VM-with-ReverseProxy"
appGWpublicIpName="PIP-AppGW"
nicName="$vmName-NIC"
nsgName="$vmName-NSG"
dnsZoneName="anilv.azure.integrella.net"

# Create a resource group
az group create \
    --name $resourceGroupName \
    --location $location 

# Create a virtual network
az network vnet create \
    --name $vnetName \
    --resource-group $resourceGroupName \
    --location $location \
    --address-prefixes 10.0.0.0/16 

# Create the first subnet for the VM
az network vnet subnet create \
    --name $subnet1Name \
    --resource-group $resourceGroupName \
    --vnet-name $vnetName \
    --address-prefixes 10.0.0.0/24 

# Create the second subnet for the application gateway
az network vnet subnet create \
    --name $subnet2Name \
    --resource-group $resourceGroupName \
    --vnet-name $vnetName \
    --address-prefixes 10.0.1.0/24 

# Create the NIC
az network nic create \
    --name $nicName \
    --resource-group $resourceGroupName \
    --location $location \
    --subnet $subnet1Name \
    --vnet-name $vnetName \
    --network-security-group $nsgName \
    --public-ip-address "$vmName-PIP" 

# Create the NSG
az network nsg create \
    --name $nsgName \
    --resource-group $resourceGroupName \
    --location $location 

# Add an inbound rule for SSH in the NSG
az network nsg rule create \
    --name "SSH" \
    --resource-group $resourceGroupName \
    --nsg-name $nsgName \
    --priority 200 --protocol Tcp \
    --destination-port-ranges 22 \
    --access Allow \
    --direction Inbound \
    --destination-address-prefixes '*' \
    --source-address-prefixes '*' 
   

# Add an inbound rule for HTTP in the NSG
az network nsg rule create \
    --name "HTTP" \
    --resource-group $resourceGroupName \
    --nsg-name $nsgName \
    --priority 100 --protocol Tcp \
    --destination-port-ranges 80 \
    --access Allow \
    --direction Inbound \
    --destination-address-prefixes '*' \
    --source-address-prefixes '*' 

# Create the public IP for the VM
az network public-ip create \
    --name "$vmName-PIP" \
    --resource-group $resourceGroupName \
    --location $location \
    --allocation-method Dynamic 

# Create the Linux VM
az vm create \
    --name $vmName \
    --resource-group $resourceGroupName \
    --location $location \
    --image UbuntuLTS \
    --admin-username anil5259 \
    --admin-password anil@1234567 \
    --size Standard_B1ls \
    --nics $nicName 

# Create the public IP address for App gateway
az network public-ip create \
    --name $appGWpublicIpName \
    --resource-group $resourceGroupName \
    --location $location \
    --allocation-method Dynamic 

# Get the private IP address of the VM
vmPrivateIpAddress=$(az vm list-ip-addresses \
    --resource-group $resourceGroupName \
    --name $vmName \
    --query "[0].virtualMachine.network.privateIpAddresses[0]" \
    --output tsv)

# Create the application gateway
az network application-gateway create \
    --name $appGatewayName \
    --resource-group $resourceGroupName \
    --location $location \
    --vnet-name $vnetName \
    --subnet $subnet2Name \
    --sku WAF_Medium \
    --http-settings-cookie-based-affinity Disabled \
    --http-settings-protocol Http \
    --public-ip-address $appGWpublicIpName 

# Create the backend address pool
az network application-gateway address-pool create \
    --gateway-name $appGatewayName \
    --name appGatewayBackendPool \
    --resource-group $resourceGroupName \
    --servers "$vmPrivateIpAddress"

#Get Public IP of Application Gateway
appGWPIP=$(az network public-ip show \
    --resource-group  $resourceGroupName \
    --name $appGWpublicIpName \
    --query "ipAddress" \
    --output tsv)

# Add a DNS Record Set
az network dns record-set a add-record \
  --resource-group $resourceGroupName \
  --zone-name $dnsZoneName \
  --record-set-name salesforce-crm \
  --ipv4-address "$appGWPIP"




