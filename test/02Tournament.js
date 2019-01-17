const IMatryxRound = artifacts.require('IMatryxRound')
const MatryxUser = artifacts.require('MatryxUser')
const IMatryxUser = artifacts.require('IMatryxUser')

let platform
let users

const { setup, stringToBytes32, stringToBytes, bytesToString, Contract } = require('../truffle/utils')
const { init, createTournament, waitUntilClose, waitUntilOpen, createSubmission, selectWinnersWhenInReview, enterTournament } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

contract('Open Tournament Testing', function() {
  let t //tournament
  let r //round

  it('Able to create a tournament', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000) + 60,
      end: Math.floor(Date.now() / 1000) + 120,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 1, 'Tournament count should be 1.')
  })

  it('Able to get tournament owner', async function() {
    let o = await t.getOwner()
    assert.equal(o, accounts[0], 'Unable to get owner.')
  })

  it('Tournament owner total spent should be 10', async function() {
    users = Contract(MatryxUser.address, IMatryxUser, 0)
    let total = await users.getTotalSpent(accounts[0]).then(fromWei)
    assert.equal(total, 10, 'Tournament owner total spent should be 10.')
  })

  it('Able to get tournament title', async function() {
    let title = await t.getTitle().then(bytesToString)
    assert.equal(title, 'first tournament', 'Unable to get title.')
  })

  it('Able to get tournament description', async function() {
    let d = await t.getDescriptionHash().then(bytesToString)
    assert.equal(d, 'QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 'Unable to get description hash.')
  })

  it('Able to get tournament bounty', async function() {
    let b = await t.getBounty().then(fromWei)
    assert.equal(b, 10, 'Unable to get bounty.')
  })

  it('Able to get tournament balance', async function() {
    let b = await platform.getBalanceOf(t.address).then(fromWei)
    assert.equal(b, 5, 'Unable to get balance.')
  })

  it('Able to get tournament entry fee', async function() {
    let f = await t.getEntryFee().then(fromWei)
    assert.equal(f, 2, 'Unable to get entry fee.')
  })

  it('Able to get tournament state', async function() {
    let s = await t.getState()
    assert.equal(s, 0, 'Unable to get state.')
  })

  it('Able to get tournament details', async function() {
    let d = await t.getDetails()
    assert.ok(d, 'Unable to get tournament details.')
  })

  it('Able to get all tournament rounds', async function() {
    let allr = await t.getRounds()
    assert.equal(allr.length, 1, 'Unable to get all rounds.')
  })

  it('Able to get current round', async function() {
    let allr = await t.getRounds()
    let [_, r] = await t.getCurrentRound()
    assert.equal(allr[0], r, 'Unable to get current round.')
  })

  it('Able to get category', async function() {
    let cat = await t.getCategory().then(bytesToString)
    assert.equal(cat, 'math', 'Unable to get category.')
  })

  it('Number of entrants is 0', async function() {
    let count = await t.getEntrantCount()
    assert.equal(count, 0, 'Number of entrants should be 0.')
  })

  it('Number of positive and negative votes is 0', async function() {
    let [pV, nV] = await t.getVotes()
    assert.equal(pV + nV, 0, 'Number of total votes should be 0.')
  })

  it("Number of submissions is 0", async function () {
    let count = await t.getSubmissionCount()
    assert.equal(count, 0, "Number of submissions should be 0.")
  })

  it('Tournament owner is not an entrant of own tournament', async function() {
    let isEntrant = await t.isEntrant(accounts[0])
    assert.isFalse(isEntrant, 'Owner should not be an entrant of own tournament.')
  })

  it('Able to add funds to the tournament', async function() {
    await t.addFunds(toWei(1))
    let b = await t.getBalance().then(fromWei)
    assert.equal(b, 6, 'Incorrect tournament balance')
  })

  it('Able to add funds to the tournament from another account', async function() {
    await setup(artifacts, web3, 2, true)
    t.accountNumber = 2
    await t.addFunds(toWei(1))
    t.accountNumber = 0
    let b = await t.getBalance().then(fromWei)
    assert.equal(b, 7, 'Incorrect tournament balance')
  })

  it('Able to edit the tournament data', async function() {
    modData = {
      title: stringToBytes32('new', 3),
      category: stringToBytes(''),
      descHash: stringToBytes32('new', 2),
      fileHash: stringToBytes32('new', 2),
      bounty: 0,
      entryFee: web3.toWei(1)
    }

    await t.updateDetails(modData)
    let title = await t.getTitle().then(bytesToString)
    let desc = await t.getDescriptionHash().then(bytesToString)
    let allNew = [title, desc].every(x => x === 'new')

    assert.isTrue(allNew, 'Tournament data not updated correctly.')
  })

  it('Able to change the tournament category', async function() {
    modData = {
      title: stringToBytes32('new', 3),
      category: stringToBytes32('science'),
      descHash: stringToBytes32('new', 2),
      fileHash: stringToBytes32('new', 2),
      bounty: 0,
      entryFee: web3.toWei(1)
    }

    await t.updateDetails(modData)
    let cat = await t.getCategory().then(bytesToString)

    assert.equal(cat, 'science', 'Tournament category not updated correctly.')
  })

  it('Unable to create a tournament with 0 bounty', async function() {
    let rData = {
      start: Math.floor(Date.now() / 1000) + 10,
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: 0
    }
    let tData = {
      category: stringToBytes('math'),
      title: stringToBytes32('title 1', 3),
      descHash: stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2),
      fileHash: stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2),
      bounty: 0,
      entryFee: web3.toWei(2)
    }

    try {
      await platform.createTournament(tData, rData)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to create a tournament with 0 bounty')
    }
  })

  it('Able to enter and exit the tournament', async function() {
    await enterTournament(t, 1)
    // switch to accounts[1]
    t.accountNumber = 1
    await t.exit()

    //switch back
    t.accountNumber = 0
    let c = await t.getEntrantCount()
    let e = await t.getEntryFeePaid(accounts[0])
    assert.equal(c + e, 0, 'Unable to exit the tournament.')
  })
})


