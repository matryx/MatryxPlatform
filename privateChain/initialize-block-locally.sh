#!/usr/bin/env bash
sudo geth \
    --identity "MatryxTestNode" \
    init \
    --datadir "~/Library/Ethereum/Matryx" \
    "./MatryxGenesis.json" \
    --ipcdisable \
    --rpc --rpcport "8545" --rpccorsdomain "*" \
    --ipcapi "admin,db,eth,debug,miner,net,shh,txpool,personal,web3" \
    --rpcapi "db,eth,net,web3,personal" \
    --autodag \
    --networkid 628799 \
    --nat "any" \
    --gasprice "3000000"