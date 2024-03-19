#!/usr/bin/env -S bash -e

# This script is called by Certbot to perform the DNS challenge (if passed to Certbot with --manual-auth-hook)
# It is called with the following environment variables:
# CERTBOT_DOMAIN: The domain being authenticated
# CERTBOT_VALIDATION: The validation string
# CERTBOT_TOKEN: Resource name part of the HTTP-01 challenge (HTTP-01 only)
# CERTBOT_REMAINING_CHALLENGES: Number of challenges remaining after the current challenge
# CERTBOT_ALL_DOMAINS: A comma-separated list of all domains challenged for the current certificate

# echo "CERTBOT_DOMAIN: $CERTBOT_DOMAIN"
# echo "CERTBOT_VALIDATION: $CERTBOT_VALIDATION"
# echo "CERTBOT_TOKEN: $CERTBOT_TOKEN"
# echo "CERTBOT_REMAINING_CHALLENGES: $CERTBOT_REMAINING_CHALLENGES"
# echo "CERTBOT_ALL_DOMAINS: $CERTBOT_ALL_DOMAINS"

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

# Check if email is set
if [ -z "$NEOSERV_EMAIL" ]; then
    echo "Email not set"
    exit 1
fi

# Check if password is set
if [ -z "$NEOSERV_PASSWORD" ]; then
    echo "Password not set"
    exit 1
fi

# echo "Verified credentials for domain [$NEOSERV_DOMAIN ($NEOSERV_DOMAIN_ID)]"

# Create cookie file
TMP_FOLDER="/tmp/certbot-neoserv"
mkdir -p "$TMP_FOLDER"
__COOKIE_JAR="$TMP_FOLDER/renew-$CERTBOT_DOMAIN-cookie.txt"
touch "$__COOKIE_JAR"
chmod 600 "$__COOKIE_JAR"

# echo "Created cookie file: $__COOKIE_JAR"

# Login
__ENDPOINT="https://moj.neoserv.si"
__RESPONSE=$(curl -s -X POST "$__ENDPOINT/prijava/preveri" \
    -F "email=$NEOSERV_EMAIL" \
    -F "password=$NEOSERV_PASSWORD" \
    -w "%{http_code}" \
    -c "$__COOKIE_JAR")

# Check if login was successful
if [[ "$__RESPONSE" != "302" ]]; then
    echo "Login failed (Username or password is incorrect)"
    rm -f "$__COOKIE_JAR"
    exit 1
fi

# echo "Logged in"

# Create DNS record
curl -s -X POST "$__ENDPOINT/storitve/domena/shranidnszapis" \
    -F "record[type]=TXT" \
    -F "record[host]=_acme-challenge" \
    -F "record[cart_id]=$NEOSERV_DOMAIN_ID" \
    -F "record[ttl]=60" \
    -F "record[priority]=10" \
    -F "record[weight]=0" \
    -F "record[port]=0" \
    -F "record[caa_flag]=0" \
    -F "record[caa_type]=issue" \
    -F "record[caa_value]=;" \
    -F "record[record]=$CERTBOT_VALIDATION" \
    -b "$__COOKIE_JAR" > /dev/null

# echo "Created DNS record"

# Wait for DNS record to propagate
DOMAIN_NS=$(dig +short NS $CERTBOT_DOMAIN | head -n 1)
TIMEOUT=60 # 60 seconds
while [ $TIMEOUT -gt 0 ]; do
    # echo "Waiting for DNS record to propagate ($TIMEOUT seconds remaining)"
    sleep 2
    TIMEOUT=$((TIMEOUT-2))
    __RESPONSE=$(dig @$DOMAIN_NS +short TXT _acme-challenge.$CERTBOT_DOMAIN)
    if [[ "$__RESPONSE" == "\"$CERTBOT_VALIDATION\"" ]]; then
        # echo "DNS record propagated"
        break
    fi
done

# Wait some more, just in case
sleep 5
