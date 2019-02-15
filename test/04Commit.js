const { shouldFail } = require('openzeppelin-test-helpers')

const { setup, genId, stringToBytes, Contract } = require('../truffle/utils')
const { init, createCommit, claimCommit } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform, token, commit

contract('MatryxCommit', async () => {
  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token
    
    await setup(artifacts, web3, 1, true)
    await setup(artifacts, web3, 3, true)
  })

  beforeEach(async () => {
    commit.accountNumber = 0
  })

  it('Able to make a commit', async () => {
    let commitsBefore = await commit.getInitialCommits()
    await createCommit('0x00', false, genId(16), toWei(1), 0)
    let commitsAfter = await commit.getInitialCommits()

    assert.equal(commitsAfter.length - commitsBefore.length, 1, 'New commit should exist')
  })

  it('Group members are persistent', async () => {
    let commitHash = await createCommit('0x00', false, genId(16), toWei(1), 0)
    await commit.addGroupMember(commitHash, accounts[1])
    await commit.addGroupMember(commitHash, accounts[2])
    
    let members = await commit.getGroupMembers(commitHash)
    let includesAllMembers = accounts.slice(0, 3).every(acc => members.includes(acc))
    assert.isTrue(includesAllMembers, 'Did not add more group members successfully')
  })
  
  it('Cannot add user to a group twice', async () => {
    let commitHash = await createCommit('0x00', false, genId(16), toWei(1), 0)
    await commit.addGroupMember(commitHash, accounts[1])

    let tx = commit.addGroupMember(commitHash, accounts[1])
    await shouldFail.reverting(tx)
  })

  it('Cannot add user for nonexistent commit', async () => {
    let tx = commit.addGroupMember('0x00', accounts[1])
    await shouldFail.reverting(tx)
  })

  it('Cannot add group member if not in group', async () => {
    let commitHash = await createCommit('0x00', false, genId(16), toWei(1), 1)
    commit.accountNumber = 0
    let tx = commit.addGroupMember(commitHash, accounts[2])
    await shouldFail.reverting(tx)
  })
  
  it('Cannot create commit if not in group', async () => {
    let parentHash = await createCommit('0x00', false, genId(16), toWei(1), 0)
    
    let salt = stringToBytes('NaCl')
    let content = genId(16)
    await claimCommit(salt, content, 1)

    commit.accountNumber = 1
    let tx = commit.createCommit(parentHash, false, salt, content, toWei(1))
    await shouldFail.reverting(tx)
  })
  
  it('Able to fork from commit', async () => {
    let parentHash = await createCommit('0x00', false, genId(16), toWei(1), 0)
    
    let balanceBefore = await token.balanceOf(network.accounts[1]).then(fromWei)
    let commitHash = await createCommit(parentHash, true, genId(16), toWei(1), 1)
    let returnCommit = await commit.getCommit(commitHash)
    let balanceAfter = await token.balanceOf(network.accounts[1]).then(fromWei)

    assert.equal(returnCommit.parentHash, parentHash, 'Fork parent should be first commit')
    assert.equal(returnCommit.owner, accounts[1], 'Fork owner should be first account')
    assert.equal(balanceBefore - 1, balanceAfter, 'Balance of commit creator should be one less than before forking')
  })

  it('Commit value transferred from fork owner to commit', async () => {
    let parentHash = await createCommit('0x00', false, genId(16), toWei(1), 0)
    let balanceBefore = await platform.getCommitBalance(parentHash).then(fromWei)
    
    // fork
    await createCommit(parentHash, true, genId(16), toWei(1), 1)
    let balanceAfter = await platform.getCommitBalance(parentHash).then(fromWei)

    assert.equal(balanceAfter, balanceBefore + 1, 'Commit balance should increase by 1 after fork')
  })

  // TODO: test new fork funds distribution, test all frontrunning cases
  // it('Correct distribution on fork', )
})
