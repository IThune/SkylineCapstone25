#!/bin/sh

# Script Params
# $1 = OPNScriptURI - path to the github repo which contains the config files and scripts - needs to end with '/'
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = Trusted Nic subnet prefix - used to get the gateway for trusted subnet
# $5 = Management subnet prefix - used to route/nat allow internet access from Management VM
# $6 = github token to download files from the private repo
# $7 = file name of the OPNsense config file, default config.xml
# $8 = file name of the python script to find gateway, default get_nic_gw.py
# $9 = file name of the waagent actions configuration file, default waagent_actions.conf

# install curl to download files from github easier
pkg install -y curl
# install python3
pkg install -y python3

# download the OPNsense config.xml 
curl -H "Authorization: Bearer $6" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$7"
# download the python gateway detector script
curl -H "Authorization: Bearer $6" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$8"

# Set OPNsense config.xml values
gatewayIp=$(python3 get_nic_gw.py $4)
sed -i "" "s/yyy.yyy.yyy.yyy/$gatewayIp/" $7 
sed -i "" "s_zzz.zzz.zzz.zzz_$5_" $7
cp $7 /usr/local/etc/config.xml

#Download OPNSense Bootstrap and Permit Root Remote Login
# fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
#fetch https://raw.githubusercontent.com/opnsense/update/7ba940e0d57ece480540c4fd79e9d99a87f222c8/src/bootstrap/opnsense-bootstrap.sh.in
fetch https://raw.githubusercontent.com/opnsense/update/master/src/bootstrap/opnsense-bootstrap.sh.in
sed -i "" 's/#PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config

#OPNSense
# Due to a recent change in pkg the following commands no longer finish with status code 0
#		pkg unlock -a
#		pkg delete -fa
# comment out the 'set -e' line to prevent script halt when these commands return 1
# also change from instant reboot at the end to a 1 minute timer
sed -i "" "s/set -e/#set -e/g" opnsense-bootstrap.sh.in
sed -i "" "s/reboot/shutdown -r +1/g" opnsense-bootstrap.sh.in
sh ./opnsense-bootstrap.sh.in -y -r "$2"

# Add Azure waagent
fetch https://github.com/Azure/WALinuxAgent/archive/refs/tags/v$3.tar.gz
tar -xvzf v$3.tar.gz
cd WALinuxAgent-$3/
python3 setup.py install --register-service --lnx-distro=freebsd --force
cd ..

# Download the actions configuration
curl -H "Authorization: Bearer $6" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$8"
# make a link to python3 binary, disable disk swap, and set the actions configuration
ln -s /usr/local/bin/python3.11 /usr/local/bin/python
sed -i "" 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/' /etc/waagent.conf
fetch $1actions_waagent.conf
cp actions_waagent.conf /usr/local/opnsense/service/conf/actions.d

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