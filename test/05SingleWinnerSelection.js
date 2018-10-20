const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')

const { Contract } = require('../truffle/utils')
const { init, createTournament, waitUntilInReview, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)

let platform

//
// Case 1
//
contract('Single Winning Submission with No Contribs or Refs and Close Tournament', function(accounts) {
  let t //tournament
  let r //round
  let s //submission
  let tBounty //Initial Tournament Bounty

  it('Able to create a Submission without Contributors and References', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    utime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Only the tournament owner can choose winning submissions', async function() {
    let submissions = await r.getSubmissions(0, 0)
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
    tBounty = await t.getBounty().then(fromWei)
    rBounty = await r.getBounty().then(fromWei)
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
    let winnings = await s.getTotalWinnings().then(fromWei)
    assert(winnings, 'Winner was not chosen')
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
    let winnings = await s.getTotalWinnings().then(fromWei)
    assert.equal(winnings, fromWei(tBounty), 'Winnings should equal initial tournament bounty')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let tB = await t.getBalance().then(fromWei)
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(tB == 0 && fromWei(rB) == 0, 'Tournament and round balance should both be 0')
  })

  it('Submission balance should be initial tournament + round bounty', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, fromWei(tBounty), 'Winnings should equal initial tournament bounty')
  })

  it('Unable to withdraw reward from some other account', async function() {
    try {
      // switch to accounts[2]
      s.accountNumber = 2
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      // switch back to submission owner
      s.accountNumber = 1
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 0, 'Submission balance should now be 0')
  })

  it('Unable to withdraw reward twice from the same account', async function() {
    try {
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

})


//
// Case 2
//
contract('Single Winning Submission with Contribs and Refs and Close Tournament', function(accounts) {
  let t //tournament
  let r //round
  let s //submission

  it('Able to create a Submission with Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with some contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    //add accounts[3] as a new contributor
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }

    await s.setContributorsAndReferences(contribs, [1], [[], []])

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Able to choose a winning submission with Contribs and Refs', async function() {
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
    let winnings = await s.getTotalWinnings().then(fromWei)
    assert(winnings, 'Winner was not chosen')
  })

  it('Submission owner should get 50% of the reward', async function() {
    s.accountNumber = 1
    let myReward = await s.getAvailableReward().then(fromWei)
    assert.isTrue(myReward == 5, 'Winnings should equal initial tournament bounty')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s.accountNumber = 3
    let myReward = await s.getAvailableReward().then(fromWei)
    s.accountNumber = 1
    assert.isTrue(myReward == 5 / contribs.length, 'Winnings should equal initial tournament bounty')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let tB = await t.getBalance().then(fromWei)
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(tB == 0 && fromWei(rB) == 0, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 10', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 10, 'Incorrect submission balance')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 5, 'Submission balance should now be 5')
  })

  it('Unable to withdraw reward twice from the same account', async function() {
    try {
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })
})

//
// Case 3
//
contract('Single Winning Submission with no Contribs or Refs and Start Next Round', function(accounts) {
  let t //tournament
  let r //round
  let nr // new round (after choosing winners)
  let s //submission

  it('Able to create a Submission without Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    utime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Able to choose a winner and Start Next Round', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    tBounty = await t.getBounty().then(fromWei)
    rBounty = await r.getBounty().then(fromWei)
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)
    let winnings = await s.getTotalWinnings().then(fromWei)
    assert(winnings, 'Winner was not chosen')
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

  it('Total round bounty assigned to the winning submission', async function() {
    let myReward = await s.getAvailableReward().then(fromWei)
    assert.equal(myReward, 5, 'Winnings should equal initial tournament bounty')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament and round balance should both be 0')
  })

  it('New Round balance should be 5', async function() {
    let nrB = await nr.getBalance().then(fromWei)
    assert.equal(nrB, 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 5, 'Incorrect submission balance')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, false, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 1)
    assert.ok(s2.address, 'Submission is not valid.')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 0, 'Submission balance should now be 0')
  })

})

// Case 4

