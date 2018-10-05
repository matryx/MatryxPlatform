var MatryxSystem = artifacts.require('MatryxSystem')
var MatryxUser = artifacts.require('MatryxUser')
var network = require('../truffle/network')

module.exports = function (deployer) {
  deployer.deploy(MatryxUser, '1', MatryxSystem.address, { overwrite: false })
}
