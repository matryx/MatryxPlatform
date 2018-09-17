var MatryxProxy = artifacts.require('MatryxProxy')
var MatryxPlatform = artifacts.require('MatryxPlatform')

module.exports = function (deployer) {
  deployer.deploy(MatryxPlatform, MatryxProxy.address, '1')
}