contract('On Hold Tournament Testing', function() {
  let t //tournament
  let r //round
  let gr //new round
  let s //submission

  it('Able to create the tournament', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 5,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    // Set up ghost round
    await waitUntilOpen(r)
    s = await createSubmission(t, false, 1)
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    let rounds = await t.getRounds()
    grAddress = rounds[rounds.length - 1]
    gr = Contract(grAddress, IMatryxRound, 0)

    roundData = {
      start: Math.floor(Date.now() / 1000) + 20,
      end: Math.floor(Date.now() / 1000) + 40,
      review: 40,
      bounty: web3.toWei(5)
    }
    await t.updateNextRound(roundData)
    await waitUntilClose(r)

    assert.ok(gr, 'Unable to create tournament On Hold')
  })

  it('Tournament should be On Hold', async function() {
    let state = await t.getState()
    assert.equal(state, 1, 'Tournament is not On Hold')
  })

  it('First round should be Closed', async function() {
    let state = await r.getState()
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('New Round should be Not Yet Open', async function() {
    let state = await gr.getState()
    assert.equal(state, 0, 'Round should be Not Yet Open')
  })

  it('Current round should be Not Yet Open', async function() {
    let [_,cr] = await t.getCurrentRound()
    assert.equal(cr, gr.address, 'Incorrect current round')
  })

  it('New round should not have any submissions', async function() {
    let sub = await gr.getSubmissions(0, 0)
    assert.equal(sub.length, 0, 'Round should not have submissions')
  })

  it('Unable to make a submission while On Hold', async function() {
    try {
      await createSubmission(t, false, 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a submission while On Hold')
    }
  })

  it('Able to enter tournament while On Hold', async function() {
    let isEnt = await enterTournament(t, 2)
    assert.isTrue(isEnt, 'Could not enter the tournament')
  })

  it('Tournament becomes open again after the next round starts', async function() {
    await waitUntilOpen(gr)
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament should be open')
  })

  it('Round should be open', async function() {
    let state = await gr.getState()
    assert.equal(state, 2, 'Round should be open')
  })
})

contract('Tournament Voting Testing', function() {
  let t //tournament
  let r //round
  let s //submission

  it('Able to create the tournament and select submissions', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 50,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    // Setup
    await waitUntilOpen(r)
    s = await createSubmission(t, false, 1)
    let submissions = await r.getSubmissions(0, 0)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)

    assert.ok(r, 'Unable to create tournament and select submissions')
  })

  it('Positive & negative votes for the submission should be 0', async function() {
    let [pV, nV] = await s.getVotes()
    assert.isTrue((pV + nV) == 0, 'Submission should not have any votes')
  })

  it('Unable to judge a submission from another account', async function() {
    try {
      t.accountNumber = 1
      await t.voteSubmission(s.address, true)
      assert.fail('Expected revert not received')
    } catch (error) {
      t.accountNumber = 0
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to vote')
    }
  })

  it('Able to give the submission a positive vote', async function() {
    await t.voteSubmission(s.address, true)
    let [pV, nV] = await s.getVotes()
    assert.isTrue(pV == 1, 'Submission should have 1 positive vote')
  })

  it('Unable to judge the submission again', async function() {
    try {
      await t.voteSubmission(s.address, false)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to vote again')
    }
  })
})

