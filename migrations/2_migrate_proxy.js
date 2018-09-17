var MatryxProxy = artifacts.require('MatryxProxy')

module.exports = function(deployer) {
  deployer.deploy(MatryxProxy, { overwrite: false })
}
