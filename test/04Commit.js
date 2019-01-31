const { shouldFail } = require('openzeppelin-test-helpers');

const { setup, genId, stringToBytes, Contract } = require('../truffle/utils')
const { init, initCommit } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')

const randContent = () => stringToBytes(genId(32), 2)

let platform, commit, groupName, group

contract('MatryxCommit', async () => {
  before(async () => {
    platform = (await init()).platform
    commit = Contract(MatryxCommit.address, IMatryxCommit)
  })

  beforeEach(async () => {
    commit.accountNumber = 0
    groupName = genId(5)
    await commit.createGroup(groupName)
  })

  // reset contract accounts
  afterEach(() => {
    commit.accountNumber = 0
  })

  it('Cannot create a group until in Matryx', async () => {
    commit.accountNumber = 1
    const tx = commit.createGroup('account 1 group')
    await shouldFail.reverting(tx)
  })
  
  it('Cannot create a commit until in Matryx', async () => {
    commit.accountNumber = 1
    const tx = commit.initialCommit(randContent(), toWei(1), 'new group')
    await shouldFail.reverting(tx)
  })

  it('Cannot create the same group twice', async () => {
    await setup(artifacts, web3, 1, true)
    commit.accountNumber = 1
    await commit.createGroup('duplicate group')
    const tx = commit.createGroup('duplicate group')
    await shouldFail.reverting(tx)
  })

  it('Able to create a group', async () => {
    let groupNameTwo = 'group 2'
    await commit.createGroup('group 2')
    // hash name of group
    const returnedName = await commit.getGroupName(web3.utils.keccak256(groupNameTwo))
    assert.equal(returnedName, groupNameTwo, 'Unable to create a new group')
  })

  it('Group members are persistent', async () => {
    await commit.addGroupMember(groupName, accounts[1])
    await commit.addGroupMember(groupName, accounts[2])

    let members = await commit.getGroupMembers(groupName)
    let includesAllMembers = accounts.slice(0, 3).every(acc => members.includes(acc))
    assert.isTrue(includesAllMembers, 'Did not add more group members successfully')
  })

  it('Cannot add user to a group twice', async () => {
    await commit.addGroupMember(groupName, accounts[1])
    const tx = commit.addGroupMember(groupName, accounts[1])
    await shouldFail.reverting(tx)
  })
  
  it('Cannot add user to nonexistent group', async () => {
    const tx = commit.addGroupMember('not a real group', accounts[1])
    await shouldFail.reverting(tx)
  })

  it('Cannot add group member if not in group', async () => {
    await setup(artifacts, web3, 3, true)
    commit.accountNumber = 3
    const tx = commit.addGroupMember(groupName, accounts[2])
    await shouldFail.reverting(tx)
  })

  it('Groups are persistent', async () => {
    let groupsBefore = await commit.getAllGroups()
    await commit.createGroup('group A')
    await commit.createGroup('group B')
    let groupsAfter = await commit.getAllGroups()

    assert.equal(groupsAfter.length - groupsBefore.length, 2, 'Commit system should contain 2 more groups')
  })

  it('Able to make a commit', async () => {
    const commitsBefore = await commit.getInitialCommits()
    await commit.initialCommit(randContent(), toWei(1), groupName)
    const commitsAfter = await commit.getInitialCommits()

    assert.equal(commitsAfter.length - commitsBefore.length, 1, 'New commit should exist')
  })

  it('Cannot create commit if not in group', async () => {
    commit.accountNumber = 1
    const tx = commit.initialCommit(randContent(), toWei(1), groupName)
    
    await shouldFail.reverting(tx)
  })

  it('Cannot fork commit until in Matryx', async () => {
    const parentHash = await initCommit(randContent(), toWei(1), groupName, 0)

    commit.accountNumber = 2
    const tx = commit.fork(randContent(), toWei(1), parentHash, 'fork group name')
    await shouldFail.reverting(tx)
  })

  it('Able to fork from commit', async () => {
    const parentHash = await initCommit(randContent(), toWei(1), groupName, 0)
    
    commit.accountNumber = 1
    const contentHash = randContent()
    await commit.fork(contentHash, toWei(1), parentHash, 'group 4')
    let returnCommit = await commit.getCommitByContentHash(contentHash)

    assert.equal(returnCommit.owner, accounts[1], 'Fork owner should be first account')
  })

  it('Commit value transferred from fork owner to commit owner', async () => {
    const balanceBefore = await platform.getBalanceOf(accounts[0]).then(fromWei)

    const parentHash = await initCommit(randContent(), toWei(1), groupName, 0)

    commit.accountNumber = 1
    await commit.fork(randContent(), toWei(1), parentHash, 'group 5')

    const balanceAfter = await platform.getBalanceOf(accounts[0]).then(fromWei)

    assert.equal(balanceAfter - balanceBefore, 1, 'Account 0 balance should increase by 1 after fork')
  })
})
