#!/bin/sh

# Script Params
# $1 = OPNScriptURI - path to the github repo which contains the config files and scripts - needs to end with '/'
# $2 = OpnVersion
# $3 = WALinuxVersion
# $4 = github token to download files from the private repo
# $5 = file name of the OPNsense config file, default config.xml
# $6 = file name of the waagent actions configuration file, default waagent_actions.conf

# install necessary utilities
pkg install -y python3

# download the OPNsense config.xml 
curl -H "Authorization: Bearer $4" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$5"

# Drop the config file into the correct directory to finish configuration
cp $5 /usr/local/etc/config.xml

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
curl -H "Authorization: Bearer $4" \
    -H 'Accept: application/vnd.github.v3.raw' \
    -O \
    -L "$1$6"
# make a link to python3 binary, disable disk swap, and set the actions configuration
ln -s /usr/local/bin/python3.11 /usr/local/bin/python
sed -i "" 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/' /etc/waagent.conf
cp $6 /usr/local/opnsense/service/conf/actions.d

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