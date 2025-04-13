# Skyline VNETs Overview #

Networking in the Skyline cloud environment is accomplished with Azure vnets, or virtual networks. Vnets do a few things:

- Allows resources to communicate with each other and with other devices over the Internet
- Define the private RFC 1918 IP spaces and subnets available to resources
- Define the security rules that resources have to follow when communicating
- Provide extra features such as custom route tables and network monitoring

We can begin by defining an IP space (or multiple) for our vnet. Within those address spaces, we define different subnets to segment our network and apply different security policies to each one. 

## Skyline Address Spaces & subnets ##

Skyline provides a dual-stack IP space for its resources. That is, subnets contain both IPv4 and IPv6 addresses.

| VNET name | IPv4 Addresses | IPv6 Addresses |
| ------------- | -------------- | -------------- |
| SKYNET | 10.0.0.0/16 | fd00:6f08:7be9::/48 |

In Azure, network interfaces on virtual machines are associated with a subnet. Its subnet defines which networks it is allowed to talk to.
We have 2 different subnets available to Skyline NICs:

| Subnet Name | IPv4 | IPv6 | Description |
| ------------- | -------------- | -------------- | -------------- |
| untrusted | 10.0.255.224/27 | fd00:6f08:7be9:ffff::/64 | External network interfaces that must communicate to the Internet. Traffic from this subnet to the trusted is subject to network security policies. |
| trusted | 10.0.0.0/24 | fd00:6f08:7be9::/64 | For network interfaces that are located behind the Skyline gateway (OPNsense). Resources located here are allowed to communicate freely with other trusted resources. |

## Skyline Network Security Groups ##

In Azure, NSGs are access control lists containing security rules that allow or deny inbound traffic to, or outbound traffic from, different resources. We can filter based on source & destination IP, CIDR block, network port numbers and protocols, and so called Service Tags which allow us to use keywords like "Internet" with which we can apply filtering rules.

Traffic is evaluated against each rule in the NSG starting from the lowest priority number. Priorities are numbered between 100 and 4096.
There are 3 default rules in Azure NSGs with priority numbers of 65000, 65001, and 65500.

Azure NSGs are applied to subnets. Alternatively, they can be assigned to a network interface for granular control, however both the parent subnet's nsg and the interface's assigned nsg will both be processed, with the parent subnet's nsg being processed first. Important to note as this behavior can result in conflicting rules. So with 2 subnets we thus have 2 NSGs:

### Untrusted Subnet NSG ###
<table>
    <thead>
        <tr>
            <th>Priority</th>
            <th>Name</th>
            <th>Port</th>
            <th>Protocol</th>
            <th>Source</th>
            <th>Destination</th>
            <th>Action</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td colspan=8>Inbound Rule List</td>
        </tr>
        <tr>
            <td>4095</td> <!-- Priority -->
            <td>Allow-WG-In-IPv4</td> <!-- Name -->
            <td>51820</td> <!-- Port -->
            <td>UDP</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>10.0.255.224/27</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>4096</td> <!-- Priority -->
            <td>Allow-WG-In-IPv6</td> <!-- Name -->
            <td>51820</td> <!-- Port -->
            <td>UDP</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>fd00:6f08:7be9:ffff::/64</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65000</td> <!-- Priority -->
            <td>AllowVnetInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>VirtualNetwork</td> <!-- Source -->
            <td>VirtualNetwork</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65001</td> <!-- Priority -->
            <td>AllowAzureLoadBalancerInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>AzureLoadBalancer</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65500</td> <!-- Priority -->
            <td>DenyAllInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
        </tr>
        <tr>
            <td colspan=8>Outbound Rule List</td>
        </tr>     
        <tr>
            <td>4096</td> <!-- Priority -->
            <td>Deny-InternetOut-Any</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Internet</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
        </tr>
        <tr>
            <td>65000</td> <!-- Priority -->
            <td>AllowVnetOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>VirtualNetwork</td> <!-- Source -->
            <td>VirtualNetwork</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65001</td> <!-- Priority -->
            <td>AllowInternetOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Internet</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65500</td> <!-- Priority -->
            <td>DenyAllOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
        </tr>
    </tbody>
</table>

In the Skyline network, the Untrusted subnet talks to security cameras and NVR users over the Internet. To do this in a secure way, we tunnel the traffic through the company's VPN, which is a Wireguard interface on the OPNsense gateway. So we are only going to allow Wireguard traffic to and from this subnet as a security measure, and nothing else. You'll notice Azure creates a default AllowInternetOutbound rule that allows any traffic to talk to the Internet. Leaving this rule wide open would be a security risk. We are not able to delete this rule, but we can override it with a deny-all rule with a lower priority number, so we will make that rule in our outbound list.

Also important to note is that NSGs in Azure are stateful, so it will not be necessary to duplicate the Wireguard rules in the Inbound list to the Outbound list.



### Trusted Subnet NSG ###
<table>
    <thead>
        <tr>
            <th>Priority</th>
            <th>Name</th>
            <th>Port</th>
            <th>Protocol</th>
            <th>Source</th>
            <th>Destination</th>
            <th>Action</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td colspan=8>Inbound Rule List</td>
        </tr>
        <tr>
            <td>65000</td> <!-- Priority -->
            <td>AllowVnetInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>VirtualNetwork</td> <!-- Source -->
            <td>VirtualNetwork</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65001</td> <!-- Priority -->
            <td>AllowAzureLoadBalancerInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>AzureLoadBalancer</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65500</td> <!-- Priority -->
            <td>DenyAllInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
        </tr>
        <tr>
            <td colspan=8>Outbound Rule List</td>
        </tr>     
        <tr>
            <td>4096</td> <!-- Priority -->
            <td>Deny-InternetOut-Any</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Internet</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
        </tr>
        <tr>
            <td>65000</td> <!-- Priority -->
            <td>AllowVnetOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>VirtualNetwork</td> <!-- Source -->
            <td>VirtualNetwork</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65001</td> <!-- Priority -->
            <td>AllowInternetOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Internet</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
        </tr>
        <tr>
            <td>65500</td> <!-- Priority -->
            <td>DenyAllOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
        </tr>
    </tbody>
</table

The Trusted Subnet only needs to communicate with the Skyline gateway to talk to clients over the Wireguard network. For this reason, the default "AllowVnet" rules will suffice, and we'll block outbound traffic directly to the Internet for good measure.


## Custom Routing Tables ##
In order for hosts on our Trusted subnet to communicate with the Internet via the Skyline gateway, we will need to install custom route tables on those hosts. These can be used to change Azure's default routing. The reason for this is because Azure wants to be able to handle DHCP within subnets. We are not allowed to use a DHCP server to point to our own gateway.

So the way around this is to create a Route Table resource and associate it with the Trusted subnet. The route table contains this entry:

| Route Name | Address Prefix | Next hop type | Next hop IP address |
| ------------- | -------------- | -------------- | -------------- |
| default-route | 0.0.0.0/0 | Virtual appliance | 10.0.0.4 |

In this configuration, we are setting the next-hop address to the "LAN" interface on OPNsense. This way traffic is properly routed through our virtual appliance.



