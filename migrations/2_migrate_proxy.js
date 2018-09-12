var MatryxProxy = artifacts.require('./MatryxProxy.sol')

module.exports = function(deployer) {
  deployer.deploy(MatryxProxy, { overwrite: false })
}
