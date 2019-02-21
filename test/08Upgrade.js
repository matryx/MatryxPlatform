const { expectEvent, shouldFail } = require('openzeppelin-test-helpers');
const MatryxSystem = artifacts.require('MatryxSystem')
const IMatryxSystem = artifacts.require('IMatryxSystem')
const MatryxPlatform = artifacts.require('MatryxPlatform')
const LibPlatform = artifacts.require('LibPlatform')
const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const IPlatformUpgraded = artifacts.require('IPlatformUpgraded')
const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')
const IMatryxCommitUpgraded = artifacts.require('IMatryxCommitUpgraded')

const { setup, Contract, genId } = require('../truffle/utils')
const { init, createTournament, waitUntilInReview, createSubmission, selectWinnersWhenInReview, initCommit, addToGroup } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform
let system

contract('Same Version Platform Library Code Swap', function() {

  it('Revert when setting library that has no code', async function() {
    platform = (await init()).platform
    system = Contract(MatryxSystem.address, IMatryxSystem)

    const tx = system.setContract(1, stb("LibPlatform"), accounts[0])

    await shouldFail.reverting(tx)
  })

  it('Revert when making a call to library with incorrect address in system', async () => {
    await system.setContract(1, stb("LibPlatform"), MatryxSystem.address)
    const tx = platform.getInfo()

    await shouldFail.reverting(tx)
  })

  it('Previously nonexistent selector returns correct value after new library setup on system', async () => {
    await system.setContract(1, stb("LibPlatform"), LibPlatformUpgraded.address)
    await system.addContractMethod(1, stb("LibPlatform"), selector('getTwo()'), [selector('getTwo(address,address,MatryxPlatform.Info storage)'), [0],[]])

    const PlatformUpgraded = Contract(MatryxPlatform.address, IPlatformUpgraded)

    let two = await PlatformUpgraded.getTwo()

    // set platform back
    await system.setContract(1, stb("LibPlatform"), LibPlatform.address)
    assert.equal(two, 2, "Returned incorrect value from upgraded library function")
  })

})

contract('Same Version Commit Library Code Swap', function() {
  let commit = Contract(MatryxCommit.address, IMatryxCommit)

  it('Revert when making a call to library with incorrect address in system', async () => {
    platform = (await init()).platform
    system = Contract(MatryxSystem.address, IMatryxSystem)

    await system.setContract(1, stb("LibCommit"), MatryxSystem.address)
    const tx = commit.getInitialCommits()

    await shouldFail.reverting(tx)
  })

  it('New library for forwarder behaves correctly', async () => {
    await system.setContract(1, stb("LibCommit"), LibCommitUpgraded.address)
    await system.addContractMethod(1, stb("LibCommit"), selector('getAvailableRewardForUser(bytes32,address)'), [selector('getAvailableRewardForUser(address,address,MatryxPlatform.Data storage,bytes32,address)'), [3], []])

    const commitTwo = Contract(MatryxCommit.address, IMatryxCommitUpgraded)

    let r = await commitTwo.getAvailableRewardForUser('0x00', accounts[0])

    assert.equal(r, 42, "Returned incorrect value from upgraded library function")
  })
})

contract('Platform version upgrade', function() {

  it('Current version functionality unaffected by new version created', async () => {
    platform = (await init()).platform
    system = Contract(MatryxSystem.address, IMatryxSystem)

    const balanceBefore = await platform.getTournamentCount().then(fromWei)
    await system.createVersion(2)
    await system.setContract(2, stb("LibPlatform"), LibPlatformUpgraded.address)
    await system.addContractMethod(2, stb("LibPlatform"), selector('getTournamentCount()'), [selector('getTournamentCount(address,address,MatryxPlatform.Data storage)'), [3],[]])
    const balanceAfter = await platform.getTournamentCount().then(fromWei)
    assert.equal(balanceBefore, balanceAfter, "Balances were not the same despite upgrade")
  })

  // TODO - everything below & moar
  it("Unable to create the same version twice", async () => {
    await system.createVersion(25)
    const tx = system.createVersion(25)
    await shouldFail.reverting(tx)
  })

  it("Setting the current version switches functionality to new version library", async () => {
    await system.createVersion(3)
    await system.setContract(3, stb("LibPlatform"), LibPlatformUpgraded.address)
    await system.setVersion(3)

    // test functionality change here
  })

  it("Able to upgrade the version of all other libraries as well", async () => {

  })

  it("Newly created contracts use the current platform version", async () => {

  })

  it("Contracts created before the version change still use the previous version libraries", async () => {

  })
})