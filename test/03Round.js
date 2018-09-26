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
const { init, createTournament, createSubmission, waitUntilInReview, waitUntilClose, selectWinnersWhenInReview, enterTournament } = require('./helpers')(artifacts, web3)

let platform

contract('NotYetOpen Round Testing', function(accounts) {
  let t //tournament
  let r //round

  it('Able to create a tournament with a valid round', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000) + 60,
      end: Math.floor(Date.now() / 1000) + 120,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round is not valid.')
  })

  it('Able to get tournament from round', async function() {
    let tournament = await r.getTournament()
    assert.equal(tournament, t.address, 'Unable to get tournament from round.')
  })

  it('Able to get round start time', async function() {
    let time = await r.getStart()
    assert.isTrue(time > Math.floor(Date.now() / 1000), 'Unable to get start time.')
  })

  it('Able to get round end time', async function() {
    let time = await r.getEnd()
    assert.isTrue(time > Math.floor(Date.now() / 1000), 'Unable to get end time.')
  })

  it('Able to get round review period duration', async function() {
    let review = await r.getReview()
    assert.equal(review, 60, 'Unable to get review period duration.')
  })

  it('Able to get round bounty', async function() {
    let b = await r.getBounty()
    assert.equal(b, web3.toWei(5), 'Unable to get bounty.')
  })

  it('Round balance should be the same as original bounty', async function() {
    let b = await r.getBalance()
    assert.equal(b, web3.toWei(5), 'Unable to get remaining bounty.')
  })

  it('Round state is Not Yet Open', async function() {
    let state = await r.getState()
    assert.equal(state, 0, 'Round State should be NotYetOpen')
  })

  it('Round should not have any submissions', async function() {
    let sub = await r.getSubmissions(0, 0)
    assert.equal(sub.length, 0, 'Round should not have submissions')
  })

  // TODO add this
  // it('Number of submissions should be zero', async function() {
  //   let no_sub = await r.numberOfSubmissions()
  //   assert.equal(no_sub.toNumber(), 0, 'Number of Submissions should be Zero')
  // })

  it('Add bounty to a round', async function() {
    await t.transferToRound(web3.toWei(1))
    let b = await r.getBounty()
    assert.equal(fromWei(b), 6, 'Bounty was not added')
  })

  it('Able to enter Not Yet Open round', async function() {
    let isEnt = await enterTournament(t, 2)
    assert.isTrue(isEnt, 'Could not enter tournament')
  })
})

contract('Open Round Testing', function(accounts) {
  let t //tournament
  let r //round

  it('Able to create a tournament with a Open round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 120,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round is not valid.')
  })

  it('Round state is Open', async function() {
    let state = await r.getState()
    assert.equal(state, 2, 'Round State should be Open')
  })

  it('Round should not have any submissions', async function() {
    let sub = await r.getSubmissions(0, 0)
    assert.equal(sub.length, 0, 'Round should not have submissions')
  })

  // TODO add this
  // it('Number of submissions should be zero', async function() {
  //   let no_sub = await r.getNumberOfSubmissions()
  //   assert.equal(no_sub.toNumber(), 0, 'Number of Submissions should be Zero')
  // })

  it('Add bounty to a round', async function() {
    await t.transferToRound(web3.toWei(1))
    let b = await r.getBounty()
    assert.equal(fromWei(b), 6, 'Bounty was not added')
  })

  it('Able to enter the tournament and make submissions', async function() {
    // Create submissions
    s = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    assert.ok(s && s2, 'Unable to make submissions')
  })

  it('Able to exit the tournament and collect my entry fee', async function() {
    // Switch to accounts[1]
    t.accountNumber = 1
    let isEnt = await t.isEntrant(accounts[1])
    await t.exit()
    isEnt = await t.isEntrant(accounts[1])
    assert.isFalse(isEnt, 'Unable to exit tournament')
  })

  it('Unable to collect my entry fee multiple times', async function() {
    try {
      t.accountNumber = 1
      await t.exit()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to round in review')
    }
  })

  it('Number of entrants should now be 0', async function() {
    let ent = await t.getEntrantCount()
    assert.equal(ent, 1, 'Number of entrants should be 0')
  })

  // TODO add this
  // it('Number of submissions should still be two', async function() {
  //   let n_sub = await r.numberOfSubmissions()
  //   assert.equal(n_sub.toNumber(), 2, 'Number of Submissions should be 2')
  // })
})

