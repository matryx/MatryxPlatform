const MatryxSystem = artifacts.require('MatryxSystem')
const MatryxCommit = artifacts.require('MatryxCommit')
const network = require('../truffle/network')

module.exports = function(deployer) {
  deployer.deploy(MatryxCommit, '1', MatryxSystem.address, { gas: 7e6, overwrite: false })
}
