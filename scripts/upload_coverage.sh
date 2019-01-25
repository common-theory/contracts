#!/bin/sh

# Deploys coverage reports to coverage.commontheory.io

set -e

# Load from .env
set -o allexport
[ -f .env ] && source .env
set +o allexport

COVERAGE_DIR=$(pwd)/coverage

if [ ! -d $COVERAGE_DIR ];
then
  echo 'Unable to find coverage reports'
  exit 1
fi

# Start a local IPFS node
jsipfs daemon &
sleep 10
JSPID=$!

# Check that the process is up
ps -ax | grep $JSPID | grep -v grep > /dev/null

DOMAIN=coverage.commontheory.io
CIDHOOKD_URL=cidhookd.commontheory.io

# Load the old CID based on the current dnslinked value
OLD_CID=$(npx dnslink resolve $DOMAIN)

# Load the new CID by adding it to the local IPFS node
NEW_CID=$(jsipfs add -Qr $COVERAGE_DIR)

# Unpin the old version
npx cidhook unpin $OLD_CID -s $CIDHOOKD_URL

# Pin the new version
npx cidhook pin $NEW_CID -s $CIDHOOKD_URL

# Update the DNS record
npx dnslink update $DOMAIN $NEW_CID

curl $DOMAIN > /dev/null 2> /dev/null

kill $JSPID
