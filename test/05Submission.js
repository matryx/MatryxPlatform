const { shouldFail } = require('openzeppelin-test-helpers')

const { genId, setup } = require('../truffle/utils')
const { init, enterTournament, createTournament, selectWinnersWhenInReview, commitCongaLine, createCommit, createSubmission } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform, commit

contract('Submissions', async () => {
  let t // tournament
  let s // submission

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit

    await setup(artifacts, web3, 1, true)
    await setup(artifacts, web3, 2, true)
  })

  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    
    let roundData = {
      start: 0,
      duration: 3600,
      review: 10,
      bounty: toWei(100)
    }
    t = await createTournament('tournament', toWei(200), roundData, 0)
    t.accountNumber = 1
    await t.enter()
    t.accountNumber = 0    
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Able to create a commit and submission for a tournament', async () => {
    let sHash = await createSubmission(t, '0x00', toWei(1), 1)
    let isS = await platform.isSubmission(sHash)
    assert.isTrue(isS, "Submission not stored in platform")
  })

  it('Able to get submission details', async () => {
    let sHash = await createSubmission(t, '0x00', toWei(1), 1)
    let s = await platform.getSubmission(sHash)

    assert.equal(s.tournament, t.address, "Submission tournament incorrect")
  })

  it('Able to create commit with parent for a tournament', async () => {
    let parentHash = await createCommit('0x00', false, genId(10), toWei(1), 1)
    let submissionHash = await createSubmission(t, parentHash, toWei(1), 1)
    let { commitHash } = await platform.getSubmission(submissionHash)

    let theCommit = await commit.getCommit(commitHash)
    assert.equal(theCommit.parentHash, parentHash, 'Commit parentHash should be parent commit')
  })

  it('Correct winning submission rewards on round', async function() {
    let s1 = await createSubmission(t, '0x00', toWei(1), 1)
    let s2 = await createSubmission(t, '0x00', toWei(1), 2)
    let c1 = await platform.getSubmission(s1)
    let c2 = await platform.getSubmission(s2)
    let submissions = [s1, s2]

    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)
    let s1Reward = await commit.getBalance(c1.commitHash).then(fromWei)
    let s2Reward = await commit.getBalance(c2.commitHash).then(fromWei)

    assert.equal(s1Reward, 50, "Submission 1 reward doesn't match reward distribution")
    assert.equal(s2Reward, 50, "Submission 2 reward doesn't match reward distribution")
  })

  it('Correct user balances for winning submissions with a common parent', async function() {
    let parentHash = await createCommit('0x00', false, genId(10), toWei(4), 0)
    await commit.addGroupMember(parentHash, accounts[1])
    await commit.addGroupMember(parentHash, accounts[2])

    let s1 = await createSubmission(t, parentHash, toWei(1), 1)
    let s2 = await createSubmission(t, parentHash, toWei(1), 2)
    let c1 = await platform.getSubmission(s1)
    let c2 = await platform.getSubmission(s2)
    let submissions = [s1, s2]

    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let user0Bal = await commit.getAvailableRewardForUser(c1.commitHash, accounts[0]).then(fromWei)
    user0Bal += await commit.getAvailableRewardForUser(c2.commitHash, accounts[0]).then(fromWei)
    let user1Bal = await commit.getAvailableRewardForUser(c1.commitHash, accounts[1]).then(fromWei)
    let user2Bal = await commit.getAvailableRewardForUser(c2.commitHash, accounts[2]).then(fromWei)

    assert.equal(user0Bal, 80, "Parent owner available reward doesn't match reward distribution")
    assert.equal(user1Bal, 10, "s1 owner available reward doesn't match reward distribution")
    assert.equal(user2Bal, 10, "s2 owner available reward doesn't match reward distribution")
  })

  it('Able to withdraw reward from commit', async () => {
    // first 5 from account 1
    let congaLine = await commitCongaLine('0x00', 5, 1)
    let lastCommit = congaLine[congaLine.length - 1]

    commit.accountNumber = 1
    await commit.addGroupMember(lastCommit, accounts[2])

    // next 5 from account 2
    congaLine = await commitCongaLine(lastCommit, 5, 2)
    lastCommit = congaLine[congaLine.length - 1]

    await enterTournament(t, 2)
    t.accountNumber = 2
    await t.createSubmission('submission', lastCommit)
    t.accountNumber = 0

    const roundIndex = await t.getCurrentRoundIndex()
    const { submissions } = await t.getRoundInfo(roundIndex)
    const submission = submissions[submissions.length - 1]

    // select winners of tournament and distribute reward
    await selectWinnersWhenInReview(t, [submission], [1], [0, 0, 0, 0], 0)

    let bal1 = await commit.getAvailableRewardForUser(lastCommit, accounts[1]).then(fromWei)
    let bal2 = await commit.getAvailableRewardForUser(lastCommit, accounts[2]).then(fromWei)

    assert.equal(bal1, 50, "Account 1 does not have correct available reward in lastCommit")
    assert.equal(bal2, 50, "Account 2 does not have correct available reward in lastCommit")
  })

  it('Correct reward distribution when submitting a fork to the tournament', async () => {
    let commitHash = await createCommit('0x00', false, genId(32), toWei(1), 1)
    let fork = await createCommit(commitHash, true, genId(32), toWei(3), 2)

    let forkPayment = await commit.getAvailableRewardForUser(commitHash, accounts[1]).then(fromWei)
    assert.equal(forkPayment, 1, "Fork reward not available to parent")

    // withdraw funds from the fork
    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0

    await enterTournament(t, 2)
    t.accountNumber = 2
    await t.createSubmission('submission', fork)
    t.accountNumber = 0

    const roundIndex = await t.getCurrentRoundIndex()
    const { submissions } = await t.getRoundInfo(roundIndex)
    const submission = submissions[submissions.length - 1]

    // select winners of tournament and distribute reward
    await selectWinnersWhenInReview(t, [submission], [1], [0, 0, 0, 0], 0)

    let bal1 = await commit.getAvailableRewardForUser(fork, accounts[1]).then(fromWei)
    let bal2 = await commit.getAvailableRewardForUser(fork, accounts[2]).then(fromWei)

    assert.equal(bal1, 25, "Account 1 does not have correct available reward in fork commit")
    assert.equal(bal2, 75, "Account 2 does not have correct available reward in fork commit")
  })

  it('Able to use the same commit hash for 2 different submissions', async () => {
    let submissionHash = await createSubmission(t, '0x00', toWei(10), 1)
    let { commitHash } = await platform.getSubmission(submissionHash)

    // go to next round
    let newRound = {
      start: 0,
      duration: 3600,
      review: 20,
      bounty: web3.toWei(10)
    }
    await selectWinnersWhenInReview(t, [submissionHash], [1], newRound, 1)

    t.accountNumber = 1
    await t.createSubmission('content', commitHash)
    const roundIndex = await t.getCurrentRoundIndex()
    let { submissions } = await t.getRoundInfo(roundIndex)
    let submissionHash2 = submissions[0]

    submissions = await commit.getSubmissionsForCommit(commitHash)
    assert.equal(submissions[0], submissionHash, 'Unable to get first submission from commit')
    assert.equal(submissions[1], submissionHash2, 'Unable to get second submission from commit')
  })

  it('Unable to use the same commit hash for 2 submissions in the same round', async () => {
    let submissionHash = await createSubmission(t, '0x00', toWei(10), 1)
    let { commitHash } = await platform.getSubmission(submissionHash)

    t.accountNumber = 1
    let tx = t.createSubmission('content', commitHash)
    await shouldFail.reverting(tx)
  })
})