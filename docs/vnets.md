#Azure VNETs Overview

Networking in Azure is accomplished with vnets, or virtual networks. Vnets do a few things:

- Allows resources to communicate with each other and with other devices over the Internet
- Define the private RFC 1918 IP spaces and subnets available to resources
- Define the security rules that resources have to follow when communicating
- Provide extra features such as custom route tables and network monitoring

We can begin by defining an IP space (or multiple) for our vnet. Within those address spaces, we define different subnets to segment our network and apply different security policies to each one. 

##Skyline Address Spaces & subnets

Skyline provides a dual-stack IP space for its resources. That is, subnets contain both IPv4 and IPv6 addresses.

| VNET name | IPv4 Addresses | IPv6 Addresses |
| ------------- | -------------- | -------------- |
| SKYNET | 10.0.0.0/16 | fd00:6f08:7be9::/48 |

In Azure, network interfaces on virtual machines are associated with a subnet. Its subnet defines which networks it is allowed to talk to.
We have 3 different subnets available to Skyline NICs:

| Subnet Name | IPv4 | IPv6 | Description |
| ------------- | -------------- | -------------- | -------------- |
| untrusted | 10.0.255.224/27 | fd00:6f08:7be9:ffff::/64 | External network interfaces that must communicate to the Internet. Traffic from this subnet to the trusted is subject to network security policies. |
| trusted | 10.0.0.0/24 | fd00:6f08:7be9::/64 | For network interfaces that are located behind the Skyline gateway (OPNsense). Resources located here are allowed to communicate freely with other trusted resources. |
| management | 10.0.100.0/27 | fd00:6f08:7be9:ff::/64 | Separate management subnet used by IT admins. Has its own public IP. Traffic from this subnet is granted increased access to trusted subnet resources for management purposes, so must be subject to increased monitoring and access control. |

##Skyline Network Security Groups

In Azure, NSGs are access control lists containing security rules that allow or deny inbound traffic to, or outbound traffic from, different resources. We can filter based on source & destination IP, CIDR block, and network protocol.
Traffic is evaluated against each rule in the NSG starting from the lowest priority number. Priorities are numbered between 100 and 4096.
There are 3 default rules in Azure NSGs with priority numbers of 65000, 65001, and 65500. We should leave them as is.
For example, an insecure NSG that allows all traffic to and from this subnet would look like this:

| Priority | Name | Port | Protocol | Source |  Destination | Action | Description |
| --------------- | --------------- | --------------- | --------------- | --------------- | --------------- | --------------- | --------------- |
| Inbound Security Rules ||||||||
| 4096 | In-Any | Any | Any | Any | Any | ✔️ Allow | Allows all inbound traffic |
| 65000 | AllowVnetInBound | Any | Any | VirtualNetwork | VirtualNetwork | ✔️ Allow | Default allow traffic from another vnet |
| 65001 | AllowAzureLoadBalancerInBound | Any | Any | AzureLoadBalancer | Any | ✔️ Allow | Default allow traffic from AzureLoadBalancer |
| 65500 | DenyAllInBound | Any | Any  Any | Any | ❌ Deny | Default deny NSG rule |

We add in our rules above the 4096 entry to create our NSGs.

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
            <th>Description</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td colspan=8>Inbound Rule List</td>
        </tr>
        <tr>
            <td>4096</td> <!-- Priority -->
            <td>In-Any</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
            <td>Allows any inbound traffic from this subnet</td> <!-- Description -->
        </tr>
        <tr>
            <td>65000</td> <!-- Priority -->
            <td>AllowVnetInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>VirtualNetwork</td> <!-- Source -->
            <td>VirtualNetwork</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
            <td>Default Allow traffic from another vnet</td> <!-- Description -->
        </tr>
        <tr>
            <td>65001</td> <!-- Priority -->
            <td>AllowAzureLoadBalancerInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>AzureLoadBalancer</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
            <td>Default allow traffic from AzureLoadBalancer</td> <!-- Description -->
        </tr>
        <tr>
            <td>65500</td> <!-- Priority -->
            <td>DenyAllInBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
            <td>Default Deny inbound traffic</td> <!-- Description -->
        </tr>
        <tr>
            <td colspan=8>Outbound Rule List</td>
        </tr>
        <tr>
            <td>4096</td> <!-- Priority -->
            <td>Out-Any</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
            <td>Allows any outbound traffic from this subnet</td> <!-- Description -->
        </tr>
        <tr>
            <td>65000</td> <!-- Priority -->
            <td>AllowVnetOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>VirtualNetwork</td> <!-- Source -->
            <td>VirtualNetwork</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
            <td>Default Allow traffic to another vnet</td> <!-- Description -->
        </tr>
        <tr>
            <td>65001</td> <!-- Priority -->
            <td>AllowInternetOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Internet</td> <!-- Destination -->
            <td>✔️ Allow</td> <!-- Action -->
            <td>Default allow traffic from this subnet to talk to the Internet</td> <!-- Description -->
        </tr>
        <tr>
            <td>65500</td> <!-- Priority -->
            <td>DenyAllOutBound</td> <!-- Name -->
            <td>Any</td> <!-- Port -->
            <td>Any</td> <!-- Protocol -->
            <td>Any</td> <!-- Source -->
            <td>Any</td> <!-- Destination -->
            <td>❌ Deny</td> <!-- Action -->
            <td>Default Deny outbound traffic</td> <!-- Description -->
        </tr>
    </tbody>
</table>
