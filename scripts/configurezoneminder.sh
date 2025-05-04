#!/bin/sh

# Script Params
# $1 - Zoneminder Database Username.
# $2 - Zoneminder Database Password. TODO find and clean stdout/stderr/other logs that would show this pass in the clear
# $3 - The version of the Azure Linux Agent to install
# $4 - Github API Token to download files
# $5 - Azure Linux Agent Actions config file name

cat "Deploy Success!" > /home/zmadmin/success.txt