contract('Single Winning Submission with Contribs and Refs and Start Next Round', function(accounts) {
  let t //tournament
  let r //round
  let nr //new round
  let s //submission

  it('Able to create a Submission with Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with some contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    //add accounts[3] as a new contributor
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }

    await s.setContributorsAndReferences(contribs, [1], [[], []])

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Able to choose a winning submission and Start Next Round', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 120,
      review: 120,
      bounty: web3.toWei(5)
    }

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)

    let winnings = await s.getTotalWinnings().then(fromWei)
    assert(winnings, 'Winner was not chosen')
  })

  it('Submission owner should get 50% of the reward', async function() {
    s.accountNumber = 1
    let myReward = await s.getAvailableReward().then(fromWei)
    assert.isTrue(myReward == 5 / 2, 'Winnings should equal half of initial tournament bounty')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s.accountNumber = 3
    let myReward = await s.getAvailableReward().then(fromWei)
    s.accountNumber = 1
    assert.isTrue(myReward == 5 / 2 / contribs.length, 'Bounty not distributed correctly among contributors')
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
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament and round balance should both be 0')
  })

  it('New Round balance should be 5', async function() {
    let nrB = await nr.getBalance().then(fromWei)
    assert.equal(nrB, 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 5, 'Incorrect submission balance')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, false, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 1)
    assert.ok(s2.address, 'Submission is not valid.')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 5 / 2, 'Submission balance should now be 5/2')
  })
})

// Case 5

contract('Single Winning Submission with no Contribs or Refs and Do Nothing', function(accounts) {
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

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    utime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Able to choose a winner and DoNothing', async function() {
    tBounty = await t.getBounty().then(fromWei)
    rBounty = await r.getBounty().then(fromWei)
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)
    let winnings = await s.getTotalWinnings().then(fromWei)
    assert(winnings, 'Winner was not chosen')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round should be in State HasWinners', async function() {
    let state = await r.getState()
    assert.equal(state, 4, 'Round is not in state HasWinners')
  })

  it('100% of the round bounty assigned to the winning submission', async function() {
    let winnings = await s.getTotalWinnings().then(fromWei)
    assert.equal(winnings, 5, 'Winnings should equal initial tournament bounty')
  })

  it('Round balance should now be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('Ghost round address exists', async function() {
    let rounds = await t.getRounds()
    gr = rounds[rounds.length - 1]
    assert.ok(gr, 'Ghost round address does not exit')
  })

  it('Ghost round Review Period Duration is correct', async function() {
    gr = Contract(gr, IMatryxRound, 0)
    let grrpd = await gr.getReview()
    assert.equal(grrpd, 60, 'New round details not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty().then(fromWei)
    assert.equal(grb, 5, 'New round details not updated correctly')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament and round balance should both be 0')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance().then(fromWei)
    assert.equal(grB, 5, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 5, 'Incorrect submission balance')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 0, 'Submission balance should now be 0')
  })

})

//
// Case 6
//
contract('Single Winning Submission with Contribs and Refs and Do Nothing', function(accounts) {
  let t //tournament
  let r //round
  let s //submission
  let gr //ghost round

  it('Able to create a Submission with Contributors and References', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 20,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with some contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    //add accounts[3] as a new contributor
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }

    await s.setContributorsAndReferences(contribs, [1], [[], []])

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Able to choose a winning submission and Do Nothing', async function() {
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let winnings = await s.getTotalWinnings().then(fromWei)
    assert(winnings, 'Winner was not chosen')
  })

  it('Submission owner should get 50% of the reward', async function() {
    s.accountNumber = 1
    let myReward = await s.getAvailableReward().then(fromWei)
    assert.isTrue(myReward == 5 / 2, 'Winnings should equal half of initial tournament bounty')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s.accountNumber = 3
    let myReward = await s.getAvailableReward().then(fromWei)
    //switch back to accounts[1]
    s.accountNumber = 1
    assert.isTrue(myReward == 5 / 2 / contribs.length, 'Bounty not distributed correctly among contributors')
  })

  it('Tournament should be open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round state should be Has Winners', async function() {
    let state = await r.getState()
    assert.equal(state, 4, 'Round is not in state HasWinners')
  })

  it('Ghost round address exists', async function() {
    let rounds = await t.getRounds()
    gr = rounds[rounds.length - 1]
    assert.ok(gr, 'Ghost round address does not exit')
  })

  it('Ghost round Review Period Duration is correct', async function() {
    gr = Contract(gr, IMatryxRound, 0)
    let grrpd = await gr.getReview()
    assert.equal(grrpd, 20, 'New round details not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty().then(fromWei)
    assert.equal(grb, 5, 'New round details not updated correctly')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament and round balance should both be 0')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance().then(fromWei)
    assert.equal(grB, 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 5, 'Incorrect submission balance')
  })

  it('Unable to withdraw reward from some other account', async function() {
    try {
      // switch to accounts[4]
      s.accountNumber = 4
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      // switch back to submission owner
      s.accountNumber = 1
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 5 / 2, 'Submission balance should now be 5/2')
  })
})

