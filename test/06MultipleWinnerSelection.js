
const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')

const { Contract } = require('../truffle/utils')
const { init, createTournament, waitUntilInReview, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)

let platform

// Case 1
contract('Multiple Winning Submissions with No Contribs or Refs and Close Tournament', function(accounts) {
  let t //tournament
  let r //round
  let s1 //submission 1
  let s2 //submission 2
  let s3 //submission 3
  let s4 //submission 4

  it('Able to create Multiple Submissions with no Contributors and References', async function() {
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
    s1 = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)
    s4 = await createSubmission(t, false, 4)

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Unable to choose any nonexisting submissions to win the round', async function() {
    await waitUntilInReview(r)
    let submissions = [accounts[3], accounts[1], t.address, s2.address]
    try {
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to choose nonexisting submissions')
    }
  })

  it('Able to choose multiple winners and close tournament', async function() {
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    let r1 = await s1.getAvailableReward().then(fromWei)
    let r2 = await s2.getAvailableReward().then(fromWei)
    let r3 = await s3.getAvailableReward().then(fromWei)
    let r4 = await s4.getAvailableReward().then(fromWei)

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
    let tB = await t.getBalance().then(fromWei)
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(tB == 0 && rB == 0, 'Tournament and round balance should both be 0')
  })

  it('Balance of each winning submission should be 10/4', async function() {
    let b1 = await s1.getBalance().then(fromWei)
    let b2 = await s2.getBalance().then(fromWei)
    let b3 = await s3.getBalance().then(fromWei)
    let b4 = await s4.getBalance().then(fromWei)
    let allEqual = [b1, b2, b3, b4].every(x => x === 10 / 4)

    assert.isTrue(allEqual, 'Incorrect winning submissions balance')
  })
})

// Case 2
contract('Multiple Winning Submissions with Contribs and Refs and Close Tournament', function(accounts) {
  let t //tournament
  let r //round
  let s1 //submission 1
  let s2 //submission 2
  let s3 //submission 3
  let s4 //submission 4

  it('Able to create Multiple Submissions with Contributors and References', async function() {
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
    s1 = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)
    s4 = await createSubmission(t, false, 4)

    //add accounts[3] as a new contributor
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }
    await s1.setContributorsAndReferences(contribs, [1], [[], []])

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners and close tournament, winners get even share of 50% of bounty', async function() {
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    let r2 = await s2.getAvailableReward().then(fromWei)
    let r3 = await s3.getAvailableReward().then(fromWei)
    let r4 = await s4.getAvailableReward().then(fromWei)

    let allEqual = [r2, r3, r4].every(x => x === 10 / 4)
    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    contribs = await s1.getContributors()
    c = contribs[contribs.length]

    //switch to accounts[3]
    s1.accountNumber = 3
    let myReward = await s1.getAvailableReward().then(fromWei)
    //switch back to accounts[1]
    s1.accountNumber = 1
    assert.isTrue(myReward == 10 / 4 / 2, 'Contributor bounty allocation incorrect')
  })

  it('Tournament should be closed', async function() {
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament is not Closed')
  })

  it('Round should be closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('Able to get winning submission addresses', async function() {
    let wsubs = await r.getWinningSubmissions()
    assert.equal(wsubs.length, 4, 'Unable to get all winning submission addresses')
  })

  it('Tournament and Round balance should now be 0', async function() {
    let rB = await r.getBalance().then(fromWei)
    let tB = await t.getBalance().then(fromWei)
    assert.isTrue(tB == 0 && rB == 0, 'Tournament and round balance should both be 0')
  })

  it('Balance of each winning submission should be 10/4', async function() {
    let b2 = await s2.getBalance().then(fromWei)
    let b1 = await s1.getBalance().then(fromWei)
    let b3 = await s3.getBalance().then(fromWei)
    let b4 = await s4.getBalance().then(fromWei)
    let allEqual = [b1, b2, b3, b4].every(x => x === 10 / 4)

    assert.isTrue(allEqual, 'Balance of each winning submission should be 10/4')
  })
})

