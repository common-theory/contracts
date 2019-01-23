#!/bin/sh

# Deploys coverage reports to coverage.commontheory.io

set -e

# Intended to be run in a CI environment
if [ -z "$CI" ];
then
  echo 'Non-ci environment detected, exiting'
  exit 1
fi

COVERAGE_DIR=$(pwd)/coverage

if [ ! -d $COVERAGE_DIR ];
then
  echo 'Unable to find coverage reports'
  exit 1
fi

# Install jsipfs
npm i -g ipfs

# Start a local IPFS node
jsipfs init
jsipfs daemon &
sleep 10

DOMAIN=coverage.commontheory.io
CIDHOOKD_URL=cidhookd.commontheory.io

# Load the old CID based on the current dnslinked value
OLD_CID=$(npx dnslink resolve $DOMAIN)

# Load the new CID by adding it to the local IPFS node
NEW_CID=$(jsipfs add -Qr $COVERAGE_DIR)

# Unpin the old version
npx cidhook $CIDHOOKD_URL $OLD_CID unpin

# Pin the new version
npx cidhook $CIDHOOKD_URL $NEW_CID

# Update the DNS record
npx dnslink update $DOMAIN $NEW_CID

wget $DOMAIN
