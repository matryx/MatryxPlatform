var LibPlatform = artifacts.require('LibPlatform')
var LibTournament = artifacts.require('LibTournament')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')
var LibEntity = artifacts.require('LibEntity')

module.exports = function (deployer) {
  deployer.deploy(LibEntity)
  deployer.link(LibEntity, LibPlatform)
  deployer.link(LibEntity, LibTournament)
  deployer.link(LibEntity, LibRound)
  deployer.link(LibEntity, LibSubmission)

  deployer.deploy(LibTournament)
  deployer.deploy(LibRound)
  deployer.deploy(LibSubmission)

  deployer.link(LibTournament, LibPlatform)
  deployer.deploy(LibPlatform)
}