contract('In Review Round Testing', function(accounts) {
  let t //tournament
  let r //round
  let s //submission

  it('Able to create a round In Review', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submissions
    s = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    await waitUntilInReview(r)

    assert.ok(r.address, 'Round is not valid.')
  })

  it('Round state is In Review', async function() {
    let state = await r.getState()
    assert.equal(state, 3, 'Round State should be In Review')
  })

  it('Able to allocate more tournament bounty to a round in review', async function() {
    await t.transferToRound(web3.toWei(1))
    let bal = await r.getBalance()
    assert.equal(fromWei(bal), 6, 'Incorrect round balance')
  })

  it('Able to enter round in review', async function() {
    let isEnt = await enterTournament(t, 3)
    assert.isTrue(isEnt, 'Could not enter tournament')
  })

//   it('Unable to make submissions while the round is in review', async function() {
//     const title = stringToBytes32('A submission ', 3)
//     const descHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
//     const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

//     const submissionData = {
//       title,
//       descHash,
//       fileHash,
//       contributors: [],
//       distribution: [1],
//       references: []
//     }

//     //switch to accounts[1]
//     t.accountNumber = 1
//     try {
//       await t.createSubmission(submissionData)
//       assert.fail('Expected revert not received')
//     } catch (error) {
//       t.accountNumber = 0
//       let revertFound = error.message.search('revert') >= 0
//       assert(revertFound, 'Should not have been able to make a submission while In Review')
//     }
//   })
// })

  it('Unable to make submissions while the round is in review', async function() {
    try {
      await createSubmission(t, false, 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while In Review')
    }
  })
})

contract('Closed Round Testing', function(accounts) {
  let t //tournament
  let r //round
  let s //submission

  it('Able to create a closed round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submissions
    s = await createSubmission(t, false, 1)

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Tournament should be closed', async function() {
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament is not Closed')
  })

  it('Round should be closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('Unable to allocate more tournament bounty to a closed round', async function() {
    try {
      await t.transferToRound(web3.toWei(1))
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to Closed round')
    }
  })

  it('Unable to enter closed tournament', async function() {
    try {
      await enterTournament(t, 2)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to Closed round')
    }
  })

  it('Unable to make submissions while the round is closed', async function() {
    try {
      await createSubmission(t, false, 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while In Review')
    }
  })
})

contract('Abandoned Round Testing', function(accounts) {
  let t //tournament
  let r //round

  it('Able to create an Abandoned round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 20,
      review: 1,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)

    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    // Create a submission
    s = await createSubmission(t, false, 1)
    s = await createSubmission(t, false, 2)

    // Wait for the round to become Abandoned
    await waitUntilClose(r)

    assert.ok(r.address, 'Round is not valid.')
  })

  it('Round state is Abandoned', async function() {
    let state = await r.getState()
    assert.equal(state, 6, 'Round State should be Abandoned')
  })

  it('Unable to add bounty to Abandoned round', async function() {
    try {
      await t.transferToRound(web3.toWei(1))
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to Abandoned round')
    }
  })

  it('Round is still open in round data before the first withdraw', async function() {
    let data = await r.getData()
    assert.isFalse(data.info.closed, 'Round should be open')
  })

  it('First entrant is able to withdraw their share from the bounty from an abandoned round', async function() {
    // Switch to acounts[1]
    t.accountNumber = 1
    await t.withdrawFromAbandoned()
    let isEnt = await t.isEntrant(accounts[1])
    assert.isFalse(isEnt, 'Should no longer be an entrant')
  })

  it('Second entrant also able to withdraw their share', async function() {
    // Switch to acounts[2]
    t.accountNumber = 2
    await t.withdrawFromAbandoned()
    let isEnt = await t.isEntrant(accounts[2])
    assert.isFalse(isEnt, 'Should no longer be an entrant')
  })

  it('Unable to withdraw from tournament multiple times from the same account', async function() {
    try {
      t.accountNumber = 1
      await t.withdrawFromAbandoned()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to Abandoned round')
    }
  })

  it('Tournament balance is 0', async function() {
    let tB = await t.getBalance()
    assert.isTrue(tB == 0, 'Tournament balance should be 0')
  })

  it('Round balance is 0', async function() {
    let rB = await r.getBalance()
    assert.isTrue(rB == 0, 'Tournament balance should be 0')
  })

  it('Round is closed', async function() {
    let data = await r.getData()
    assert.isTrue(data.info.closed, 'Round should be closed after 1st reward withdrawal')
  })
})

contract('Unfunded Round Testing', function(accounts) {
  let t //tournament
  let r //round
  let ur //unfunded round
  let s //submission
  let token

  it('Able to create an Unfunded round', async function() {
    token = (await init()).token
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
      review: 60,
      bounty: web3.toWei(10)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submissions
    s = await createSubmission(t, false, 1)

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)
    await waitUntilClose(r)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round should be Unfunded', async function() {
    let [_, roundAddress] = await t.getCurrentRound()
    ur = Contract(roundAddress, IMatryxRound, 0)
    let state = await ur.getState()
    assert.equal(state, 1, 'Round is not Unfunded')
  })

  it('Balance of unfunded round is 0', async function() {
    let urB = await ur.getBalance()
    assert.equal(urB, 0, 'Round has funds in balance')
  })

  it('Balance of tournament is 0', async function() {
    let tB = await t.getBalance()
    assert.equal(tB, 0, 'Round has funds in balance')
  })

  it('Round should not have any submissions', async function() {
    let sub = await ur.getSubmissions(0, 0)
    assert.equal(sub.length, 0, 'Round should not have submissions')
  })

  it('Unable to make submissions while the round is Unfunded', async function() {
    try {
      await createSubmission(t, false, 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while round is Unfunded')
    }
  })

  it('Able to transfer more MTX to the tournament', async function() {
    await token.transfer(t.address, toWei(2))
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 2, 'Funds not transferred')
  })

  it('Able to transfer tournament funds to the Unfunded round', async function() {
    t.accountNumber = 0
    await t.transferToRound(toWei(2))
    let urB = await ur.getBalance()
    assert.equal(fromWei(urB), 2, 'Funds not transferred')
  })

  it('Round should now be Open', async function() {
    let state = await ur.getState()
    assert.equal(state, 2, 'Round is not Open')
  })
})

