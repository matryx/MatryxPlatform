var LibUtils = artifacts.require('LibUtils')
var LibPlatform = artifacts.require('LibPlatform')
var LibUser = artifacts.require('LibUser')
var LibTournament = artifacts.require('LibTournament')
var LibTournamentHelper = artifacts.require('LibTournamentHelper')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')

module.exports = function (deployer) {
  deployer.deploy(LibUtils, { overwrite: false })
  deployer.deploy(LibUser, { overwrite: false })

  deployer.deploy(LibTournamentHelper, { overwrite: false })
  deployer.link(LibTournamentHelper, LibTournament)

  deployer.deploy(LibTournament, { overwrite: false })
  deployer.deploy(LibRound, { overwrite: false })
  deployer.deploy(LibSubmission, { overwrite: false })

  deployer.link(LibTournament, LibPlatform)
  deployer.deploy(LibPlatform, { overwrite: false })
}
