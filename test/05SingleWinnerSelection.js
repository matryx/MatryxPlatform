let fs = require('fs')
const MatryxSystem = artifacts.require('MatryxSystem')
const MatryxPlatform = artifacts.require('MatryxPlatform')
const IMatryxPlatform = artifacts.require('IMatryxPlatform')
const IMatryxTournament = artifacts.require('IMatryxTournament')
const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')
const MatryxToken = artifacts.require('MatryxToken')
const LibUtils = artifacts.require('LibUtils')
const LibPlatform = artifacts.require('LibPlatform')
const LibTournament = artifacts.require('LibTournament')
const LibRound = artifacts.require('LibRound')
const LibSubmission = artifacts.require('LibSubmission')

const { setup, getMinedTx, sleep, stringToBytes32, stringToBytes, bytesToString, Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)

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
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
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
    const roundEndTime = await r.getEnd()
    let timeTilRoundInReview = roundEndTime - Date.now() / 1000
    timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

    await sleep(timeTilRoundInReview * 1000)

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

  it('Able to choose a winner and Close Tournament', async function() {
    tBounty = await t.getBounty()
    rBounty = await r.getBounty()
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
    let winnings = await s.getTotalWinnings()
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
    let winnings = await s.getTotalWinnings()
    assert.equal(fromWei(winnings), fromWei(tBounty), 'Winnings should equal initial tournament bounty')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let tB = await t.getBalance()
    let rB = await r.getBalance()
    assert.isTrue(fromWei(tB) == 0 && fromWei(rB) == 0, 'Tournament and round balance should both be 0')
  })

  it('Submission balance should be initial tournament + round bounty', async function() {
    let b = await s.getBalance()
    assert.equal(fromWei(b), fromWei(tBounty), 'Winnings should equal initial tournament bounty')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance()
    assert.equal(sb, 0, 'Submission balance should now be 0')
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
    let winnings = await s.getTotalWinnings()
    assert(winnings, 'Winner was not chosen')
  })

  it('Submission owner should get 50% of the reward', async function() {
    s.accountNumber = 1
    let myReward = await s.getAvailableReward()
    assert.isTrue(fromWei(myReward) == 5, 'Winnings should equal initial tournament bounty')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s.accountNumber = 3
    let myReward = await s.getAvailableReward()
    s.accountNumber = 1
    assert.isTrue(fromWei(myReward) == 5 / contribs.length, 'Winnings should equal initial tournament bounty')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let tB = await t.getBalance()
    let rB = await r.getBalance()
    assert.isTrue(fromWei(tB) == 0 && fromWei(rB) == 0, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 10', async function() {
    let b = await s.getBalance()
    assert.equal(fromWei(b), 10, 'Incorrect submission balance')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance()
    assert.equal(fromWei(sb), 5, 'Submission balance should now be 5')
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
      end: Math.floor(Date.now() / 1000) + 10,
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

    tBounty = await t.getBounty()
    rBounty = await r.getBounty()
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)
    let winnings = await s.getTotalWinnings()
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
    let nrb = await nr.getBounty()
    assert.equal(fromWei(nrb), 5, 'New round details not updated correctly')
  })

  it('Total round bounty assigned to the winning submission', async function() {
    let myReward = await s.getAvailableReward()
    assert.equal(fromWei(myReward), 5, 'Winnings should equal initial tournament bounty')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 5, 'Tournament and round balance should both be 0')
  })

  it('New Round balance should be 5', async function() {
    let nrB = await nr.getBalance()
    assert.equal(fromWei(nrB), 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance()
    assert.isTrue(fromWei(rB) == 0, 'Round balance should be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance()
    assert.equal(fromWei(b), 5, 'Incorrect submission balance')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, false, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 1)
    assert.ok(s2.address, 'Submission is not valid.')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance()
    assert.equal(fromWei(sb), 0, 'Submission balance should now be 0')
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

    let winnings = await s.getTotalWinnings()
    assert(winnings, 'Winner was not chosen')
  })

  it('Submission owner should get 50% of the reward', async function() {
    s.accountNumber = 1
    let myReward = await s.getAvailableReward()
    assert.isTrue(fromWei(myReward) == 5 / 2, 'Winnings should equal half of initial tournament bounty')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s.accountNumber = 3
    let myReward = await s.getAvailableReward()
    s.accountNumber = 1
    assert.isTrue(fromWei(myReward) == 5 / 2 / contribs.length, 'Bounty not distributed correctly among contributors')
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
    let nrb = await nr.getBounty()
    assert.equal(fromWei(nrb), 5, 'New round details not updated correctly')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 5, 'Tournament and round balance should both be 0')
  })

  it('New Round balance should be 5', async function() {
    let nrB = await nr.getBalance()
    assert.equal(fromWei(nrB), 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance()
    assert.isTrue(fromWei(rB) == 0, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance()
    assert.equal(fromWei(b), 5, 'Incorrect submission balance')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, false, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 1)
    assert.ok(s2.address, 'Submission is not valid.')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance()
    assert.equal(fromWei(sb), 5 / 2, 'Submission balance should now be 5/2')
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
      end: Math.floor(Date.now() / 1000) + 10,
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
    tBounty = await t.getBounty()
    rBounty = await r.getBounty()
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)
    let winnings = await s.getTotalWinnings()
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
    let winnings = await s.getTotalWinnings()
    assert.equal(fromWei(winnings), 5, 'Winnings should equal initial tournament bounty')
  })

  it('Round balance should now be 0', async function() {
    let rB = await r.getBalance()
    assert.isTrue(fromWei(rB) == 0, 'Round balance should be 0')
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
    let grb = await gr.getBounty()
    assert.equal(fromWei(grb), 5, 'New round details not updated correctly')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 5, 'Tournament and round balance should both be 0')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance()
    assert.equal(fromWei(grB), 5, 'Tournament and round balance should both be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance()
    assert.equal(fromWei(b), 5, 'Incorrect submission balance')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance()
    assert.equal(fromWei(sb), 0, 'Submission balance should now be 0')
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

    let winnings = await s.getTotalWinnings()
    assert(winnings, 'Winner was not chosen')
  })

  it('Submission owner should get 50% of the reward', async function() {
    s.accountNumber = 1
    let myReward = await s.getAvailableReward()
    assert.isTrue(fromWei(myReward) == 5 / 2, 'Winnings should equal half of initial tournament bounty')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s.accountNumber = 3
    let myReward = await s.getAvailableReward()
    //switch back to accounts[1]
    s.accountNumber = 1
    assert.isTrue(fromWei(myReward) == 5 / 2 / contribs.length, 'Bounty not distributed correctly among contributors')
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
    let grb = await gr.getBounty()
    assert.equal(fromWei(grb), 5, 'New round details not updated correctly')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 5, 'Tournament and round balance should both be 0')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance()
    assert.equal(fromWei(grB), 5, 'Tournament and round balance should both be 0')
  })

  it('First Round balance should now be 0', async function() {
    let rB = await r.getBalance()
    assert.isTrue(fromWei(rB) == 0, 'Round balance should be 0')
  })

  it('Winning submission balance should be 5', async function() {
    let b = await s.getBalance()
    assert.equal(fromWei(b), 5, 'Incorrect submission balance')
  })

  it('Able to withdraw reward', async function() {
    await s.withdrawReward()
    let sb = await s.getBalance()
    assert.equal(fromWei(sb), 5 / 2, 'Submission balance should now be 5/2')
  })
})
