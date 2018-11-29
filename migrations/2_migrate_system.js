var MatryxSystem = artifacts.require('MatryxSystem')

module.exports = function(deployer) {
  deployer.deploy(MatryxSystem, { overwrite: false })
}
