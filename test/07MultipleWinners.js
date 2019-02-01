const { expectEvent, shouldFail } = require('openzeppelin-test-helpers');
const IMatryxRound = artifacts.require('IMatryxRound')

const { Contract } = require('../truffle/utils')
const { init, createTournament, waitUntilInReview, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform

// Case 1
contract('Multiple Commits and Close Tournament', function() {
  let t //tournament
  let r //round
  let s1 //submission 1
  let s2 //submission 2
  let s3 //submission 3
  let s4 //submission 4

  it('Able to create Multiple Submissions with no Contributors and References', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    s1 = await createSubmission(t, 1)
    s2 = await createSubmission(t, 2)
    s3 = await createSubmission(t, 3)
    s4 = await createSubmission(t, 4)

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Unable to choose any nonexisting submissions to win the round', async function() {
    await waitUntilInReview(r)
    let submissions = [accounts[3], accounts[1], t.address, s2]
    
    const tx = selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
    await shouldFail.reverting(tx)
  })

  it('Able to choose multiple winners and close tournament', async function() {
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    let r1 = await platform.getCommitBalance(s1).then(fromWei)
    let r2 = await platform.getCommitBalance(s2).then(fromWei)
    let r3 = await platform.getCommitBalance(s3).then(fromWei)
    let r4 = await platform.getCommitBalance(s4).then(fromWei)

    let allEqual = [r1, r2, r3, r4].every(x => x === 10 / 4)
    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Tournament should be closed', async function() {
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament is not Closed')
  })

  it('Round should be closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.isTrue(tB == 0 && rB == 0, 'Tournament and round balance should both be 0')
  })

  it('All submission owners able to withdraw reward', async function () {
    for (let [i, s] of [s1, s2, s3, s4].entries()) {
      let balBefore = await platform.getBalanceOf(accounts[i + 1]).then(fromWei)
      await c.distributeReward(s)
      let balAfter = await platform.getBalanceOf(accounts[i + 1]).then(fromWei)
      assert.equal(balAfter - balBefore, 10 / 4, `Submission ${i + 1} owner balance incorrect`)
    }
  })

})

// Case 2
contract('Multiple Commits and Start Next Round', function() {
  let t //tournament
  let r //round
  let s1 //submission
  let s2
  let s3
  let s4

  it('Able to create Multiple Submissions with no Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s1 = await createSubmission(t, 1)
    s2 = await createSubmission(t, 2)
    s3 = await createSubmission(t, 3)
    s4 = await createSubmission(t, 4)

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners and start next round', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)
    let r1 = await platform.getCommitBalance(s1).then(fromWei)
    let r2 = await platform.getCommitBalance(s2).then(fromWei)
    let r3 = await platform.getCommitBalance(s3).then(fromWei)
    let r4 = await platform.getCommitBalance(s4).then(fromWei)
    let allEqual = [r1, r2, r3, r4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Tournament should be open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('New round should be open', async function() {
    const [_, newRoundAddress] = await t.getCurrentRound()
    nr = Contract(newRoundAddress, IMatryxRound)
    let state = await nr.getState()
    assert.equal(state, 2, 'Round is not Open')
  })

  it('New round details are correct', async function() {
    let rpd = await nr.getReview()
    assert.equal(rpd, 120, 'New round details not updated correctly')
  })

  it('New round bounty is correct', async function() {
    let nrb = await nr.getBounty().then(fromWei)
    assert.equal(nrb, 5, 'New round details not updated correctly')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('New Round balance should be 5', async function() {
    let nrB = await platform.getBalanceOf(nr.address).then(fromWei)
    assert.equal(nrB, 5, 'New round balance should be 5')
  })

  it('First Round balance should now be 0', async function() {
    r.accountNumber = 0
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.equal(rB, 0, 'First Round balance should be 0')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, 1)
    assert.ok(s2, 'Submission is not valid.')
  })

  it('All submission owners able to withdraw reward', async function () {
    for (let [i, s] of [s1, s2, s3, s4].entries()) {
      let balBefore = await platform.getBalanceOf(accounts[i + 1]).then(fromWei)
      await c.distributeReward(s)
      let balAfter = await platform.getBalanceOf(accounts[i + 1]).then(fromWei)
      assert.equal(balAfter - balBefore, 5 / 4, `Submission ${i + 1} owner balance incorrect`)
    }
  })
})

// Case 3
contract('Multiple Commits and Do Nothing', function() {
  let t //tournament
  let r //round
  let s1 //submission
  let s2
  let s3
  let s4

  it('Able to create Multiple Submissions with no Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s1 = await createSubmission(t, 1)
    s2 = await createSubmission(t, 2)
    s3 = await createSubmission(t, 3)
    s4 = await createSubmission(t, 4)

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners and do nothing', async function() {
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let r1 = await platform.getCommitBalance(s1).then(fromWei)
    let r2 = await platform.getCommitBalance(s2).then(fromWei)
    let r3 = await platform.getCommitBalance(s3).then(fromWei)
    let r4 = await platform.getCommitBalance(s4).then(fromWei)
    let allEqual = [r1, r2, r3, r4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round should be in State HasWinners', async function() {
    let state = await r.getState()
    assert.equal(state, 4, 'Round is not in state HasWinners')
  })

  it('Ghost round address exists', async function() {
    let rounds = await t.getRounds()
    gr = rounds[rounds.length - 1]
    assert.isTrue(gr != r.address, 'Ghost round address does not exit')
  })

  it('Ghost round Review Period Duration is correct', async function() {
    gr = Contract(gr, IMatryxRound, 0)
    let grrpd = await gr.getReview()
    assert.equal(grrpd, 60, 'Incorrect ghost round Review Period Duration')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.equal(rB, 0, 'First round balance should be 0')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty().then(fromWei)
    assert.equal(grb, 5, 'Incorrect ghost round bounty')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await platform.getBalanceOf(gr.address).then(fromWei)
    assert.equal(grB, 5, 'Ghost Round balance should be 5')
  })

  it('All submission owners able to withdraw reward', async function () {
    for (let [i, s] of [s1, s2, s3, s4].entries()) {
      let balBefore = await platform.getBalanceOf(accounts[i + 1]).then(fromWei)
      await c.distributeReward(s)
      let balAfter = await platform.getBalanceOf(accounts[i + 1]).then(fromWei)
      assert.equal(balAfter - balBefore, 5 / 4, `Submission ${i + 1} owner balance incorrect`)
    }
  })
  
})
