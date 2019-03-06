const network = require('../truffle/network')

const LibPlatform2 = artifacts.require('LibPlatform2')
const LibCommit2 = artifacts.require('LibCommit2')
const LibTournament2 = artifacts.require('LibTournament2')

module.exports = function (deployer) {
  if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(LibTournament2, {gas: 8e6, overwrite: false})

    deployer.link(LibTournament2, LibPlatform2)
    deployer.deploy(LibPlatform2, {gas: 8e6, overwrite: false})

    deployer.link(LibTournament2, LibCommit2)
    deployer.deploy(LibCommit2, {gas: 8e6, overwrite: false})
  }
}