const { shouldFail } = require('openzeppelin-test-helpers')

const { setup, genId, stringToBytes, Contract } = require('../truffle/utils')
const { init, createCommit } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')

const randContent = () => stringToBytes(genId(32), 2)

let platform, commit, groupName, group

contract('MatryxCommit', async () => {
  before(async () => {
    platform = (await init()).platform
    commit = Contract(MatryxCommit.address, IMatryxCommit)
    await setup(artifacts, web3, 1, true)
    await setup(artifacts, web3, 3, true)
  })

  beforeEach(async () => {
    commit.accountNumber = 0
  })

  it('Able to make a commit', async () => {
    let commitsBefore = await commit.getInitialCommits()
    await createCommit('0x00', randContent(), toWei(1), 0)
    let commitsAfter = await commit.getInitialCommits()

    assert.equal(commitsAfter.length - commitsBefore.length, 1, 'New commit should exist')
  })

  it('Group members are persistent', async () => {
    let commitHash = await createCommit('0x00', randContent(), toWei(1), 0)
    await commit.addGroupMember(commitHash, accounts[1])
    await commit.addGroupMember(commitHash, accounts[2])
    
    let members = await commit.getGroupMembers(commitHash)
    let includesAllMembers = accounts.slice(0, 3).every(acc => members.includes(acc))
    assert.isTrue(includesAllMembers, 'Did not add more group members successfully')
    assert.isTrue(true, 'Did not add more group members successfully')
  })
  
  it('Cannot add user to a group twice', async () => {
    let commitHash = await createCommit('0x00', randContent(), toWei(1), 0)
    await commit.addGroupMember(commitHash, accounts[1])
    let tx = commit.addGroupMember(commitHash, accounts[1])
    
    await shouldFail.reverting(tx)
  })

  it('Cannot add user for nonexistent commit', async () => {
    let tx = commit.addGroupMember(stb(''), accounts[1])
    await shouldFail.reverting(tx)
  })

  it('Cannot add group member if not in group', async () => {
    let commitHash = await createCommit('0x00', randContent(), toWei(1), 1)
    commit.accountNumber = 0
    let tx = commit.addGroupMember(commitHash, accounts[2])
    await shouldFail.reverting(tx)
  })
  
  it('Cannot create commit if not in group', async () => {
    let commitHash = await createCommit('0x00', randContent(), toWei(1), 0)
    commit.accountNumber = 1
    let tx = commit.commit(commitHash, randContent(), toWei(1))

    await shouldFail.reverting(tx)
  })
  
  it('Able to fork from commit', async () => {
    let parentHash = await createCommit('0x00', randContent(), toWei(1), 0)
    commit.accountNumber = 1
    let contentHash = randContent()
    await commit.fork(parentHash, contentHash, toWei(1))
    let returnCommit = await commit.getCommitByContentHash(contentHash)

    assert.equal(returnCommit.parentHash, parentHash, 'Fork parent should be first commit')
    assert.equal(returnCommit.owner, accounts[1], 'Fork owner should be first account')
  })

  it('Commit value transferred from fork owner to commit', async () => {
    let parentHash = await createCommit('0x00', randContent(), toWei(1), 0)
    let balanceBefore = await platform.getCommitBalance(parentHash).then(fromWei)
    
    commit.accountNumber = 1
    await commit.fork(parentHash, randContent(), toWei(1))

    let balanceAfter = await platform.getCommitBalance(parentHash).then(fromWei)

    assert.equal(balanceAfter - balanceBefore, 1, 'Commit balance should increase by 1 after fork')
  })

  // TODO: test new fork funds distribution, test all frontrunning cases
  // it('Correct distribution on fork', )
})