// Case 3
contract('Multiple Winning Submissions with no Contribs or Refs and Start Next Round', function(accounts) {
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

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s1 = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)
    s4 = await createSubmission(t, false, 4)

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners and start next round', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)
    let r1 = await s1.getAvailableReward().then(fromWei)
    let r2 = await s2.getAvailableReward().then(fromWei)
    let r3 = await s3.getAvailableReward().then(fromWei)
    let r4 = await s4.getAvailableReward().then(fromWei)
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

  it('5/4 of round bounty assigned to each winning submission', async function() {
    let myReward = await s1.getAvailableReward().then(fromWei)
    assert.equal(myReward, 5/4, 'Each wininng submission should have 5/4 reward')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('New Round balance should be 5', async function() {
    let nrB = await nr.getBalance().then(fromWei)
    assert.equal(nrB, 5, 'New round balance should be 5')
  })

  it('First Round balance should now be 0', async function() {
    r.accountNumber = 0
    let rB = await r.getBalance().then(fromWei)
    assert.equal(rB, 0, 'First Round balance should be 0')
  })

  it('Balance of each winning submission should be 5/4', async function() {
    let b1 = await s1.getBalance().then(fromWei)
    let b2 = await s2.getBalance().then(fromWei)
    let b3 = await s3.getBalance().then(fromWei)
    let b4 = await s4.getBalance().then(fromWei)
    let allEqual = [b1, b2, b3, b4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Incorrect winning submissions balance')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, false, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 1)
    assert.ok(s2.address, 'Submission is not valid.')
  })
})

// Case 4
contract('Multiple Winning Submissions with Contribs and Refs and Start Next Round', function(accounts) {
  let t //tournament
  let r //round
  let s1 //submission
  let s2
  let s3
  let s4

  it('Able to create Multiple Submissions with Contributors and References', async function() {
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
    s1 = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)
    s4 = await createSubmission(t, false, 4)

    //add accounts[3] as a new contributor
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }
    await s1.setContributorsAndReferences(contribs, [1], [[], []])

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners and start next round, winners get correct bounty allocation', async function() {
    let newRound = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)

    let r2 = await s2.getAvailableReward().then(fromWei)
    let r3 = await s3.getAvailableReward().then(fromWei)
    let r4 = await s4.getAvailableReward().then(fromWei)
    let allEqual = [r2, r3, r4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    //switch to accounts[3]
    s1.accountNumber = 3
    let myReward = await s1.getAvailableReward()
    //switch back to accounts[1]
    s1.accountNumber = 1
    assert.isTrue(fromWei(myReward) == 5 / 2 / 4, 'Available reward should be 5/2/4')
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
    r.accountNumber = 0
    let rB = await r.getBalance().then(fromWei)
    assert.isTrue(rB == 0, 'Round balance should be 0')
  })

  it('Able to make a submission to the new round', async function() {
    let s2 = await createSubmission(t, false, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 1)
    assert.ok(s2.address, 'Submission is not valid.')
  })

  it('Balance of each winning submission should be 5/4', async function() {
    let b1 = await s1.getBalance().then(fromWei)
    let b2 = await s2.getBalance().then(fromWei)
    let b3 = await s3.getBalance().then(fromWei)
    let b4 = await s4.getBalance().then(fromWei)
    let allEqual = [b1, b2, b3, b4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Incorrect winning submissions balance')
  })
})

// Case 5
contract('Multiple Winning Submissions with no Contribs or Refs and Do Nothing', function(accounts) {
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

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s1 = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)
    s4 = await createSubmission(t, false, 4)

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners and do nothing', async function() {
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let r1 = await s1.getAvailableReward().then(fromWei)
    let r2 = await s2.getAvailableReward().then(fromWei)
    let r3 = await s3.getAvailableReward().then(fromWei)
    let r4 = await s4.getAvailableReward().then(fromWei)
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

  it('Each winning submission gets 1/4 of 50% of round bounty', async function() {
    let w = await s1.getTotalWinnings().then(fromWei)
    assert.equal(w, 5 / 4, 'Each winning submission should get 5/4 winnings')
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
    let rB = await r.getBalance().then(fromWei)
    assert.equal(rB, 0, 'First round balance should be 0')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty().then(fromWei)
    assert.equal(grb, 5, 'Incorrect ghost round bounty')
  })

  it('Tournament balance should now be 5', async function() {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance().then(fromWei)
    assert.equal(grB, 5, 'Ghost Round balance should be 5')
  })

  it('Balance of each winning submission should be 5/4', async function() {
    let b1 = await s1.getBalance().then(fromWei)
    let b2 = await s2.getBalance().then(fromWei)
    let b3 = await s3.getBalance().then(fromWei)
    let b4 = await s4.getBalance().then(fromWei)

    let allEqual = [b1, b2, b3, b4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Incorrect winning submissions balance')
  })
})

// Case 6
contract('Multiple Winning Submissions with Contribs and Refs and Do Nothing', function(accounts) {
  let t //tournament
  let r //round
  let s1 //submission
  let s2
  let s3
  let s4

  it('Able to create Multiple Submissions with Contributors and References', async function() {
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
    s1 = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)
    s4 = await createSubmission(t, false, 4)

    //add accounts[3] as a new contributor
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }
    await s1.setContributorsAndReferences(contribs, [1], [[], []])

    assert.ok(s1 && s2 && s3 && s4, 'Unable to create submissions.')
  })

  it('Able to choose multiple winners, winners get correct bounty allocation', async function() {
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let r2 = await s2.getAvailableReward().then(fromWei)
    let r3 = await s3.getAvailableReward().then(fromWei)
    let r4 = await s4.getAvailableReward().then(fromWei)

    let allEqual = [r2, r3, r4].every(x => x === 5 / 4)
    assert.isTrue(allEqual, 'Bounty not distributed correctly among all winning submissions.')
  })

  it('Remaining 50% of Bounty allocation distributed correctly to contributors', async function() {
    //switch to accounts[3]
    s1.accountNumber = 3
    let myReward = await s1.getAvailableReward()
    //switch back to accounts[1]
    s1.accountNumber = 1
    assert.isTrue(fromWei(myReward) == 5 / 2 / 4, 'Incorrect contributor available reward')
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
    assert.isTrue(gr != r.address, 'Ghost round address does not exit')
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
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance().then(fromWei)
    assert.equal(grB, 5, 'Ghost round balance should be 5')
  })

  it('First Round balance should now be 0', async function() {
    r.accountNumber = 0
    let rB = await r.getBalance().then(fromWei)
    assert.equal(rB, 0, 'First round balance should be 0')
  })

  it('Balance of each winning submission should be 5/4', async function() {
    let b1 = await s1.getBalance().then(fromWei)
    let b2 = await s2.getBalance().then(fromWei)
    let b3 = await s3.getBalance().then(fromWei)
    let b4 = await s4.getBalance().then(fromWei)

    let allEqual = [b1, b2, b3, b4].every(x => x === 5 / 4)

    assert.isTrue(allEqual, 'Incorrect winning submissions balance')
  })
})
