var MatryxToken = artifacts.require('MatryxToken')
var network = require('../truffle/network')

module.exports = function (deployer) {
  if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(MatryxToken, { overwrite: false })
  }
}
