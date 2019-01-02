#!/bin/sh

set -e

# More info here: https://github.com/sc-forks/solidity-parser/pull/18
wget -O $(pwd)/node_modules/solidity-parser-sc/build/parser.js https://raw.githubusercontent.com/maxsam4/solidity-parser/solidity-0.5/build/parser.js
