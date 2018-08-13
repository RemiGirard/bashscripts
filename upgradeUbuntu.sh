#!/bin/bash
apt update
apt -y upgrade
apt -y dist-upgrade
apt clean
apt -y autoremove

rm /usr/share/applications/ubuntu-amazon-default.desktop
rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/Amazon.user.js
rm /usr/share/unity-webapps/userscripts/unity-webapps-amazon/manifest.json
