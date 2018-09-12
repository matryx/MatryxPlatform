const fs = require('fs')
const Web3 = require('web3')
const HDWalletProvider = require("truffle-hdwallet-provider")

ethers = require('ethers')
network = require('./truffle/network')

// SETUP GLOBALS FOR CLI REPL
const utils = require('./truffle/utils')
getMinedTx = utils.getMinedTx
bytesToString = utils.bytesToString
stringToBytes = utils.stringToBytes
stringToBytes32 = utils.stringToBytes32
contract = utils.Contract

keccak = str => '0x' + ethUtil.keccak(str).hexSlice(0)
selector = signature => keccak(signature).substr(0, 10)
getFileContents = path => fs.readFileSync(path).toString()

getTx = hash => wallet.provider.getTransaction(hash)
getTxR = hash => wallet.provider.getTransactionReceipt(hash)

hex = dec => '0x' + dec.toString(16)
dec = hex => parseInt(hex, 16)

fromWei = wei => +ethers.utils.formatEther(wei.toString())
toWei = eth => ethers.utils.parseEther(eth.toString())

console.log('Setup to copy paste:\n')
console.log('platform = contract(MatryxPlatform.address, MatryxPlatform);0')
console.log('token = contract(network.tokenAddress, MatryxToken);0\n')

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
      gas: 6541593,
      gasPrice: 30000000
    },
    ropsten: {
      provider: function () {
        network.setNetwork('ropsten')
        wallet = new ethers.Wallet(network.privateKeys[0], network.provider)
        const mnemonic = getFileContents(network.mnemonicPath)
        return new HDWalletProvider(mnemonic, "https://ropsten.infura.io/metamask")
      },
      network_id: 3,
      gas: 4500000
    },
    testing: {
      host: "localhost",
      port: 8545,
      network_id: "*", // match any network
      gas: 6741593,
      gasPrice: 30000000
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
