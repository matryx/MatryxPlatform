const { shouldFail } = require('openzeppelin-test-helpers')

const { Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, waitUntilInReview, waitUntilClose, selectWinnersWhenInReview, enterTournament } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform

contract('NotYetOpen Round Testing', function() {
  let t //tournament
  let roundData

  it('Able to create a tournament with a valid round', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000) + 60,
      duration: 120,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    assert.equal(roundIndex, 0, 'Round is not valid.')
  })
  
  it('Able to get round details', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { start, duration, review, bounty } = await t.getRoundDetails(roundIndex)
    assert.equal(start, roundData.start, 'Incorrect round start')
    assert.equal(duration, roundData.duration, 'Incorrect round duration')
    assert.equal(review, roundData.review, 'Incorrect round review')
    assert.equal(bounty, roundData.bounty, 'Incorrect round bounty')
  })
  
  it('Round state is Not Yet Open', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 0, 'Round State should be NotYetOpen')
  })

  it('Round should not have any submissions', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { submissions } = await t.getRoundInfo(roundIndex)
    assert.equal(submissions.length, 0, 'Round should not have submissions')
  })

  it('Able to add bounty to a round', async function() {
    await t.transferToRound(web3.toWei(1))
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex)
    assert.equal(fromWei(bounty), 6, 'Bounty was not added')
  })

  it('Able to enter tournament with Not Yet Open round', async function() {
    await enterTournament(t, 2)
    let isEnt = await t.isEntrant(accounts[2])
    assert.isTrue(isEnt, 'Could not enter tournament')
  })
})

contract('Open Round Testing', function() {
  let t //tournament
  let s //submission
  it('Able to create a tournament with a Open round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 120,
      review: 60,
      bounty: web3.toWei(5)
    }
    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    assert.equal(roundIndex, 0, 'Round is not valid.')
  })

  it('Round state is Open', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 2, 'Round State should be Open')
  })

  it('Able to enter the tournament and make submissions', async function() {
    // Create submissions
    s = await createSubmission(t, '0x00', toWei(1), 1)
    s2 = await createSubmission(t, '0x00', toWei(1), 2)

    assert.ok(s && s2, 'Unable to make submissions')
  })
  
  it('Number of submissions should be 2', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { submissions } = await t.getRoundInfo(roundIndex)
    assert.equal(submissions.length, 2, 'Number of Submissions should be 2')
  })
})

contract('In Review Round Testing', function() {
  let t //tournament
  let s //submission

  it('Able to create a round In Review', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    assert.equal(roundIndex, 0, 'Round is not valid.')

    //Create submissions
    s = await createSubmission(t, '0x00', toWei(1), 1)
    s2 = await createSubmission(t, '0x00', toWei(1), 2)
    await waitUntilInReview(t, roundIndex)

    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 3, 'Round State should be In Review')
  })

  it('Able to allocate more tournament bounty to a round in review', async function() {
    await t.transferToRound(web3.toWei(1))
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex)
    assert.equal(fromWei(bounty), 6, 'Incorrect round balance')
  })

  it('Able to enter round in review', async function() {
    let isEnt = await enterTournament(t, 3)
    assert.isTrue(isEnt, 'Could not enter tournament')
  })

  it('Unable to make submissions while the round is in review', async function() {
    try {
      await createSubmission(t, '0x00', toWei(1), 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while In Review')
    }
  })
})

