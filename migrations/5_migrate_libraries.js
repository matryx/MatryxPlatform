var LibUtils = artifacts.require('LibUtils')
var LibPlatform = artifacts.require('LibPlatform')
var LibUser = artifacts.require('LibUser')
var LibTournament = artifacts.require('LibTournament')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')
var LibTrinity = artifacts.require('LibTrinity')

module.exports = function (deployer) {
  deployer.deploy(LibUtils, { overwrite: false })
  deployer.deploy(LibUser, { overwrite: false })

  deployer.deploy(LibTrinity, { overwrite: false })
  deployer.link(LibTrinity, LibPlatform)
  deployer.link(LibTrinity, LibTournament)
  deployer.link(LibTrinity, LibRound)
  deployer.link(LibTrinity, LibSubmission)

  deployer.deploy(LibTournament, { overwrite: false })
  deployer.deploy(LibRound, { overwrite: false })
  deployer.deploy(LibSubmission, { overwrite: false })

  deployer.link(LibTournament, LibPlatform)
  deployer.deploy(LibPlatform, { overwrite: false })
}
