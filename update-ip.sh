#!/bin/sh

set -euo pipefail

# Updates the DNS record of your domain registered on GoDaddy to the current IP assigned to your internet connection.
# Inspired by https://uk.godaddy.com/community/Managing-Domains/Dynamic-DNS-Updates/td-p/7862.
#
# Automatically verifies that the DNS record has been updated successfully.
# Returns:
# - exit code 0: success
# - exit code 1: any failure that prevented the DNS record to be updated
#
# Setup:
# - Go to https://developer.godaddy.com/getstarted and create a developer account.
# - Get valid **production** credentials (a KEY and a SECRET) to access the API.
#   Do not select testing, otherwise changes are not exposed.
# - Provide environment variable as described below, feel free to customize defaults.
#
# Expected environment variables, with some defaults:
#
# DOMAIN                # domain name you want to update, e.g., "example.com"
TYPE=${TYPE:-"A"}       # record type, e.g., "A"
NAME=${NAME:-"@"}       # name of the record to update, e.g., "@"
TTL=${TTL:-"1800"}      # time to live, seconds, e.g., "1800"
PORT=${PORT:-"1"}       # required port, e.g., "1"
WEIGHT=${WEIGHT:-"1"}   # required weight, e.g., "1"
# KEY                   # KEY for accessing GoDaddy developer API
# SECRET                # SECRET for the above KEY
PHASE=${PHASE:-"0"}     # initial sleep before script execution
                        #   useful for shifting phase in case of multiple script executing
                        #   at the same time
#
# usually no need to modify beyond this point
#
[ "$(id -u)" -eq 0 ] && echo "Please run without root priviledges." && exit 1

sleep "${PHASE}"

# get IP currently assigned to the selected DNS record
get_dns_ip() {
      RET=$(${CURL} -s -X GET -H "${HEADER}" "https://api.godaddy.com/v1/domains/${DOMAIN}/records/${TYPE}/${NAME}")
      DNS_IP=$(echo "${RET}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
}

CURL="curl --silent -m 30" # set timeout for each curl call to 30s
HEADER="Authorization: sso-key $KEY:$SECRET"

# get current public IP address
RET=$(${CURL} -s GET "http://ipinfo.io/json")
ISP_IP=$(echo "${RET}" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

get_dns_ip
if [ "${DNS_IP}" != "${ISP_IP}" ]; then
      echo "DNS IP: ${DNS_IP}, ISP IP: $ISP_IP. Updating DNS record..."
      ${CURL} -X PUT "https://api.godaddy.com/v1/domains/${DOMAIN}/records/${TYPE}/${NAME}" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -H "${HEADER}" \
            -d "[ { \"data\": \"${ISP_IP}\", \"port\": ${PORT}, \"priority\": 0, \"protocol\": \"string\", \"service\": \"string\", \"ttl\": ${TTL}, \"weight\": ${WEIGHT} } ]"

      # make sure IP has been really updated
      get_dns_ip
      [ "${DNS_IP}" != "${ISP_IP}" ] && echo "FAILURE! IP has NOT been updated." && exit 1

elif [ -z "${DNS_IP}" ] | [ -z "${ISP_IP}" ]; then
      echo "FAILURE! Unable to read current status (DNS IP: \"${DNS_IP}\", ISP IP: \"$ISP_IP\")"
      exit 1
fi
echo "OK"