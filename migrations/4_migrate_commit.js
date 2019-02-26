const MatryxSystem = artifacts.require('MatryxSystem')
const MatryxCommit = artifacts.require('MatryxCommit')

module.exports = function(deployer) {
  deployer.deploy(MatryxCommit, '1', MatryxSystem.address, { gas: 7e6, overwrite: false })
}
