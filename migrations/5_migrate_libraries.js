const LibPlatform = artifacts.require('LibPlatform')
const LibUser = artifacts.require('LibUser')
const LibCommit = artifacts.require('LibCommit')
const LibTournament = artifacts.require('LibTournament')
const LibTournamentHelper = artifacts.require('LibTournamentHelper')
const LibRound = artifacts.require('LibRound')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')

module.exports = function (deployer) {
  deployer.deploy(LibPlatform, { gas: 8e6, overwrite: false })
  deployer.deploy(LibUser, { gas: 8e6, overwrite: false })
  deployer.deploy(LibTournamentHelper, { gas: 8e6, overwrite: false })
  
  deployer.link(LibTournamentHelper, LibTournament)
  
  deployer.deploy(LibTournament, { gas: 8e6, overwrite: false })
  deployer.deploy(LibRound, { gas: 8e6, overwrite: false })
  
  deployer.link(LibTournament, LibCommit)
  deployer.deploy(LibCommit, { gas: 8e6, overwrite: false })

  deployer.deploy(LibPlatformUpgraded, {gas: 8e6, overwrite: false})
  deployer.deploy(LibCommitUpgraded, {gas: 8e6, overwrite: false})
}
