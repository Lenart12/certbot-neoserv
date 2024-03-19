# Certbot DNS-01 renewal hooks for moj.neoserv.si 

> ## These scrips are not affiliated with or endorsed by Neoserv (AVANT.SI d.o.o.) in any way

## Project Description

This project provides Certbot renewal hooks for DNS-01 challenge for [moj.neoserv.si](moj.neoserv.si). It allows you to automate the process of renewing wildcard SSL certificates using Certbot and the DNS-01 challenge method by providing hooks that will set `_acme-challenge TXT` records and clean them up afterwards.

This repository contains three scripts: `authenticator.sh`, `cleanup.sh`, and `configure.sh`.

- `configure.sh`: This script is used for configuring the credentials for neoserv dns portal. It verifies them and stores them to `/etc/certbot-neoserv` directory.

- `authenticator.sh`: This script is called by Certbot to perform the DNS challenge (if passed to Certbot with --manual-auth-hook)

- `cleanup.sh`: This script is called by Certbot to clean up the DNS challenge (if passed to Certbot with --manual-cleanup-hook)

## Installation and usage

After git cloning (or copy the files) to a permanent directory (such as `/usr/local/share/certbot-neoserv` or `/opt/certbot-neoserv`) run `configure.sh` script to install the required login credentials for the script. Then run the command supplied by the script.

Or manually configure certbot to use hooks in this repo with `certbot certonly --cert-name "*.example.com" --manual --preferred-challenges dns --manual-auth-hook "$SCRIPT_LOCATION/authenticator.sh" --manual-cleanup-hook "$SCRIPT_LOCATION/cleanup.sh" -d "*.example.com"
`

## Dependencies

* certbot (tested with 2.2.0)
* grep with perl regexp (tested with GNU grep 3.6)
* curl (tested with 7.74.0)
* dig (tested with 9.16.44-Debian)
