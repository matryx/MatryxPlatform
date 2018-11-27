var MatryxSystem = artifacts.require('MatryxSystem')
var MatryxPlatform = artifacts.require('MatryxPlatform')
var network = require('../truffle/network')

module.exports = function (deployer) {
  deployer.deploy(MatryxPlatform, MatryxSystem.address, network.tokenAddress, { overwrite: false })
}