contract('Closed Round Testing', function() {
  let t //tournament
  let s //submission

  it('Able to create a closed round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 20,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    assert.equal(roundIndex, 0, 'Round is not valid.')

    // Create submissions
    s = await createSubmission(t, '0x00', toWei(1), 1)

    let { submissions } = await t.getRoundInfo(roundIndex)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('Tournament should be closed', async function() {
    let state = await t.getState()
    assert.equal(+state, 3, 'Tournament is not Closed')
  })

  it('Unable to allocate more tournament bounty to a closed round', async function() {
    let tx = t.transferToRound(web3.toWei(1))
    await shouldFail.reverting(tx)
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
      await createSubmission(t, '0x00', toWei(1), 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while In Review')
    }
  })
})

contract('Abandoned Round Testing', function() {
  let t //tournament

  it('Able to create an Abandoned round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 20,
      review: 1,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    assert.equal(roundIndex, 0, 'Round is not valid.')

    // Create a submission
    s = await createSubmission(t, '0x00', toWei(1), 1)
    s = await createSubmission(t, '0x00', toWei(1), 2)

    // Wait for the round to become Abandoned
    await waitUntilClose(t, roundIndex)

    assert.equal(roundIndex, 0, 'Round is not valid.')
  })

  it('Round state is Abandoned', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(+state, 6, 'Round State should be Abandoned')
  })

  it('Tournament state is Abandoned', async function() {
    let state = await t.getState()
    assert.equal(+state, 4, 'Tournament State should be Abandoned')
  })

  it('Unable to add bounty to Abandoned round', async function() {
    let tx = t.transferToRound(web3.toWei(1))
    await shouldFail.reverting(tx)
  })

  it('Round is still open in round data before the first withdrawal', async function () {
    let roundIndex = await t.getCurrentRoundIndex()
    let { closed } = await t.getRoundInfo(roundIndex)
    assert.isFalse(closed, 'Round should still be set as open')
  })

  it('First entrant is able to withdraw their share from the bounty from an abandoned round', async function() {
    // Switch to acounts[1]
    t.accountNumber = 1
    await t.withdrawFromAbandoned()
    let isEnt = await t.isEntrant(accounts[1])
    assert.isFalse(isEnt, 'Should no longer be an entrant')
  })

  it('Round is set to closed after first withdrawal', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { closed } = await t.getRoundInfo(roundIndex)
    assert.isTrue(closed, 'Round should be closed after 1st reward withdrawal')
  })

  it('Second entrant also able to withdraw their share', async function() {
    // Switch to acounts[2]
    t.accountNumber = 2
    await t.withdrawFromAbandoned()
    let isEnt = await t.isEntrant(accounts[2])
    assert.isFalse(isEnt, 'Should no longer be an entrant')
  })

  it('Unable to withdraw from tournament multiple times from the same account', async function() {
    t.accountNumber = 1
    let tx = t.withdrawFromAbandoned()
    await shouldFail.reverting(tx)
    t.accountNumber = 0
  })

  it('Tournament balance is 0', async function() {
    let tB = await platform.getBalanceOf(t.address)
    assert.equal(fromWei(tB), 0, 'Tournament balance should be 0')
  })

})

contract('Abandoned Round due to No Submissions', function() {
  let t //tournament

  it('Able to create an Abandoned round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 20,
      review: 1,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    // Wait for the round to become Abandoned
    await waitUntilClose(t, roundIndex)

    assert.equal(roundIndex, 0, 'Round is not valid.')
  })

  it('Round state is Abandoned', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(+state, 6, 'Round State should be Abandoned')
  })
  
  it('Able to recover funds and mark the round as closed', async function() {
    await t.recoverFunds()
    let roundIndex = await t.getCurrentRoundIndex()
    let { closed } = await t.getRoundInfo(roundIndex)
    assert.isTrue(closed, 'Round should be closed after owner recovers funds')
  })

  it('Unable to recover funds multiple times', async function() {
    let tx = t.recoverFunds()
    await shouldFail.reverting(tx)
  })

  it('Tournament balance is 0', async function() {
    let tB = await platform.getBalanceOf(t.address)
    assert.equal(fromWei(tB), 0, 'Tournament balance should be 0')
  })
})

contract('Unfunded Round Testing', function() {
  let t //tournament
  let ur //unfunded round
  let s //submission
  let token

  it('Able to create an Unfunded round', async function() {
    token = (await init()).token

    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 35,
      review: 20,
      bounty: web3.toWei(10)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()

    s = await createSubmission(t, '0x00', toWei(1), 1)

    let { submissions } = await t.getRoundInfo(roundIndex)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    await waitUntilClose(t, roundIndex)

    let state = await t.getState()
    assert.equal(+state, 2, 'Tournament is not Open')
  })

  it('Round should be Unfunded', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 1, 'Round is not Unfunded')
  })

  it('Bounty of unfunded round is 0', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex)
    assert.equal(bounty, 0, 'Round bounty should be 0')
  })

  it('Balance of tournament is 0', async function() {
    let tB = await platform.getBalanceOf(t.address)
    assert.equal(tB, 0, 'Tournament balance should be 0')
  })

  it('Round should not have any submissions', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { submissions } = await t.getRoundInfo(roundIndex)
    assert.equal(submissions.length, 0, 'Round should not have submissions')
  })

  it('Unable to make submissions while the round is Unfunded', async function() {
    try {
      await createSubmission(t, '0x00', toWei(1), 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while round is Unfunded')
    }
  })

  it('Able to transfer more MTX to the tournament', async function () {
    await t.addFunds(toWei(2))
    let tB = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(tB, 2, 'Funds not transferred')
  })

  it('Able to transfer tournament funds to the Unfunded round', async function() {
    t.accountNumber = 0
    await t.transferToRound(toWei(2))
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex)
    assert.equal(fromWei(bounty), 2, 'Funds not transferred')
  })

  it('Round should now be Open', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 2, 'Round is not Open')
  })
})

