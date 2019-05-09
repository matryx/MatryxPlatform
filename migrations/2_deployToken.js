const MatryxToken = artifacts.require('MatryxToken')
const network = require('../truffle/network')

module.exports = function (deployer) {
  if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(MatryxToken, { gas: 7e6, overwrite: false })
  }
}
