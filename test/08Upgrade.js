const { shouldFail } = require('openzeppelin-test-helpers');
const MatryxSystem = artifacts.require('MatryxSystem')
const IMatryxSystem = artifacts.require('IMatryxSystem')
const MatryxPlatform = artifacts.require('MatryxPlatform')
const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')

const LibPlatformUpgraded = artifacts.require('LibPlatformUpgraded')
const IPlatformUpgraded = artifacts.require('IPlatformUpgraded')
const LibCommitUpgraded = artifacts.require('LibCommitUpgraded')
const ICommitUpgraded = artifacts.require('ICommitUpgraded')
const LibTournamentUpgraded = artifacts.require('LibTournamentUpgraded')

const { Contract } = require('../truffle/utils')
const { init, createTournament } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform
let system
let commit

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

    assert.equal(two, 2, "Returned incorrect value from upgraded library function")
  })

})

contract('Same Version Commit Library Code Swap', function() {
  commit = Contract(MatryxCommit.address, IMatryxCommit)

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

    const commitTwo = Contract(MatryxCommit.address, ICommitUpgraded)

    let r = await commitTwo.getAvailableRewardForUser('0x00', accounts[0])

    assert.equal(r, 42, "Returned incorrect value from upgraded library function")
  })
})

contract('Platform version upgrade', function() {
  let t1
  let t2
  let roundData = {
    start: 0,
    duration: 30,
    review: 20,
    bounty: web3.toWei(5)
  }

  it('Current version functionality unaffected by new version created', async () => {
    platform = (await init()).platform
    system = Contract(MatryxSystem.address, IMatryxSystem)

    t1 = await createTournament('tournament', web3.toWei(10), roundData, 0)

    const countBefore = await platform.getTournamentCount().then(fromWei)
    await system.createVersion(2)
    await system.setContract(2, stb("LibPlatform"), LibPlatformUpgraded.address)
    await system.addContractMethod(2, stb("LibPlatform"), selector('getTournamentCount()'), [selector('getTournamentCount(address,address,MatryxPlatform.Data storage)'), [3],[]])
    const countAfter = await platform.getTournamentCount().then(fromWei)
    assert.equal(countBefore, countAfter, "Incorrect counts after upgrade")
  })

  it("Unable to create the same version twice", async () => {
    await system.createVersion(25)
    const tx = system.createVersion(25)
    await shouldFail.reverting(tx)
  })

  it("Setting the current version switches functionality to new version library", async () => {
    await system.createVersion(3)
    await system.setContract(3, stb("LibPlatform"), LibPlatformUpgraded.address)
    await system.addContractMethod(3, stb("LibPlatform"), selector('getTournamentCount()'), [selector('getTournamentCount(address,address,MatryxPlatform.Data storage)'), [3],[]])
    await system.setVersion(3)

    let countAfter = await platform.getTournamentCount().then(fromWei)
    assert.equal(countAfter, 99, "Incorrect count after upgrade")
  })

  it("Contracts created before the version change still use the previous version libraries", async () => {
    let { version } = await t1.getInfo();
    assert.equal(version, 1, "Incorrect version for old tournament")

    let b = await t1.getBalance().then(fromWei)
    assert.equal(b, 10, "Incorrect tournament balance")
  })

  // TODO
  it("Newly created contracts use the current platform version", async () => {
    // figure out how to link new libPlatform with new libTournament before attempting to create a new tournament
    await system.setContract(3, stb("LibTournament"), LibTournamentUpgraded.address)
    await system.addContractMethod(3, stb("LibTournament"), selector('getBalance()'), [selector('getBalance(address,address,MatryxPlatform.Data storage)'), [3],[]])

    // t2 = await createTournament('tournament', web3.toWei(10), roundData, 0)
    // let { version } = await t2.getInfo();
    // assert.equal(version, 3, "Incorrect version for new tournament")

    // let b = await t2.getBalance().then(fromWei)
    // assert.equal(b, 99, "Incorrect tournament balance")
  })

  it("Able to upgrade the version of all other libraries as well", async () => {
    // figure out how to migrate and link new libraries from within the tests
  })
})