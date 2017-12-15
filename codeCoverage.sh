#!/usr/bin/env bash
rm -rf ./build
rm -rf ./coverage

# Make sure you have solidity-coverage
# >npm install --save-dev solidity-coverage

./node_modules/.bin/solidity-coverage

cd coverage
open index.html
