const MatryxSystem = artifacts.require('MatryxSystem')
const MatryxPlatform = artifacts.require('MatryxPlatform')
const MatryxUser = artifacts.require('MatryxUser')
const MatryxCommit = artifacts.require('MatryxCommit')
const network = require('../truffle/network')

module.exports = function(deployer) {
  deployer.deploy(MatryxPlatform, MatryxSystem.address, network.tokenAddress, { gas: 8e6, overwrite: false })
  deployer.deploy(MatryxUser, '1', MatryxSystem.address, { gas: 8e6, overwrite: false })
  deployer.deploy(MatryxCommit, '1', MatryxSystem.address, { gas: 8e6, overwrite: false })
}
