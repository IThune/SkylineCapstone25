# How to Deploy this Repository on Azure #

This guide assumes you are using Azure CLI with Bicep installed. To install Azure CLI Microsoft has a guide written here: [https://learn.microsoft.com/en-us/cli/azure/install-azure-cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

For more information about installing Bicep read here: [https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install).

## Before Beginning.. ##

This project is just a sample project, not a production-ready one. The [config.xml file for OPNsense](scripts/config.xml) contains password hashes and private keys needed to configure the firewall and VPN service. It is a future goal to use a templating engine in order to avoid leaving these values in this public repository, but it is *highly* recommended to change these defaults after deploying!

It is also recommended to be able to access the Azure Portal for troubleshooting, in case something goes wrong, you will be able to access the serial console of VMs.

## Step 1 - Install Wireguard and create a Peer Configuration ##

Accessing the Skyline environment requires a Wireguard connection. So you will want to have Wireguard installed on your system and create a Wireguard configuration file. You can use the one here:

```
[Interface]
Address = 10.10.100.1
PrivateKey = iHM8ESHZaiGLikZd3/OlLlRF5B0VXYc/17+3l5at3mc=

[Peer]
PublicKey = bU+yT+JY3BtOCa5921i7/amF3fl9AinKyoQthtIO3wQ=
AllowedIPs = 10.0.0.0/16, 10.10.0.0/16
Endpoint = YourOPNsensePublicIPAddressHere:51820
PersistentKeepalive = 30
```

## Step 2 - Clone this repository ##

You can download this repo with the command `git clone https://github.com/IThune/SkylineCapstone25`

## Step 3 - Create a Resource Group in Azure ##

A Resource Group is like a container in Azure that has all of the resources you will deploy. Create one with the command `az group create --name RGName --location eastus` and replace the location with the desired one.

## Step 4 - Run the deployment operation ##

Open a command line or terminal and change directories to the root folder of the cloned repository. Issue the following command: `az deployment group create --resource-group RGName --template-file bicep/main.bicep`

You will be required to enter some parameters before the deployment begins. Here's what those parameters are:

| Parameter Name | Description |
| ------------- | -------------- |
| AdminUsername | A user with 'sudo' privileges on the OPNsense host |
| AdminPassword | Password of the Admin user above |
| ZoneminderMySQLPassword | The database password used to access the back-end of Zoneminder |
| ZoneminderAdminUsername | A user with 'sudo' privileges on the Zoneminder host |
| ZoneminderAdminPassword | Password of the Zoneminder Admin above |

The deployment will take approx. 30 minutes to complete. Note: There is currently an issue where the script for Zoneminder will throw warnings, which may look like the deployment failed, but it should still work just fine anyways.

## Step 5 - Connect to Wireguard VPN ##

Activate your Wireguard peer connection with the following command: `sudo systemctl start wg-quick@wg#` where # is the number of the config file you made earlier. If you are using Windows, then use the GUI program to start Wireguard.

Test your connection to the gateway by issuing a ping to 10.0.0.4. If you get a response, then you have successfully connected.

## Step 6 - Access the Gateway's Web UI and change default settings ##

You can access the OPNsense UI at https://10.0.0.4:8447. You can login with:

```
Username: root
Password: Skyline2025!
```

Please change the root password, and generate new keypairs for each Wireguard peer as well. Leaving the keys as the default values will allow an attacker to decrypt your traffic or possibly impersonate your server. So changing these is required:

#### Generate a new Private Key - Goes into OPNsense UI ####
```wg genkey > private.key```

#### Generate a new Public Key - Goes into your Config File ####
```cat private.key | wg pubkey```

Just ensure the new private key is entered into OPNsense, and the new public key goes into the config file on your own computer. Restart Wireguard and you should be connected with non-default values.

## Step 7 - Access Zoneminder and begin using ##

You can access the Zoneminder Web UI at http://10.0.0.5/zm. From here you can begin adding cameras. Refer to Zoneminder documentation online for information about adding cameras. Just keep in mind the cameras should be set up with their own Wireguard peer configurations with their address set in the 10.10.255.0/24 subnet, and they should be added as a peer in OPNsense as well.

## Future goals ##

Managing multiple Wiregaurd configurations is very unwieldy, it would be nice to use something like Tailscale in a production environment.

I would eventually want to figure out how to generalize the config.xml file for OPNsense with a templating engine like Jinja to avoid leaving default credentials and keys in this project. 
