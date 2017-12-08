#!/usr/bin/env bash
rm -rf ./build
truffle compile
truffle test --network testrpc