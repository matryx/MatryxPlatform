const Migrations = artifacts.require('./Migrations.sol')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')

const LibPlatform = artifacts.require("LibPlatform")
const LibTournament = artifacts.require("LibTournament")
const LibTournamentHelper = artifacts.require("LibTournamentHelper")
const TestLibPlatform = artifacts.require("TestLibPlatform")
const AssertUint = artifacts.require("AssertUint")
// const AssertAddress = artifacts.require("AssertAddress")

module.exports = function(deployer) {
  deployer.deploy(Migrations, { gas: 7e6, overwrite: false })

  
}