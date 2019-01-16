var MatryxSystem = artifacts.require('MatryxSystem')

module.exports = function(deployer) {
  deployer.deploy(MatryxSystem, { gasLimit: 8e6, overwrite: false })
}
