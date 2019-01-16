var LibUtils = artifacts.require('LibUtils')
var LibPlatform = artifacts.require('LibPlatform')
var LibUser = artifacts.require('LibUser')
var LibTournament = artifacts.require('LibTournament')
var LibTournamentHelper = artifacts.require('LibTournamentHelper')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')

module.exports = function (deployer) {
  deployer.deploy(LibUtils, { gasLimit: 8e6, overwrite: false })
  deployer.deploy(LibUser, { gasLimit: 8e6, overwrite: false })

  deployer.deploy(LibTournamentHelper, { gasLimit: 8e6, overwrite: false })
  deployer.link(LibTournamentHelper, LibTournament)

  deployer.deploy(LibTournament, { gasLimit: 8e6, overwrite: false })
  deployer.deploy(LibRound, { gasLimit: 8e6, overwrite: false })
  deployer.deploy(LibSubmission, { gasLimit: 8e6, overwrite: false })

  deployer.deploy(LibPlatform, { gasLimit: 8e6, overwrite: false })
}
