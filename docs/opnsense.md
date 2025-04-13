# OPNsense Overview #

OPNsense is an all-in-one network security appliance. In the Skyline network, it acts as a router and a firewall, and comes with Wireguard as a VPN solution and Suricata for network intrusion detection (NIDS).

## Skyline Network Gateway ##

We deploy OPNsense as a virtual machine in Azure to allow routing between our cloud-hosted NVR and on-site IP security cameras. It also allows authorized users to access the NVR for playback of footage, and IT admins the ability to remotely manage the network.


Through testing, we have found the best balance between cost and performance for the VM's configuration to be the following:

<OPN VM configuration here>

## Firewall Ruleset ##

## Wireguard VPN ##

## Network Intrusion Detection ##

## Remote Management ##