const network = require('../truffle/network')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')
const LibTournamentUpgraded = artifacts.require('LibTournamentUpgraded')

module.exports = function (deployer) {
  if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(LibTournamentUpgraded, {gas: 8e6, overwrite: false})

    deployer.link(LibTournamentUpgraded, LibPlatformUpgraded)
    deployer.deploy(LibPlatformUpgraded, {gas: 8e6, overwrite: false})

    deployer.link(LibTournamentUpgraded, LibCommitUpgraded)
    deployer.deploy(LibCommitUpgraded, {gas: 8e6, overwrite: false})
  }
}