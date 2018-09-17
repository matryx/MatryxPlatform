var MatryxProxy = artifacts.require('MatryxProxy')
var MatryxPlatform = artifacts.require('MatryxPlatform')
var network = require('../truffle/network')

module.exports = function (deployer) {
  deployer.deploy(MatryxPlatform, MatryxProxy.address, '1', network.tokenAddress)
}
