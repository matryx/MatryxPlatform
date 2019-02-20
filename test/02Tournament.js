const { shouldFail } = require('openzeppelin-test-helpers')

const { setup } = require('../truffle/utils')
const { init, createTournament, waitUntilClose, waitUntilOpen, createSubmission, selectWinnersWhenInReview, enterTournament } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform

contract('Open Tournament Testing', function() {
  let t //tournament

  // reset accounts
  afterEach(() => {
    t.accountNumber = 0
  })

  it('Able to create a tournament', async function() {
    platform = (await init()).platform
    roundData = {
      start: 0,
      duration: 120,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 1, 'Tournament count should be 1.')
  })

  it('Able to get tournament owner and version', async function() {
    let { owner } = await t.getInfo()
    let { version } = await t.getInfo()
    assert.equal(owner, accounts[0], 'Unable to get owner.')
    assert.equal(version, 1, 'Unable to get version.')
  })

  it('Able to get tournament details', async () => {
    let details = await t.getDetails()
    assert.equal(details.content, 'tournament', 'Unable to get content')
    assert.equal(fromWei(details.bounty), 10, 'Unable to get bounty.')
    assert.equal(fromWei(details.entryFee), 2, 'Unable to get entry fee.')
  })

  it('Able to get tournament balance', async function() {
    let b = await t.getBalance().then(fromWei)
    assert.equal(b, 10, 'Unable to get balance.')
  })

  it('Able to get tournament state', async function() {
    let s = +(await t.getState())
    assert.equal(s, 2, 'Tournament should be open.')
  })

  it('Able to get current round', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    assert.equal(roundIndex, 0, 'Unable to get current round.')
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
    await t.addToBounty(toWei(1))
    let b = await t.getBalance().then(fromWei)
    assert.equal(b, 11, 'Incorrect tournament balance')
  })

  it('Only the tournament owner can transfer funds to a round', async function() {
    t.accountNumber = 1
    let tx = t.transferToRound(toWei(1))
    await shouldFail.reverting(tx)
  })

  it('Able to add funds to the tournament from another account', async function() {
    await setup(artifacts, web3, 2, true)

    t.accountNumber = 2
    await t.addToBounty(toWei(1))
    let b = await t.getBalance().then(fromWei)

    assert.equal(b, 12, 'Incorrect tournament balance')
  })

  it('Able to edit the tournament data', async function() {
    modData = {
      content: 'new',
      bounty: 0,
      entryFee: web3.toWei(1)
    }

    await t.updateDetails(modData)
    let { content, bounty, entryFee } = await t.getDetails()

    assert.equal(content, 'new', 'Incorrect tournament content.')
    assert.equal(fromWei(bounty), 10, 'Incorrect tournament bounty.')
    assert.equal(fromWei(entryFee), 1, 'Incorrect tournament entry fee.')
  })

  it('Unable to create a tournament with 0 bounty', async function() {
    let rData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: 0
    }
    let tData = {
      content: 'content',
      bounty: 0,
      entryFee: web3.toWei(2)
    }

    let tx = platform.createTournament(tData, rData)
    await shouldFail.reverting(tx)
  })

  it('Unable to create a tournament with more round bounty than funds available', async function() {
    let rData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: toWei(20)
    }
    let tData = {
      content: 'content',
      bounty: toWei(5),
      entryFee: web3.toWei(2)
    }

    let tx = platform.createTournament(tData, rData)
    await shouldFail.reverting(tx)
  })

  it('Able to enter the tournament', async function() {
    await enterTournament(t, 1)
    let isEnt = await t.isEntrant(accounts[1])
    assert.isTrue(isEnt, 'Unable to enter the tournament.')
  })

  it('Unable to enter the tournament twice', async function() {
    t.accountNumber = 1
    let tx = t.enter()
    await shouldFail.reverting(tx)
  })

  it('Entry fee paid stored correctly', async function() {
    let e = await t.getEntryFeePaid(accounts[1]).then(fromWei)
    assert.equal(e, 1, 'Incorrect entry fee.')
  })

  it('Able to exit the tournament', async function() {
    t.accountNumber = 1
    await t.exit()

    let isEnt = await t.isEntrant(accounts[1])
    assert.isFalse(isEnt, 'Unable to exit the tournament.')
  })

  it('Unable to exit the tournament twice', async function() {
    t.accountNumber = 1
    let tx = t.exit()
    await shouldFail.reverting(tx)
  })

  it('Able to enter the tournament again', async function() {
    await enterTournament(t, 1)
    let isEnt = await t.isEntrant(accounts[1])
    assert.isTrue(isEnt, 'Unable to enter the tournament.')
  })
})

