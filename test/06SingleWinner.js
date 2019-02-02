const IMatryxRound = artifacts.require('IMatryxRound')
const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')
const MatryxUser = artifacts.require('MatryxUser')
const IMatryxUser = artifacts.require('IMatryxUser')

const { Contract } = require('../truffle/utils')
const { init, createTournament, waitUntilInReview, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform
let users = Contract(MatryxUser.address, IMatryxUser, 0)
let c = Contract(MatryxCommit.address, IMatryxCommit, 0)

//
// Case 1
//
contract('Singleton Commit, Close Tournament', function() {
  let t //tournament
  let r //round
  let s //submission

  it('Able to create a Submission', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    s = await createSubmission(t, '0x00', false, 1)

    assert.ok(s, 'Submission is not valid.')
  })

  it('Only the tournament owner can choose winning submissions', async function() {
    let submissions = await r.getSubmissions()
    waitUntilInReview(r)

    try {
      //make the call from accounts[1]
      t.accountNumber = 1
      await t.selectWinners([submissions, [1], 2], [0, 0, 0, 0])
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      //set account back to tournament owner
      t.accountNumber = 0
      assert(revertFound, 'This account should not have been able to choose winners')
    }
  })

  it('Unable to choose nonexisting submission to win the round', async function() {
    let submissions = [t.address]
    try {
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to choose nonexisting submission')
    }
  })

  it('Able to choose a winner and Close Tournament', async function() {
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.isTrue(b > 0, 'Winner was not chosen')
  })

  it('Tournament should be closed', async function() {
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament is not Closed')
  })

  it('Round should be closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('Total tournament + round bounty assigned to the winning submission', async function() {
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 10, 'Commit balance should equal initial tournament bounty')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.isTrue(tB == 0 && rB == 0, 'Tournament and round balance should both be 0')
  })

  it('Submission owner able to withdraw reward', async function () {
    let balBefore = await platform.getBalanceOf(accounts[1]).then(fromWei)
    await c.distributeReward(s)
    let b = await platform.getCommitBalance(s).then(fromWei)
    let balAfter = await platform.getBalanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter - balBefore, 10, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async function () {
    try {
      await c.distributeReward(s)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

//
// Case 2
//
contract('Singleton Commit, Start Next Round', function() {
  let t  //tournament
  let r  //round
  let nr // new round (after choosing winners)
  let s  //submission

  it('Able to create a Submission without Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    s = await createSubmission(t, '0x00',  false, 1)

    assert.ok(s, 'Submission is not valid.')
  })

  it('Able to choose a winner and Start Next Round', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.isTrue(b > 0, 'Winner was not chosen')
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
    assert.equal(rpd, 120, 'Incorrect new round review period')
  })

  it('New round bounty is correct', async function() {
    let nrb = await nr.getBounty().then(fromWei)
    assert.equal(nrb, 5, 'Incorrect new round bounty')
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
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.equal(rB, 0, 'First round balance should be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 5, 'Incorrect submission balance')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, '0x00',  false, 1)
    assert.ok(s2, 'Unable to make submissions to the new round.')
  })

  it('Submission owner able to withdraw reward', async function () {
    let balBefore = await platform.getBalanceOf(accounts[1]).then(fromWei)
    await c.distributeReward(s)
    let b = await platform.getCommitBalance(s).then(fromWei)
    let balAfter = await platform.getBalanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter - balBefore, 5, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async function () {
    try {
      await c.distributeReward(s)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

// Case 3

contract('Singleton Commit, Do Nothing', function() {
  let t //tournament
  let r //round
  let s //submission

  it('Able to create a Submission without Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 20,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    s = await createSubmission(t, '0x00',  false, 1)

    assert.ok(s, 'Submission is not valid.')
  })

  it('Able to choose a winner and DoNothing', async function() {
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 5, 'Winner was not chosen')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round should be in State HasWinners', async function() {
    let state = await r.getState()
    assert.equal(state, 4, 'Round is not in state HasWinners')
  })

  it('Round balance should now be 0', async function() {
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('Ghost round address exists', async function() {
    let rounds = await t.getRounds()
    gr = rounds[rounds.length - 1]
    assert.isTrue(gr != r.address, 'Ghost round address does not exist')
  })

  it('Ghost round Review Period Duration is correct', async function() {
    gr = Contract(gr, IMatryxRound, 0)
    let grrpd = await gr.getReview()
    assert.equal(grrpd, 60, 'Incorrect ghost round Review Period Duration')
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
    assert.equal(grB, 5, 'Ghost round balance should be 5')
  })

  it('Submission owner able to withdraw reward', async function () {
    let balBefore = await platform.getBalanceOf(accounts[1]).then(fromWei)
    await c.distributeReward(s)
    let b = await platform.getCommitBalance(s).then(fromWei)
    let balAfter = await platform.getBalanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter - balBefore, 5, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async function () {
    try {
      await c.distributeReward(s)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

//
// Case 4
//
contract('Singleton Commit, Do Nothing, then Close Tournament', function() {
  let t //tournament
  let r //round
  let s //submission
  let gr //ghost round

  it('Able to choose a winning submission and Do Nothing', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    s = await createSubmission(t, '0x00',  false, 1)
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    // get ghost round
    let rounds = await t.getRounds()
    let grA = rounds[rounds.length - 1]
    gr = Contract(grA, IMatryxRound, 0)

    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 5, 'Winner was not chosen')
  })

  it('Able to Close the tournament after selecting winners & Do Nothing', async function() {
    await t.closeTournament()
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament should be Closed')
  })

  it('Round state should be Closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round should be Closed')
  })

  it('Current round is still the initial round', async function() {
    let cr = await t.getCurrentRound()
    assert.equal(cr[1], r.address, 'Current round should be the initial round')
  })

  it('Ghost round no longer exists in tournament', async function() {
    let rounds = await t.getRounds()
    assert.isTrue(rounds.length == 1, 'Ghost round should no longer exist')
  })

  it('Tournament balance should now be 0', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 0, 'Tournament balance should be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.isTrue(rB == 0, 'First round balance should be 0')
  })

  it('Ghost Round balance should be 0', async function() {
    let grB = await platform.getBalanceOf(gr.address).then(fromWei)
    assert.equal(grB, 0, 'Ghost round balance should be 0')
  })

  it('Correct winning submission balance', async function() {
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 10, 'Incorrect commit balance')
  })

  it('Submission owner able to withdraw reward', async function () {
    let balBefore = await platform.getBalanceOf(accounts[1]).then(fromWei)
    await c.distributeReward(s)
    let b = await platform.getCommitBalance(s).then(fromWei)
    let balAfter = await platform.getBalanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter - balBefore, 10, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async function () {
    try {
      await c.distributeReward(s)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

//
// Case 5
//
contract('Singleton Commit, Do Nothing, then Start Next Round', function() {
  let t //tournament
  let r //round
  let s //submission
  let gr //ghost round

  it('Able to choose a winning submission and Do Nothing', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    s = await createSubmission(t, '0x00',  false, 1)
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    // get ghost round
    let rounds = await t.getRounds()
    let grA = rounds[rounds.length - 1]
    gr = Contract(grA, IMatryxRound, 0)

    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 5, 'Winner was not chosen')
  })

  it('Able to start next round after selecting winners & Do Nothing', async function() {
    await t.startNextRound()
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament should be Open')
  })

  it('Initial round should be Closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Initial round should be Closed')
  })

  it('New round should be Open', async function() {
    let state = await gr.getState()
    assert.equal(state, 2, 'New round should be Open')
  })

  it('Former ghost round is now current round', async function() {
    let cr = await t.getCurrentRound()
    assert.equal(cr[1], gr.address, 'Ghost round should now be current round')
  })

  it('Tournament balance should be 5', async function() {
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('First Round balance should be 0', async function() {
    let rB = await platform.getBalanceOf(r.address).then(fromWei)
    assert.equal(rB, 0, 'Round balance should be 0')
  })

  it('New Round balance should be 5', async function() {
    let grB = await platform.getBalanceOf(gr.address).then(fromWei)
    assert.equal(grB, 5, 'New round balance should be 5')
  })

  it('Correct winning submission balance', async function() {
    let b = await platform.getCommitBalance(s).then(fromWei)
    assert.equal(b, 5, 'Incorrect commit balance')
  })

  it('Submission owner able to withdraw reward', async function () {
    let balBefore = await platform.getBalanceOf(accounts[1]).then(fromWei)
    await c.distributeReward(s)
    let b = await platform.getCommitBalance(s).then(fromWei)
    let balAfter = await platform.getBalanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter - balBefore, 5, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async function () {
    try {
      await c.distributeReward(s)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })
})