var LibUtils = artifacts.require('LibUtils')
var LibPlatform = artifacts.require('LibPlatform')
var LibUser = artifacts.require('LibUser')
var LibTournament = artifacts.require('LibTournament')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')
var LibTrinity = artifacts.require('LibTrinity')

module.exports = function (deployer) {
  deployer.deploy(LibUtils)
  deployer.deploy(LibUser)

  deployer.deploy(LibTrinity)
  deployer.link(LibTrinity, LibPlatform)
  deployer.link(LibTrinity, LibTournament)
  deployer.link(LibTrinity, LibRound)
  deployer.link(LibTrinity, LibSubmission)

  deployer.deploy(LibTournament)
  deployer.deploy(LibRound)
  deployer.deploy(LibSubmission)

  deployer.link(LibTournament, LibPlatform)
  deployer.deploy(LibPlatform)
}
