const { shouldFail } = require('openzeppelin-test-helpers')

const { setup, genId, stringToBytes } = require('../truffle/utils')
const { init, createCommit, claimCommit } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform, token, commit

contract('MatryxCommit', async () => {
  before(async () => {
    data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    await setup(artifacts, web3, 1, true)
    await setup(artifacts, web3, 3, true)
  })

  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    commit.accountNumber = 0
  })

  // reset accounts
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Able to make a commit', async () => {
    let commitsBefore = await commit.getInitialCommits()
    let cHash = await createCommit('0x00', false, genId(16), toWei(1), 0)
    let commitsAfter = await commit.getInitialCommits()

    assert.equal(commitsAfter.length - commitsBefore.length, 1, 'New commit should exist')

    let isC = await platform.isCommit(cHash)
    assert.isTrue(isC, "Commit not stored in platform")
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
    let balanceBefore = await commit.getBalance(parentHash).then(fromWei)

    // fork
    await createCommit(parentHash, true, genId(16), toWei(1), 1)
    let balanceAfter = await commit.getBalance(parentHash).then(fromWei)

    assert.equal(balanceAfter, balanceBefore + 1, 'Commit balance should increase by 1 after fork')
  })

  it('Correct distribution when everyone withdraws after a fork', async () => {
    // create commit chain with different owners
    let c1 = await createCommit('0x00', false, genId(16), toWei(1), 1)
    commit.accountNumber = 1
    await commit.addGroupMember(c1, accounts[3])
    let c3 = await createCommit(c1, false, genId(16), toWei(2), 3)

    // fork
    await createCommit(c3, true, genId(16), toWei(1), 1)
    let b = await commit.getBalance(c3).then(fromWei)
    assert.equal(b, 3, 'Incorrent commit balance after fork')

    // check available rewards
    let r1 = await commit.getAvailableRewardForUser(c3, accounts[1]).then(fromWei)
    let r3 = await commit.getAvailableRewardForUser(c3, accounts[3]).then(fromWei)
    assert.equal(r1, 1, "Incorrect available reward for account 1")
    assert.equal(r3, 2, "Incorrect available reward for account 3")

    // all users able to withdraw
    let bb1 = await token.balanceOf(network.accounts[1]).then(fromWei)
    let bb3 = await token.balanceOf(network.accounts[3]).then(fromWei)

    commit.accountNumber = 1
    await commit.withdrawAvailableReward(c3)
    commit.accountNumber = 3
    await commit.withdrawAvailableReward(c3)

    let ba1 = await token.balanceOf(network.accounts[1]).then(fromWei)
    let ba3 = await token.balanceOf(network.accounts[3]).then(fromWei)

    assert.equal(ba1, bb1 + 1, "Account 1 withdraw incorrect")
    assert.equal(ba3, bb3 + 2, "Account 3 withdraw incorrect")
  })

  it('Correct distribution when some users withdraw in between forks', async () => {
    // create commit chain with different owners
    let c1 = await createCommit('0x00', false, genId(16), toWei(1), 1)
    commit.accountNumber = 1
    await commit.addGroupMember(c1, accounts[3])
    let c3 = await createCommit(c1, false, genId(16), toWei(2), 3)

    // fork
    await createCommit(c3, true, genId(16), toWei(1), 1)
    let b = await commit.getBalance(c3).then(fromWei)
    assert.equal(b, 3, 'Incorrent commit balance after fork')

    // user 1 withdraws
    let bb1 = await token.balanceOf(network.accounts[1]).then(fromWei)
    await commit.withdrawAvailableReward(c3)
    let ba1 = await token.balanceOf(network.accounts[1]).then(fromWei)

    assert.equal(ba1, bb1 + 1, "Account 1 withdraw incorrect")

    // another fork
    await createCommit(c3, true, genId(16), toWei(1), 0)
    b = await commit.getBalance(c3).then(fromWei)
    assert.equal(b, 5, 'Incorrent commit balance after second fork')

    // both users withdraw
    bb1 = await token.balanceOf(network.accounts[1]).then(fromWei)
    let bb3 = await token.balanceOf(network.accounts[3]).then(fromWei)
    await commit.withdrawAvailableReward(c3)
    commit.accountNumber = 3
    await commit.withdrawAvailableReward(c3)
    ba1 = await token.balanceOf(network.accounts[1]).then(fromWei)
    let ba3 = await token.balanceOf(network.accounts[3]).then(fromWei)

    assert.equal(ba1, bb1 + 1, "Account 1 withdraw incorrect")
    assert.equal(ba3, bb3 + 4, "Account 3 withdraw incorrect")
  })
})
