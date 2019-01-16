var MatryxSystem = artifacts.require('MatryxSystem')
var MatryxPlatform = artifacts.require('MatryxPlatform')
var network = require('../truffle/network')

module.exports = function (deployer) {
  deployer.deploy(MatryxPlatform, MatryxSystem.address, network.tokenAddress, { gas: 8e6, overwrite: false })
}