contract('On Hold Tournament Testing', function() {
  let t // tournament
  let s // submission

  // reset accounts
  afterEach(() => {
    t.accountNumber = 0
  })

  it('Able to make tournament on hold', async function() {
    await init()
    roundData = {
      start: 0,
      duration: 30,
      review: 10,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()

    // Set up ghost round
    s = await createSubmission(t, '0x00', toWei(1), 1)
    await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 0)

    roundData = {
      start: Math.floor(Date.now() / 1000) + 20,
      duration: 40,
      review: 5,
      bounty: web3.toWei(5)
    }

    await t.updateNextRound(roundData)
    await waitUntilClose(t, roundIndex)

    let state = await t.getState()
    assert.equal(+state, 1, 'Tournament is not On Hold')
  })

  it('New Round should be Not Yet Open', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(+state, 0, 'Round should be Not Yet Open')
  })

  it('New round should not have any submissions', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let { submissions } = await t.getRoundInfo(roundIndex)
    assert.equal(submissions.length, 0, 'Round should not have submissions')
  })

  it('Unable to make a submission while On Hold', async function() {
    try {
      await createSubmission(t, '0x00', toWei(1), 1)
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
    let roundIndex = await t.getCurrentRoundIndex()
    await waitUntilOpen(t, roundIndex)
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament should be open')
  })

  it('Round should be open', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 2, 'Round should be open')
  })
})

contract('Abandoned Tournament due to No Submissions Testing', function() {
  let token
  let t // tournament

  // reset accounts
  afterEach(() => {
    t.accountNumber = 0
  })

  it('Able to create an Abandoned round', async function() {
    token = (await init()).token

    roundData = {
      start: 0,
      duration: 5,
      review: 1,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()

    await waitUntilClose(t, roundIndex)

    assert.equal(roundIndex, 0, 'Round is not valid.')
  })

  it('Round state is Abandoned', async function() {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = +await t.getRoundState(roundIndex)
    assert.equal(state, 6, 'Round State should be Abandoned')
  })

  it('Tournament state is Abandoned', async function() {
    let state = +await t.getState()
    assert.equal(state, 4, 'Tournament State should be Abandoned')
  })

  it('Unable to add bounty to Abandoned round', async function() {
    let tx = t.transferToRound(toWei(1))
    await shouldFail.reverting(tx)
  })

  it('Unable to add funds to an Abandoned tournament', async function() {
    let tx = t.addToBounty(toWei(1))
    await shouldFail.reverting(tx)
  })

  it("Only the tournament owner can attempt to recover the tournament funds", async function () {
    t.accountNumber = 1
    let tx = t.recoverBounty()
    await shouldFail.reverting(tx)
    t.accountNumber = 0
  })

  it("Tournament owner is able to recover tournament funds", async function () {
    let balBefore = await token.balanceOf(accounts[0]).then(fromWei)
    await t.recoverBounty()
    let balAfter = await token.balanceOf(accounts[0]).then(fromWei)
    assert.equal(balAfter, balBefore + 10, "Tournament funds not transferred back to the owner")
  })

  it("Unable to call recover funds twice", async function () {
    let tx = t.recoverBounty()
    await shouldFail.reverting(tx)
  })

  it("Nonentrant unable to withdraw from Abandoned", async function () {
    t.accountNumber = 1
    let tx = t.withdrawFromAbandoned()
    await shouldFail.reverting(tx)
  })

  it("Tournament balance is 0", async function () {
    let tB = await t.getBalance().then(fromWei)
    assert.isTrue(tB == 0, "Tournament balance should be 0")
  })

})
