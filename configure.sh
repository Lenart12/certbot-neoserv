#!/usr/bin/env bash

################################################################################

# Helper script to configure the authenticator for the Neoserv DNS portal
# Run with sudo ./configure.sh and follow the instructions

################################################################################

# Make sure root is running this script
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Read login information
read -p "Enter your domain name: " NEOSERV_DOMAIN
read -p "Enter your email: " NEOSERV_EMAIL
read -sp "Enter your password: " NEOSERV_PASSWORD

# Verify login information
echo ""
echo -n "Verifiying login"
__ENDPOINT="https://moj.neoserv.si"

# Create cookie file
__COOKIE_JAR="/tmp/certbot-neoserv-cookie-$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32).txt"
touch "$__COOKIE_JAR"
chmod 600 "$__COOKIE_JAR"

echo -n "."

# Login
__RESPONSE=$(curl -s -X POST "$__ENDPOINT/prijava/preveri" \
    -F "email=$NEOSERV_EMAIL" \
    -F "password=$NEOSERV_PASSWORD" \
    -w "%{http_code}" \
    -c "$__COOKIE_JAR")

echo -n "."

# Check if login was successful
if [[ "$__RESPONSE" != "302" ]]; then
    echo ""
    echo "Login failed (Username or password is incorrect)"
    rm -f "$__COOKIE_JAR"
    exit 1
fi

# Get list of domains
__RESPONSE=$(curl -s -X GET "$__ENDPOINT/storitve" \
    -w "%{http_code}" \
    -b "$__COOKIE_JAR")

echo -n "."

# Extract domain ID for the given domain
NEOSERV_DOMAIN_ID=$(echo "$__RESPONSE" | tr -d '\t\n\r ' | grep -Po "(?<=\/storitve\/domena\/)([0-9]+)(?=\\\">\.\w+?domena-$NEOSERV_DOMAIN<\/a>)")

# Check if domain was found
if [[ -z "$NEOSERV_DOMAIN_ID" ]]; then
    echo ""
    echo "Domain [$NEOSERV_DOMAIN] not found"
    rm -f "$__COOKIE_JAR"
    exit 1
fi

# Log out
curl -s -X GET "$__ENDPOINT/odjava" -b "$__COOKIE_JAR" > /dev/null

rm -f "$__COOKIE_JAR"

echo ""
echo "Verified credentials for domain [$NEOSERV_DOMAIN ($NEOSERV_DOMAIN_ID)]"

# Save the configuration
CONFIG_FOLDER="/etc/certbot-neoserv"
mkdir -p "$CONFIG_FOLDER"
CONFIG_FILE="$CONFIG_FOLDER/$NEOSERV_DOMAIN.conf"
touch "$CONFIG_FILE"
chmod 600 "$CONFIG_FILE"
cat << EOF > "$CONFIG_FILE"
NEOSERV_DOMAIN="$NEOSERV_DOMAIN"
NEOSERV_DOMAIN_ID="$NEOSERV_DOMAIN_ID"
NEOSERV_EMAIL="$NEOSERV_EMAIL"
NEOSERV_PASSWORD="$NEOSERV_PASSWORD"
EOF

echo "Configuration saved [$CONFIG_FILE]"

SCRIPT_LOCATION=$(dirname "$(readlink -f "$0")")

CERTBOT_COMMAND="certbot certonly --cert-name \"*.wgn.si\" --manual --preferred-challenges dns --manual-auth-hook \"$SCRIPT_LOCATION/authenticator.sh\" --manual-cleanup-hook \"$SCRIPT_LOCATION/cleanup.sh\" -d \"*.$NEOSERV_DOMAIN\""

echo "To create a renewable wildcard certificate for $NEOSERV_DOMAIN, run the following command:"
echo "$CERTBOT_COMMAND"
