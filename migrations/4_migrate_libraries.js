const LibPlatform = artifacts.require('LibPlatform')
const LibCommit = artifacts.require('LibCommit')
const LibTournament = artifacts.require('LibTournament')

module.exports = function (deployer) {
  deployer.deploy(LibTournament, { gas: 7e6, overwrite: false })
  deployer.link(LibTournament, LibPlatform)

  deployer.deploy(LibPlatform, { gas: 7e6, overwrite: false })

  deployer.link(LibTournament, LibCommit)
  deployer.deploy(LibCommit, { gas: 7e6, overwrite: false })
}
