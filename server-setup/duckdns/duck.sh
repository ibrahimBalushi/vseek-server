#!/bin/bash

source "$(dirname "$0")/../config/variables.conf"

curl -s "https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip="