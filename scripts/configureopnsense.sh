#!/bin/sh

# Script Params
# $1 = OPNScriptURI - path to the github repo which contains the config files and scripts - needs to end with '/'
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = Trusted Nic IP Address
# $5 = github token to download files from the private repo
# $6 = file name of the OPNsense config file, default config.xml
# $7 = file name of the python script to find gateway, default get_nic_gw.py
# $8 = file name of the waagent actions configuration file, default waagent_actions.conf
# $9 = file name of the opnsense jinja2 template
# $10 = file name of the opnsense j2 template variables.yml file
# $11 = file name of the opnsense config.xml generation script
# $12 = the wireguard private key, used to configure the wireguard server

# install necessary utilities
pkg install -y python3 wireguard-tools ipcalc

# install pip, config.xml.generate.py dependencies
python -m ensurepip --upgrade
pip3 install pyyaml jinja2

# download the OPNsense config.xml 
# deprecated soon, use j2 template
curl -H "Authorization: Bearer $5" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$6"
# download the python gateway detector script
curl -H "Authorization: Bearer $5" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$7"
# download the opnsense j2 template
curl -H "Authorization: Bearer $5" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$9"
# download the opnsense yaml definitions
curl -H "Authorization: Bearer $5" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$10"
# download the opnsense config.xml generation script
curl -H "Authorization: Bearer $5" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$11"

# Set OPNsense config.xml values
# this process will be deprecated soon, use the j2 template instead.
#gatewayIp=$(python3 get_nic_gw.py $4) 
#sed -i "" "s/yyy.yyy.yyy.yyy/$4/" $6 #sets the ip address of the lan interface
#sed -i "" "s_zzz.zzz.zzz.zzz_$5_" $6   #sets the alias for management subnet, no longer needed


# Configuring OPNsense

# Sets the Wireguard server configuration in the yml config file (pub and priv keys)
wgServerPubkey=$(printf $12 | wg pubkey)
sed -i "" "s/WireguardServerPrivateKeyHere/$12/" $10
sed -i "" "s/WireguardServerPublicKeyHere/$wgServerPubkey/" $10

# Sets the Wireguard initial peer configuration in the yml config file
sed -i "" "s/WireguardPeerPublicKeyHere/$13/" $10

# Sets the LAN interface settings in the yml config file
#LAN_ADDRESS=$(ipcalc $4 | grep Address | cut -d ' ' -f 4)
#sed -i "" "s/LanIPv4AddressHere/$LAN_ADDRESS/" $10
#LAN_SUBNET_MASK=$(ipcalc $4 | grep Netmask | cut -d ' ' -f 4)
#sed -i "" "s/LanSubnetMaskHere/$LAN_SUBNET_MASK/" $10
# Render the config template to config.xml
python $11 $9

# Drop the rendered config file into the correct directory to finish configuration
cp $6 /usr/local/etc/config.xml

#Download OPNSense Bootstrap and Permit Root Remote Login
fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

#OPNSense
# Due to a recent change in pkg the following commands no longer finish with status code 0
#		pkg unlock -a
#		pkg delete -fa
# comment out the 'set -e' line to prevent script halt when these commands return 1
# also change from instant reboot at the end to a 5 minute timer
sed -i "" "s/set -e/#set -e/g" opnsense-bootstrap.sh.in
sed -i "" "s/reboot/shutdown -r +5/g" opnsense-bootstrap.sh.in
sh ./opnsense-bootstrap.sh.in -y -r "$2"

# Add Azure waagent
fetch https://github.com/Azure/WALinuxAgent/archive/refs/tags/v$3.tar.gz
tar -xvzf v$3.tar.gz
cd WALinuxAgent-$3/
python3 setup.py install --register-service --lnx-distro=freebsd --force
cd ..

# Download the actions configuration
curl -H "Authorization: Bearer $5" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$8"
# make a link to python3 binary, disable disk swap, and set the actions configuration
ln -s /usr/local/bin/python3.11 /usr/local/bin/python
sed -i "" 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/' /etc/waagent.conf
cp $8 /usr/local/opnsense/service/conf/actions.d

# Installing bash - This is a requirement for Azure custom Script extension to run
pkg install -y bash
pkg install -y os-frr

# Remove wrong route at initialization
cat > /usr/local/etc/rc.syshook.d/start/22-remoteroute <<EOL
#!/bin/sh
route delete 168.63.129.16
EOL
chmod +x /usr/local/etc/rc.syshook.d/start/22-remoteroute

# Reset WebGUI certificate
echo #\!/bin/sh >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo configctl webgui restart renew >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
echo rm /usr/local/etc/rc.syshook.d/start/94-restartwebgui >> /usr/local/etc/rc.syshook.d/start/94-restartwebgui
chmod +x /usr/local/etc/rc.syshook.d/start/94-restartwebgui