contract('Ghost Round Testing', function() {
  let t //tournament
  let s //submission

  it('Able to create a ghost round', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 30,
      review: 30,
      bounty: toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(20), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()
    
    assert.equal(roundIndex, 0, 'Round is not valid.')

    s = await createSubmission(t, '0x00', toWei(1), 1)
    let { submissions } = await t.getRoundInfo(roundIndex)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    assert.ok(s, 'Submission is not valid.')
  })

  it('Tournament should be Open', async function() {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round state should be Has Winners', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 4, 'Round should be in Has Winners state')
  })

  it('Ghost round Review Period Duration is correct', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { review } = await t.getRoundDetails(roundIndex + 1)
    assert.equal(review, 30, 'Incorrect ghost round review period')
  })

  it('Ghost round bounty is correct', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex + 1)
    assert.equal(fromWei(bounty), 5, 'Incorrect ghost round bounty')
  })

  it('Able to edit ghost round, review period duration updated correctly', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000) + 60,
      duration: 80,
      review: 40,
      bounty: web3.toWei(5)
    }

    await t.updateNextRound(roundData)
    let roundIndex = await t.getCurrentRoundIndex()
    let { review } = await t.getRoundDetails(roundIndex + 1)

    assert.equal(review, 40, 'Review period duration not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex + 1)
    assert.equal(fromWei(bounty), 5, 'Incorrect ghost round bounty')
  })

  // Tournament can send more funds to ghost round if round is edited
  it('Able to edit ghost round increasing its bounty', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000) + 200,
      duration: 220,
      review: 40,
      bounty: web3.toWei(8)
    }
    await t.updateNextRound(roundData)
    let roundIndex = await t.getCurrentRoundIndex()
    let { review } = await t.getRoundDetails(roundIndex + 1)

    assert.equal(review, roundData.review, 'Ghost Round not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex + 1)
    assert.equal(fromWei(bounty), 8, 'Incorrect ghost round bounty')
  })

  // Ghost round can send funds back to tournament upon being edited
  it('Able to edit ghost round decreasing its bounty', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000) + 300,
      duration: 320,
      review: 50,
      bounty: web3.toWei(2)
    }
    await t.updateNextRound(roundData)
    let roundIndex = await t.getCurrentRoundIndex()
    let { review } = await t.getRoundDetails(roundIndex + 1)

    assert.equal(review, roundData.review, 'Ghost Round not updated correctly')
  })

  it('Ghost round bounty is correct', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex + 1)
    assert.equal(fromWei(bounty), 2, 'Incorrect ghost round bounty')
  })
})

//TODO - add timing restrictions
/*
contract('Round Timing Restrictions Testing', function() {
  let t //tournament

  it('Able to create a round with duration: 1 day', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 86400,
      review: 5,
      bounty: web3.toWei(5)
    }
    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let [, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round not created successfully.')
  })

  it('Able to create a round with duration: 1 year', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 31536000,
      review: 5,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let [, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round not created successfully.')
  })

  it('Unable to create a round with duration: 1 year + 1 second', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 31536001,
      review: 5,
      bounty: web3.toWei(5)
    }

    try {
      t.accountNumber = 1
      await createTournament('tournament', web3.toWei(10), roundData, 0)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to create the round')
    }
  })

  it('Able to create a round review period duration: 1 year', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 10,
      review: 31536000,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let [, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    assert.ok(r.address, 'Round not created successfully.')
  })

  it('Unable to create a round with duration: 1 year + 1 second', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      duration: 10,
      review: 31536001,
      bounty: web3.toWei(5)
    }

    try {
      t.accountNumber = 1
      await createTournament('tournament', web3.toWei(10), roundData, 0)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to create the round')
    }
  })
})
*/
