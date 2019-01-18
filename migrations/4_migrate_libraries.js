const LibUtils = artifacts.require('LibUtils')
const LibPlatform = artifacts.require('LibPlatform')
const LibUser = artifacts.require('LibUser')
const LibCommit = artifacts.require('LibCommit')
const LibTournament = artifacts.require('LibTournament')
const LibTournamentHelper = artifacts.require('LibTournamentHelper')
const LibRound = artifacts.require('LibRound')
const LibSubmission = artifacts.require('LibSubmission')

module.exports = function (deployer) {
  deployer.deploy(LibUtils, { gas: 8e6, overwrite: false })
  deployer.deploy(LibPlatform, { gas: 8e6, overwrite: false })
  deployer.deploy(LibUser, { gas: 8e6, overwrite: false })
  deployer.deploy(LibCommit, { gas: 8e6, overwrite: false })
  deployer.deploy(LibTournamentHelper, { gas: 8e6, overwrite: false })
  
  deployer.link(LibTournamentHelper, LibTournament)

  deployer.deploy(LibTournament, { gas: 8e6, overwrite: false })
  deployer.deploy(LibRound, { gas: 8e6, overwrite: false })
  deployer.deploy(LibSubmission, { gas: 8e6, overwrite: false })
}
