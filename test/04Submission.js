const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')
const MatryxUser = artifacts.require('MatryxUser')
const IMatryxUser = artifacts.require('IMatryxUser')

const { setup, bytesToString, Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, updateSubmission, waitUntilInReview } = require('./helpers')(artifacts, web3)

let platform
let users

contract('Submission Testing with No Contributors and References', function(accounts) {
  let t  // tournament
  let r  // round
  let s  // submission 1
  let s2 // submission 2
  let s3 // submission 3

  it('Able to create a Submission', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 60,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s3 = await createSubmission(t, false, 3)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it("Submission should exist in round", async function () {
    let exists = await platform.isSubmission(s.address)
    assert.isTrue(exists, "Submission does not exist in round")
  })

  it("Non-submission address does not exist as a submission in round", async function () {
    let exists = await platform.isSubmission(r.address)
    assert.isFalse(exists, "This address should not exist as a submission in round")
  })

  it('Only Submission Owner and Tournament Owner have Download Permissions', async function() {
    let permitted = await s.getViewers()
    let tOwner = await t.getOwner()
    let sOwner = await s.getOwner()

    let allTrue = permitted.some(x => x == tOwner) && permitted.some(x => x == sOwner)

    assert.isTrue(allTrue && permitted.length == 2, 'Permissions are not correct')
  })

  it('Submission has no References', async function() {
    let ref = await s.getReferences()
    assert.equal(ref.length, 0, 'References are not correct')
  })

  it('Submission has no Contributors', async function() {
    let contribs = await s.getContributors()
    assert.equal(contribs.length, 0, 'Contributors are not correct')
  })

  it('Able to get Reward Distribution', async function() {
    let crd = await s.getDistribution()
    assert.equal(crd.length, 1, 'Reward distribution incorrect')
  })

  it('Able to get tournament address', async function() {
    let ts = await s.getTournament()
    assert.equal(ts, t.address, 'Tournament address is incorrect')
  })

  it('Able to get round address', async function() {
    let tr = await s.getRound()
    assert.equal(tr, r.address, 'Round address is incorrect')
  })

  it('Get Submission Owner', async function() {
    let to = await s.getOwner()
    let actual = web3.eth.accounts[1]
    assert.equal(to.toLowerCase(), actual.toLowerCase(), 'Owner is incorrect')
  })

  it('Get Time Submitted and Updated', async function() {
    let st = await s.getTimeSubmitted().then(Number)
    let ut = await s.getTimeUpdated().then(Number)
    assert.equal(st, ut, 'Time submitted and updated are incorrect')
  })

  it('Submission title correctly updated', async function() {
    await updateSubmission(s)
    let title = await s.getTitle().then(bytesToString)
    assert.equal(title, 'AAAAAA', 'Submission Title should be Updated')
  })

  it('Able to update contributors', async function() {
    let con = await s.getContributors()
    assert.equal(con.length, 3, 'Contributors not updated correctly.')
  })

  it('Get Time Updated', async function() {
    let st = await s.getTimeSubmitted().then(Number)
    let ut = await s.getTimeUpdated().then(Number)
    assert.isTrue(ut > st, 'Update Time is not correct')
  })

  it('Any Matryx entrant able to request download permissions', async function() {
    //switch to accounts[1]
    s2.accountNumber = 1
    await waitUntilInReview(r)

    //unlock the s2 files from accounts[1]
    await s2.unlockFile()

    let permitted = await s2.getViewers()
    let p2 = permitted.some(x => x.toLowerCase() == accounts[1])

    assert.isTrue(p2, 'Permissions are not correct')
  })

  it('Non Matryx entrant unable to request download permissions', async function() {
    try {
      s.accountNumber = 4
      await s.unlockFile()
      assert.fail('Expected revert not received')
    } catch (error) {
      // switch back
      s.accountNumber = 1
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to view files')
    }
  })

  it('Able to flag a submission for missing a reference', async function() {
    // switch to accounts[2]
    s.accountNumber = 2
    await s.flagMissingReference(s2.address);
    s.accountNumber = 1
    users = Contract(MatryxUser.address, IMatryxUser, 0)
    let [v, n] = await users.getVotes(accounts[1])
    assert.equal(n, 1, "Submission owner user should have 1 negative vote")
  })

  it('Unable to flag same missing reference twice', async function() {
    try {
      s.accountNumber = 2
      await s.flagMissingReference(s2.address)
      assert.fail('Expected revert not received')
    } catch (error) {
      s.accountNumber = 1
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to flag submission')
    }
  })

  it('Unable to flag missing reference from an account that doesn\'t own the reference', async function() {
    try {
      s.accountNumber = 3
      await s.flagMissingReference(s2.address)
      assert.fail('Expected revert not received')
    } catch (error) {
      s.accountNumber = 1
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to flag submission from this account')
    }
  })

  it('Unable to flag missing reference if submission owner does not have file download permissions', async function() {
    try {
      s.accountNumber = 3
      await s.flagMissingReference(s3.address)
      assert.fail('Expected revert not received')
    } catch (error) {
      s.accountNumber = 1
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to flag submission')
    }
  })

})

contract('Submission Testing with Contributors', function(accounts) {
  let t
  let s
  let s2

  it('Able to create a Submission with Contributors and References', async function() {
    platform = (await init()).platform
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    s = await createSubmission(t, false, 1)
    s2 = await createSubmission(t, false, 2)
    s = Contract(s.address, IMatryxSubmission, 1)
    s2 = Contract(s2.address, IMatryxSubmission, 2)

    assert.ok(s.address, 'Submission is not valid.')
  })

  it('Submission and Tournament owners have Download Permissions', async function() {
    let permitted = await s.getViewers()

    //check tournament owner has download permissions
    let tOwner = await t.getOwner()
    let allTrue = permitted.some(x => x == tOwner)

    //check submission owner has download permissions
    let sOwner = await s.getOwner()
    allTrue = allTrue && permitted.some(x => x == sOwner)

    assert.isTrue(allTrue, 'Submission and Tournament owners should have Download Permissions')
  })

  it('Contributors have Download Permissions', async function() {
    // add accounts[3] as a new contributor
    await s.addContributorsAndReferences([accounts[3]], [1], [s2.address])
    await setup(artifacts, web3, 3, true)

    // check contributors can unlock files
    s.accountNumber = 3
    await s.unlockFile()
    let unlocked = (await s.getFileHash()) != ''
    s.accountNumber = 1

    assert.isTrue(unlocked, 'Download permissions are not correct')
  })

  it('Submission has References', async function() {
    let ref = await s.getReferences()
    assert.equal(ref.length, 1, 'References are not correct')
  })

  it('Submission has Contributors', async function() {
    let contribs = await s.getContributors()
    assert.equal(contribs.length, 1, 'Contributors are not correct')
  })

  it('Get Contributor Reward Distribution', async function() {
    let crd = await s.getDistribution()
    assert.equal(crd.length, 2, 'Contributor reward distribution incorrect')
  })

})
