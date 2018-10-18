const IMatryxRound = artifacts.require('IMatryxRound')

let platform
const { stringToBytes32, stringToBytes, bytesToString, Contract } = require('../truffle/utils')
const { init, createTournament, waitUntilClose, waitUntilOpen, createSubmission, selectWinnersWhenInReview, enterTournament } = require('./helpers')(artifacts, web3)

contract('Tournament Testing', function(accounts) {
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

  it('Able to get tournament title', async function() {
    let title = await t.getTitle()
    let str = bytesToString(title)
    assert.equal(str, 'first tournament', 'Unable to get title.')
  })

  it('Able to get tournament description', async function() {
    let d = await t.getDescriptionHash()
    let str = bytesToString(d)
    assert.equal(str, 'QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 'Unable to get description hash.')
  })

  it('Able to get tournament files', async function() {
    let f = await t.getFileHash()
    let str = bytesToString(f)
    assert.equal(str, 'QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 'Unable to get file hash.')
  })

  it('Able to get tournament bounty', async function() {
    let b = await t.getBounty()
    assert.equal(b, web3.toWei(10), 'Unable to get bounty.')
  })

  it('Able to get tournament balance', async function() {
    let b = await t.getBalance()
    assert.equal(fromWei(b), 5, 'Unable to get balance.')
  })

  it('Able to get tournament entry fee', async function() {
    let f = await t.getEntryFee()
    assert.equal(f, web3.toWei(2), 'Unable to get entry fee.')
  })

  it('Able to get tournament state', async function() {
    let s = await t.getState()
    assert.equal(s, 0, 'Unable to get state.')
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
    let cat = await t.getCategory()
    let math = stringToBytes32('math')
    assert.equal(cat, math, 'Unable to get current round.')
  })

  it('Number of entrants is 0', async function() {
    let count = await t.getEntrantCount()
    assert.equal(count, 0, 'Number of entrants should be 0.')
  })

  // it("Number of submissions is 0", async function () {
  //   let count = await t.getSubmissionCount()
  //   assert.equal(count, 0, "Number of entrants should be 0.")
  // })

  it('I am not an entrant of my tournament', async function() {
    let isEntrant = await t.isEntrant(accounts[0])
    assert.isFalse(isEntrant, 'I should not be an entrant of my own tournament.')
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
    let title = await t.getTitle()
    let desc = await t.getDescriptionHash()
    let file = await t.getFileHash()
    let fee = await t.getEntryFee()

    let n = stringToBytes32('new', 2)

    let allNew = [title[0], desc[0], file[0]].every(x => x === n[0])

    assert.isTrue(allNew && fee == web3.toWei(1), 'Tournament data not updated correctly.')
  })

  it('Able to change the tournament category', async function() {
    //create new category
    await platform.createCategory(stringToBytes32('science'))
    let allCat = await platform.getCategories(1, 1)

    modData = {
      title: stringToBytes32('new', 3),
      category: stringToBytes32('science'),
      descHash: stringToBytes32('new', 2),
      fileHash: stringToBytes32('new', 2),
      bounty: 0,
      entryFee: web3.toWei(1)
    }

    await t.updateDetails(modData)
    let cat = await t.getCategory()

    assert.equal(cat, stringToBytes32('science'), 'Tournament category not updated correctly.')
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
})


contract('On Hold Tournament Testing', function(accounts) {
  let t //tournament
  let r //round
  let gr //new round
  let s //submission

  it('Able to create the tournament', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 10,
      review: 5,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    // Wait until open
    await waitUntilOpen(r)

    // Create submissions
    s = await createSubmission(t, false, 1)
    let submissions = await r.getSubmissions(0, 0)

    // Select winners
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
    assert.ok(gr, 'Unable to create tournament')
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

contract('Abandoned Tournament due to No Submissions Testing', function(accounts) {
  let t //tournament
  let r //round

  it('Able to create an Abandoned round', async function() {
    await init()
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

  it('Unable to add bounty to Abandoned round', async function() {
    try {
      await t.transferToRound(web3.toWei(1))
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to add bounty to Abandoned round')
    }
  })

  // TODO add this
  // it("Only the tournament owner can attempt to recover the tournament funds", async function () {
  //     try {
  //         // Switch to some other account
  //         t.accountNumber = 1
  //         await t.recoverFunds()
  //         assert.fail('Expected revert not received')
  //       } catch (error) {
  //         // Switch back to the tournament owner account
  //         t.accountNumber = 0
  //         let revertFound = error.message.search('revert') >= 0
  //         assert(revertFound, 'Should not have been able to add bounty to Abandoned round')
  //       }
  // })

  // it("Tournament owner is able to recover tournament funds", async function () {
  //     let balBefore = await token.balanceOf(accounts[0])
  //     await t.recoverFunds()
  //     let balAfter = await token.balanceOf(accounts[0])
  //     assert.isTrue(fromWei(balAfter) == (fromWei(balBefore) + 10), "Tournament funds not transferred back to the owner")
  // })

  // it("Tournament balance is 0", async function () {
  //     let tB = await t.getBalance()
  //     assert.isTrue(tB == 0, "Tournament balance should be 0")
  // })

  // it("Round balance is 0", async function () {
  //     let rB = await r.getBalance()
  //     assert.isTrue(rB == 0, "Tournament balance should be 0")
  // })
})