contract('Ghost Round Testing', function(accounts) {
  let t //tournament
  let r //round
  let gr //ghost round
  let s //submission

  it('Able to create a ghost round', async function() {
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

    //Create submissions
    s = await createSubmission(t, false, 1)

    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Able to get ghost round', async function() {
    let rounds = await t.getRounds()
    grAddress = rounds[rounds.length - 1]
    gr = Contract(grAddress, IMatryxRound, 0)
    assert.isTrue(gr.address != r.address, 'Unable to get ghost round')
  })

  it('Ghost round Review Period Duration is correct', async function() {
    let rpd = await gr.getReview()
    assert.equal(rpd, 20, 'New round details not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty()
    assert.equal(fromWei(grb), 5, 'New round details not updated correctly')
  })

  it('Tournament balance is correct', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 5, 'Tournament balance incorrect')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance()
    assert.equal(fromWei(grB), 5, 'Tournament and round balance should both be 0')
  })

  it('Able to edit ghost round, review period duration updated correctly', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000) + 60,
      end: Math.floor(Date.now() / 1000) + 80,
      review: 40,
      bounty: web3.toWei(5)
    }

    await t.updateNextRound(roundData)
    let rpd = await gr.getReview()

    assert.equal(rpd.toNumber(), 40, 'Review period duration not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty()
    assert.equal(fromWei(grb), 5, 'New round details not updated correctly')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance()
    assert.equal(fromWei(grB), 5, 'Tournament and round balance should both be 0')
  })

  // Tournament can send more funds to ghost round if round is edited
  it('Able to edit ghost round, send more MTX to the round', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000) + 200,
      end: Math.floor(Date.now() / 1000) + 220,
      review: 40,
      bounty: web3.toWei(8)
    }

    await t.updateNextRound(roundData)
    let rpd = await gr.getReview()

    assert.equal(rpd, 40, 'Ghost Round not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty()
    assert.equal(fromWei(grb), 8, 'Ghost round bounty not updated correctly')
  })

  it('Ghost Round balance should be 8', async function() {
    let grB = await gr.getBalance()
    assert.equal(fromWei(grB), 8, 'Ghost round balance incorrect')
  })

  it('Tournament balance is correct', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 2, 'Tournament balance incorrect')
  })

  // Ghost round can send funds back to tournament upon being edited
  it('Able to edit ghost round, send MTX from round back to tournament', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000) + 300,
      end: Math.floor(Date.now() / 1000) + 320,
      review: 40,
      bounty: web3.toWei(2)
    }

    await t.updateNextRound(roundData)
    let rpd = await gr.getReview()

    assert.equal(rpd, 40, 'Ghost Round not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let grb = await gr.getBounty()
    assert.equal(fromWei(grb), 2, 'New round details not updated correctly')
  })

  it('Ghost Round balance should be 5', async function() {
    let grB = await gr.getBalance()
    assert.equal(fromWei(grB), 2, 'Tournament and round balance should both be 0')
  })

  it('Tournament balance is correct', async function() {
    let tB = await t.getBalance()
    assert.equal(fromWei(tB), 8, 'Tournament balance incorrect')
  })
})

contract('Round Timing Restrictions Testing', function(accounts) {
  let t //tournament
  let r //round

  it('Able to create a round with duration: 1 day', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 86400,
      review: 5,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round not created successfully.')
  })

  it('Able to create a round with duration: 1 year', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 31536000,
      review: 5,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round not created successfully.')
  })

  it('Unable to create a round with duration: 1 year + 1 second', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 31536001,
      review: 5,
      bounty: web3.toWei(5)
    }

    try {
      t.accountNumber = 1
      await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to create the round')
    }
  })

  it('Able to create a round review period duration: 1 year', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
      review: 31536000,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round not created successfully.')
  })

  it('Unable to create a round with duration: 1 year + 1 second', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
      review: 31536001,
      bounty: web3.toWei(5)
    }

    try {
      t.accountNumber = 1
      await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to create the round')
    }
  })
})
