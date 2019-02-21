const MatryxSystem = artifacts.require('MatryxSystem')

module.exports = function(deployer) {
  deployer.deploy(MatryxSystem, { gas: 7e6, overwrite: false })
}
