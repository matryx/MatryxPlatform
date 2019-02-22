const network = require('../truffle/network')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')

const LibPlatform = artifacts.require("LibPlatform")
const LibTournament = artifacts.require("LibTournament")
const LibTournamentHelper = artifacts.require("LibTournamentHelper")

module.exports = function (deployer) {
  if (['develop', 'ganache'].includes(network.network)) {
    deployer.deploy(LibPlatformUpgraded, {gas: 8e6, overwrite: false})
    deployer.deploy(LibCommitUpgraded, {gas: 8e6, overwrite: false})
  }
}