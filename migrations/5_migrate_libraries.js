var LibUtils = artifacts.require('LibUtils')
var LibPlatform = artifacts.require('LibPlatform')
var LibUser = artifacts.require('LibUser')
var LibTournament = artifacts.require('LibTournament')
var LibTournamentHelper = artifacts.require('LibTournamentHelper')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')

module.exports = function (deployer) {
  deployer.deploy(LibUtils, { gas: 8e6, overwrite: false })
  deployer.deploy(LibUser, { gas: 8e6, overwrite: false })

  deployer.deploy(LibTournamentHelper, { gas: 8e6, overwrite: false })
  deployer.link(LibTournamentHelper, LibTournament)

  deployer.deploy(LibTournament, { gas: 8e6, overwrite: false })
  deployer.deploy(LibRound, { gas: 8e6, overwrite: false })
  deployer.deploy(LibSubmission, { gas: 8e6, overwrite: false })

  deployer.deploy(LibPlatform, { gas: 8e6, overwrite: false })
}
