var MatryxProxy = artifacts.require('MatryxProxy')
var MatryxPlatform = artifacts.require('MatryxPlatform')
var LibPlatform = artifacts.require('LibPlatform')
var LibTest = artifacts.require('LibTest')

module.exports = function(deployer) {
  deployer.deploy(MatryxPlatform, MatryxProxy.address, '1')
  deployer.deploy(LibPlatform)
  deployer.deploy(LibTest)
}
