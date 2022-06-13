#!/bin/bash

# Separate config vars with dash in a single env-var
IFS=- read key secret appID cluster <<< $PUSHER_CLIPBOARD

timestamp=$(date +%s)
data='{"data":"'$(cat | awk -v ORS='\\n' '1' | sed -z '$ s/\\n$//')'","name":"clipboard","channel":"clipboard"}'
md5data=$(printf '%s' "$data" | md5sum | awk '{ print $1 }')

path="/apps/${appID}/events"
queryString="auth_key=${key}&auth_timestamp=${timestamp}&auth_version=1.0&body_md5=${md5data}"

authSig=$(printf '%s' "POST
$path
$queryString" | openssl dgst -sha256 -hex -hmac "$secret" | awk '{ print $2 }')
curl -H "Content-Type: application/json" --data-binary "$data" "https://api-${cluster}.pusher.com${path}?${queryString}&auth_signature=${authSig}"