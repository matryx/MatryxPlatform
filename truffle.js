const fs = require('fs')
const HDWalletProvider = require("truffle-hdwallet-provider")

const { mnemonicPath } = require('./truffle/network')

ethers = require('ethers')
const sha3 = require('solidity-sha3').default // only in context of this file

// SETUP GLOBALS FOR CLI REPL
const utils = require('./truffle/utils')
getMinedTx = utils.getMinedTx
bytesToString = utils.bytesToString
stringToBytes = utils.stringToBytes
stringToBytes32 = utils.stringToBytes32
getFileContents = path => fs.readFileSync(path).toString()
contract = utils.Contract
// contract = (address, { abi }) => new ethers.Contract(address, abi, wallet)
selector = signature => sha3(signature).substr(0, 10)
getTx = hash => wallet.provider.getTransaction(hash)
getTxR = hash => wallet.provider.getTransactionReceipt(hash)

// wallet key from ganache
// wallet = new ethers.Wallet('0x' + '2c22c05cb1417cbd17c57c1bd0f50142d8d7884984e07b2d272c24c6e120a9ea')
// wallet.provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')

network = require('./truffle/network')
wallet = new ethers.Wallet(network.privateKeys[0], network.provider)

console.log('Setup to copy paste:\n')
console.log('platform = contract(MatryxPlatform.address, MatryxPlatform);0')
console.log('token = contract(network.tokenAddress, MatryxToken);0\n')

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // match any network
      gas: 6541593,
      gasPrice: 30000000
    },
    ropsten: {
      provider: function () {
        return new HDWalletProvider(getFileContents(mnemonicPath), "https://ropsten.infura.io/metamask")
      },
      network_id: 3,
      gas: 5800000
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
