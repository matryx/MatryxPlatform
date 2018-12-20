const fs = require('fs')
const Web3 = require('web3')
const HDWalletProvider = require("truffle-hdwallet-provider")

ethers = require('ethers')
network = require('./truffle/network')

// SETUP GLOBALS FOR CLI REPL
const utils = require('./truffle/utils')
getMinedTx = utils.getMinedTx
bts = bytesToString = utils.bytesToString
ntb = numberToBytes = utils.numberToBytes
stb = stringToBytes = utils.stringToBytes
contract = utils.Contract

keccak = str => '0x' + ethUtil.keccak(str).hexSlice(0)
selector = signature => keccak(signature).substr(0, 10)

gt = getTx = hash => wallet.provider.getTransaction(hash)
gtr = getTxR = hash => wallet.provider.getTransactionReceipt(hash)

hex = dec => '0x' + dec.toString(16)
dec = hex => parseInt(hex, 16)

fromWei = wei => +ethers.utils.formatEther(wei.toString())
toWei = eth => ethers.utils.parseEther(eth.toString())

network.setNetwork('develop')

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      provider: function () {
        network.setNetwork('ganache')
        wallet = new ethers.Wallet(network.privateKeys[0], network.provider)
        return new Web3.providers.HttpProvider('http://localhost:8545')
      },
      network_id: "*", // match any network
      gas: 8e6,
      gasPrice: 5e9
    },
    ropsten: {
      provider: function () {
        network.setNetwork('ropsten')
        wallet = new ethers.Wallet(network.privateKeys[0], network.provider)
        return new HDWalletProvider(network.mnemonic, "https://ropsten.infura.io/metamask")
      },
      network_id: 3,
      gas: 8e6,
      gasPrice: 5e9
    },
    kovan: {
      provider: function () {
        network.setNetwork('kovan')
        wallet = new ethers.Wallet(network.privateKeys[0], network.provider)
        return new HDWalletProvider(network.mnemonic, "https://kovan.infura.io/metamask")
      },
      network_id: 42,
      gas: 8e6,
      gasPrice: 5e9 // 5 gwei
    },
    testing: {
      host: "localhost",
      port: 8545,
      network_id: "*", // match any network
      gas: 8e6,
      gasPrice: 5e9
    },
    coverage: {
      host: "localhost",
      network_id: "*",
      port: 8545,     // <-- If you change this, also set the port option in .solcover.js.
      gas: 9000000000, // <-- Use this high gas value
      gasPrice: 100000     // <-- Use this low gas price
    }
  },
  mocha: {
    enableTimeouts: false
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 4000
    }
  }
}
