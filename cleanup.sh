#!/usr/bin/env bash

# This script is called by Certbot to clean up the DNS challenge (if passed to Certbot with --manual-cleanup-hook)
# It is called with the following environment variables:
# CERTBOT_DOMAIN: The domain being authenticated
# CERTBOT_VALIDATION: The validation string
# CERTBOT_TOKEN: Resource name part of the HTTP-01 challenge (HTTP-01 only)
# CERTBOT_REMAINING_CHALLENGES: Number of challenges remaining after the current challenge
# CERTBOT_ALL_DOMAINS: A comma-separated list of all domains challenged for the current certificate
# CERTBOT_AUTH_OUTPUT: The output from the auth script (if any)

# echo "CERTBOT_DOMAIN: $CERTBOT_DOMAIN"
# echo "CERTBOT_VALIDATION: $CERTBOT_VALIDATION"
# echo "CERTBOT_TOKEN: $CERTBOT_TOKEN"
# echo "CERTBOT_REMAINING_CHALLENGES: $CERTBOT_REMAINING_CHALLENGES"
# echo "CERTBOT_ALL_DOMAINS: $CERTBOT_ALL_DOMAINS"

TMP_FOLDER="/tmp/certbot-neoserv"
__COOKIE_JAR="$TMP_FOLDER/renew-$CERTBOT_DOMAIN-cookie.txt"

# If no session cookie is found, exit
if ! [ -f "$__COOKIE_JAR" ]; then
    exit 0
fi

CONFIG_FOLDER="/etc/certbot-neoserv"
CONFIG_FILE="$CONFIG_FOLDER/$CERTBOT_DOMAIN.conf"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file for $CERTBOT_DOMAIN not found"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Check that domain matches
if [ "$NEOSERV_DOMAIN" != "$CERTBOT_DOMAIN" ]; then
    echo "Domain mismatch: $NEOSERV_DOMAIN != $CERTBOT_DOMAIN"
    exit 1
fi

# Check if domain ID is set
if [ -z "$NEOSERV_DOMAIN_ID" ]; then
    echo "Domain ID not set"
    exit 1
fi

__ENDPOINT="https://moj.neoserv.si"

# Get list of domains
__RESPONSE=$(curl -s -X GET "$__ENDPOINT/storitve/domena/dns/$NEOSERV_DOMAIN_ID" \
    -b "$__COOKIE_JAR")

# Extract _acme-challenge record ID(s)
CHALLENGE_RECORDS=$(echo "$__RESPONSE" | tr -d '\r\t\n ' | grep -Po "(_acme-challenge.+?odstranizapis\/\d+)(?=\/$NEOSERV_DOMAIN_ID)" | grep -Po "\d+$")
# echo "CHALLENGE_RECORDS: $CHALLENGE_RECORDS"

for CHALLENGE_RECORD in $CHALLENGE_RECORDS; do
    # Remove _acme-challenge record
    __RESPONSE=$(curl -s -X GET "$__ENDPOINT/storitve/domena/odstranizapis/$CHALLENGE_RECORD/$NEOSERV_DOMAIN_ID" \
       -b "$__COOKIE_JAR")
    # echo "Removed _acme-challenge record: $CHALLENGE_RECORD"
done

# Log out
curl -s -X GET "$__ENDPOINT/odjava" -b "$__COOKIE_JAR" > /dev/null
# echo "Logged out"

rm -f "$__COOKIE_JAR"
