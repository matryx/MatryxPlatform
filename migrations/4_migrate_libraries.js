var LibPlatform = artifacts.require('LibPlatform')
var LibTournament = artifacts.require('LibTournament')
var LibRound = artifacts.require('LibRound')
var LibSubmission = artifacts.require('LibSubmission')

module.exports = function(deployer) {
  deployer.deploy(LibPlatform)
  deployer.deploy(LibTournament)
  deployer.deploy(LibRound)
  deployer.deploy(LibSubmission)
}
