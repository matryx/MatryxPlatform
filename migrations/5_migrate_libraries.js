const LibPlatform = artifacts.require('LibPlatform')
const LibCommit = artifacts.require('LibCommit')
const LibTournament = artifacts.require('LibTournament')
const LibTournamentHelper = artifacts.require('LibTournamentHelper')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')

const network = require('../truffle/network')

module.exports = function (deployer) {
  deployer.deploy(LibTournamentHelper, { gas: 8e6, overwrite: false })
  deployer.link(LibTournamentHelper, LibTournament)
  
  deployer.deploy(LibTournament, { gas: 8e6, overwrite: false })
  deployer.link(LibTournament, LibPlatform)

  deployer.deploy(LibPlatform, { gas: 8e6, overwrite: false })
  
  deployer.link(LibTournament, LibCommit)
  deployer.deploy(LibCommit, { gas: 8e6, overwrite: false })

  if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(LibPlatformUpgraded, {gas: 8e6, overwrite: false})
    deployer.deploy(LibCommitUpgraded, {gas: 8e6, overwrite: false})
  }
}