contract('Abandoned Tournament due to No Submissions Testing', function() {
  let token
  let t //tournament
  let r //round

  it('Able to create an Abandoned round', async function() {
    token = (await init()).token

    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 5,
      review: 1,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    // Wait for the round to become Abandoned
    await waitUntilClose(r)

    assert.ok(r.address, 'Round is not valid.')
  })

  it('Round state is Abandoned', async function() {
    let state = await r.getState()
    assert.equal(state, 6, 'Round State should be Abandoned')
  })

  it('Tournament state is Abandoned', async function() {
    let state = await t.getState()
    assert.equal(state, 4, 'Tournament State should be Abandoned')
  })

  it('Unable to add bounty to Abandoned round', async function() {
    try {
      await t.transferToRound(toWei(1))
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to Abandoned round')
    }
  })

  it('Unable to add funds to an Abandoned tournament', async function() {
    try {
      await t.addFunds(toWei(1))
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add funds')
    }
  })

  it("Only the tournament owner can attempt to recover the tournament funds", async function () {
      try {
        // Switch to some other account
        t.accountNumber = 1
        await t.recoverFunds()
        assert.fail('Expected revert not received')
      } catch (error) {
        // Switch back to the tournament owner account
        t.accountNumber = 0
        let revertFound = error.message.search('revert') >= 0
        assert(revertFound, 'Should not have been able to recover funds from another account')
      }
  })

  it("Tournament owner is able to recover tournament funds", async function () {
      let balBefore = await token.balanceOf(accounts[0])
      await t.recoverFunds()
      let balAfter = await token.balanceOf(accounts[0])
      assert.isTrue(fromWei(balAfter) == (fromWei(balBefore) + 10), "Tournament funds not transferred back to the owner")
  })

  it("Unable to call recover funds twice", async function () {
    try {
        await t.recoverFunds()
        assert.fail('Expected revert not received')
      } catch (error) {
        let revertFound = error.message.search('revert') >= 0
        assert(revertFound, 'Should not have been able to recover funds twice')
      }
  })

  it("Nonentrant unable to withdraw from Abandoned", async function () {
    try {
        // switch to accounts[1]
        t.accountNumber = 1
        await t.withdrawFromAbandoned()
        assert.fail('Expected revert not received')
      } catch (error) {
        // switch back
        t.accountNumber = 0
        let revertFound = error.message.search('revert') >= 0
        assert(revertFound, 'Should not have been able to withdraw')
      }
  })

  it("Tournament balance is 0", async function () {
      let tB = await platform.getBalanceOf(t.address)
      assert.isTrue(tB == 0, "Tournament balance should be 0")
  })

  it("Round balance is 0", async function () {
      let rB = await platform.getBalanceOf(r.address)
      assert.isTrue(rB == 0, "Round balance should be 0")
  })

  it('Tournament owner total spent should be 0', async function() {
      let total = await users.getTotalSpent(accounts[0]).then(fromWei)
      assert.equal(total, 0, 'Tournament owner total spent should be 0.')
  })
})