//
// Case 7
//
contract('Single Winning Submission and Do Nothing, then Close Tournament', function(accounts) {
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

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with some contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    // get ghost round
    let rounds = await t.getRounds()
    let grA = rounds[rounds.length - 1]
    gr = Contract(grA, IMatryxRound, 0)

    let winnings = await s.getTotalWinnings().then(fromWei)
    assert.isTrue(winnings > 0, 'Winner was not chosen')
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
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 0, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('Ghost Round balance should be 0', async function() {
    let grB = await gr.getBalance().then(fromWei)
    assert.equal(grB, 0, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 10', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 10, 'Incorrect submission balance')
  })

  it('Winning submission available reward should be 10', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 10, 'Incorrect available reward')
  })

  it('Unable to withdraw reward from some other account', async function() {
    try {
      // switch to accounts[2]
      s.accountNumber = 2
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      // switch back to submission owner
      s.accountNumber = 1
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

  it('Able to withdraw my reward, submission balance should go to 0', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 0, 'Submission balance should now be 0')
  })

  it('Unable to withdraw reward twice from the same account', async function() {
    try {
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

})

//
// Case 8
//
contract('Single Winning Submission and Do Nothing, then Start Next Round', function(accounts) {
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

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with some contributors
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    // get ghost round
    let rounds = await t.getRounds()
    let grA = rounds[rounds.length - 1]
    gr = Contract(grA, IMatryxRound, 0)

    let winnings = await s.getTotalWinnings().then(fromWei)
    assert.isTrue(winnings > 0, 'Winner was not chosen')
  })

  it('Able to start next round after selecting winners & Do Nothing', async function() {
    await t.startNextRound()
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament should be Open')
  })

  it('Initial round state should be Closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round should be Closed')
  })

  it('New round state should be Open', async function() {
    let state = await gr.getState()
    assert.equal(state, 2, 'Round should be Open')
  })

  it('Former ghost round is now current round', async function() {
    let cr = await t.getCurrentRound()
    assert.equal(cr[1], gr.address, 'Ghost round should now be current round')
  })

  it('Tournament balance should be 5', async function() {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('New Round balance should be 5', async function() {
    let grB = await gr.getBalance().then(fromWei)
    assert.equal(grB, 5, 'Round balance should be 5')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 5, 'Incorrect submission balance')
  })

  it('Winning submission available reward should be 5', async function() {
    let b = await s.getBalance().then(fromWei)
    assert.equal(b, 5, 'Incorrect available reward')
  })

  it('Unable to withdraw reward from some other account', async function() {
    try {
      // switch to accounts[2]
      s.accountNumber = 2
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      // switch back to submission owner
      s.accountNumber = 1
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

  it('Able to withdraw my reward, submission balance should go to 0', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance().then(fromWei)
    assert.equal(sb, 0, 'Submission balance should now be 0')
  })

  it('Unable to withdraw reward twice from the same account', async function() {
    try {
      await s.withdrawReward()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward')
    }
  })

})