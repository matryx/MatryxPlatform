const { init, createTournament, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform, commit, token

// Case 1
contract('Multiple Commits and Close Tournament', function() {
  let t //tournament
  let submissions = []
  let commits = []

  before(async function() {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)

    for (let i = 1; i <= 4; i++) {
      let s = await createSubmission(t, '0x00', toWei(1), i)
      let ch = (await platform.getSubmission(s)).commitHash
      submissions.push(s)
      commits.push(ch)
    }
  })

  it('Unable to choose any nonexisting submissions to win the round', async function () {
    try {
      let submissions = [accounts[3], accounts[1], t.address]
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'This account should not have been able to choose winners')
    }
  })

  it('Able to choose multiple winners and close tournament', async function() {
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    let balances = await Promise.all(commits.map(c => platform.getCommitBalance(c).then(fromWei)))
    let allEqual = balances.every(x => x === 10 / 4)

    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Tournament should be closed', async function() {
    let state = await t.getState()
    assert.equal(+state, 3, 'Tournament is not Closed')
  })

  it('Round should be closed', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(+state, 5, 'Round is not Closed')
  })

  it('Tournament balance should now be 0', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 0, 'Tournament and round balance should both be 0')
  })

  it('All submission owners able to withdraw reward', async function () {
    for (let [i, c] of commits.entries()) {
      let balBefore = await token.balanceOf(accounts[i + 1]).then(fromWei)
      commit.accountNumber = i + 1
      await commit.withdrawAvailableReward(c)
      let balAfter = await token.balanceOf(accounts[i + 1]).then(fromWei)

      assert.equal(balAfter - balBefore, 10 / 4, `Submission ${i + 1} owner balance incorrect`)
    }
  })
})

// Case 2
contract('Multiple Commits and Start Next Round', function() {
  let t //tournament
  let submissions = []
  let commits = []

  before(async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)

    for (let i = 1; i <= 4; i++) {
      let s = await createSubmission(t, '0x00', toWei(1), i)
      let ch = (await platform.getSubmission(s)).commitHash
      submissions.push(s)
      commits.push(ch)
    }
  })

  it('Able to choose multiple winners and start next round', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      duration: 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)

    let balances = await Promise.all(commits.map(c => platform.getCommitBalance(c).then(fromWei)))
    let allEqual = balances.every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Tournament should be open', async function() {
    let state = await t.getState()
    assert.equal(+state, 2, 'Tournament is not Open')
  })

  it('New round should be open', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(+state, 2, 'Round is not Open')
  })

  it('New round details are correct', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { review, bounty } = await t.getRoundDetails(roundIndex)
    assert.equal(review, 120, 'New round review not updated correctly')
    assert.equal(fromWei(bounty), 5, 'New round bounty not updated correctly')
  })

  it('Tournament balance should now be 10', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 10, 'Tournament balance should be 10')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, '0x00', toWei(1), 1)
    assert.ok(s2, 'Submission is not valid.')
  })

  it('All submission owners able to withdraw reward', async function () {
    for (let [i, c] of commits.entries()) {
      let balBefore = await token.balanceOf(accounts[i + 1]).then(fromWei)
      commit.accountNumber = i + 1
      await commit.withdrawAvailableReward(c)
      let balAfter = await token.balanceOf(accounts[i + 1]).then(fromWei)

      assert.equal(balAfter - balBefore, 5 / 4, `Submission ${i + 1} owner balance incorrect`)
    }
  })
})

// Case 3
contract('Multiple Commits and Do Nothing', function() {
  let t //tournament
  let submissions = []
  let commits = []

  before(async function () {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)

    for (let i = 1; i <= 4; i++) {
      let s = await createSubmission(t, '0x00', toWei(1), i)
      let ch = (await platform.getSubmission(s)).commitHash
      submissions.push(s)
      commits.push(ch)
    }
  })

  it('Able to choose winners and do nothing', async function() {
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let balances = await Promise.all(commits.map(c => platform.getCommitBalance(c).then(fromWei)))
    let allEqual = balances.every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(+state, 2, 'Tournament is not Open')
  })

  it('Round should be in State HasWinners', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(+state, 4, 'Round is not in state HasWinners')
  })

  it('Tournament balance should now be 10', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 10, 'Tournament balance should be 10')
  })

  it('All submission owners able to withdraw reward', async function () {
    for (let [i, c] of commits.entries()) {
      let balBefore = await token.balanceOf(accounts[i + 1]).then(fromWei)
      commit.accountNumber = i + 1
      await commit.withdrawAvailableReward(c)
      let balAfter = await token.balanceOf(accounts[i + 1]).then(fromWei)

      assert.equal(balAfter - balBefore, 5 / 4, `Submission ${i + 1} owner balance incorrect`)
    }
  })
})
