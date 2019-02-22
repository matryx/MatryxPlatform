const network = require('../truffle/network')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')
const LibTournamentUpgraded = artifacts.require('LibTournamentUpgraded')

const LibPlatform = artifacts.require("LibPlatform")
const LibTournament = artifacts.require("LibTournament")
const LibTournamentHelper = artifacts.require("LibTournamentHelper")
const TestLibPlatform = artifacts.require("TestLibPlatform")
const AssertUint = artifacts.require("AssertUint")
const AssertAddress = artifacts.require("AssertAddress")

module.exports = async function (deployer) {
  // if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(LibPlatformUpgraded, {gas: 8e6, overwrite: false})
    deployer.deploy(LibCommitUpgraded, {gas: 8e6, overwrite: false})
    deployer.deploy(LibTournamentUpgraded, {gas: 8e6, overwrite: false})

    deployer.deploy(LibTournamentHelper)
    deployer.link(LibTournamentHelper, LibTournament)
    deployer.deploy(LibTournament)
    deployer.link(LibTournament, LibPlatform)
    deployer.deploy(LibPlatform)
    deployer.deploy(AssertUint)
    // deployer.deploy(AssertAddress);
    deployer.link(AssertUint, TestLibPlatform)
    deployer.link(LibPlatform, TestLibPlatform)
    // deployer.link(AssertAddress, TestLibPlatform)
    deployer.deploy(TestLibPlatform)
  // }
}