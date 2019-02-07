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
  let commit

  before(async () => {
    commit = Contract(MatryxCommit.address, IMatryxCommit)
  })

  it('Revert when setting library that has no code', async function() {
    platform = (await init()).platform
    await setup(artifacts, web3, 0)
    system = Contract(MatryxSystem.address, IMatryxSystem)
    
    const tx = system.setContract(1, stb("LibPlatform"), accounts[0])

    await shouldFail.reverting(tx)
  })

  it('Revert when making a call to library with incorrect address in system', async () => {
    platform = (await init()).platform
    await setup(artifacts, web3, 0)
    system = Contract(MatryxSystem.address, IMatryxSystem)
    
    await system.setContract(1, stb("LibPlatform"), MatryxSystem.address)
    const tx = platform.setCommitDistributionDepth(100)

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
  commit = Contract(MatryxCommit.address, IMatryxCommit)

  it('Revert when making a call to library with incorrect address in system', async () => {   
    platform = (await init()).platform
    await setup(artifacts, web3, 0)
    system = Contract(MatryxSystem.address, IMatryxSystem)
    
    await system.setContract(1, stb("LibCommit"), MatryxSystem.address)
    const tx = commit.createGroup("new group")

    await shouldFail.reverting(tx)
  })

  it('New library for forwarder behaves correctly', async () => {
    await system.setContract(1, stb("LibCommit"), LibCommitUpgraded.address)
    await system.addContractMethod(1, stb("LibCommit"), selector('getGroupName()'), [selector('getGroupName(address,address,MatryxPlatform.Info storage,bytes32)'), [0],[]])

    const commitTwo = Contract(MatryxCommit.address, IMatryxCommitUpgraded)
    
    let tacotaco = await commitTwo.getGroupName(stb('group name'))

    assert.equal(tacotaco, "tacotaco", "Returned incorrect value from upgraded library function")
  })
})

contract('Platform version upgrade', function() {

  it('Current version functionality unaffected by new version created', async () => {
    platform = (await init()).platform
    await setup(artifacts, web3, 0)
    system = Contract(MatryxSystem.address, IMatryxSystem)

    console.log(platform.address)
    console.log(LibPlatform.address)
    const balanceBefore = await platform.getBalanceOf(accounts[0]).then(fromWei)
    console.log(`balance before: ${balanceBefore}`)
    await system.createVersion(2)
    await system.setContract(2, stb("LibPlatform"), LibPlatformUpgraded.address)
    await system.addContractMethod(2, stb("LibPlatform"), selector('getBalanceOf(address)'), [selector('getBalanceOf(address,address,MatryxPlatform.Data storage,address)'), [3],[]])
    const balanceAfter = await platform.getBalanceOf(accounts[0]).then(fromWei)
    console.log(`balance after: ${balanceAfter}`)
    assert.equal(balanceBefore, balanceAfter, "Balances were not the same despite upgrade")
  })

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