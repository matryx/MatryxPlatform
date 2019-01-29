const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')
const MatryxUser = artifacts.require('MatryxUser')
const IMatryxUser = artifacts.require('IMatryxUser')

const { setup, bytesToString, Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, updateSubmission, waitUntilInReview } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform
let users

contract('Submission Testing with No Contributors and References', function() {
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

  it('Submission has no Contributors', async function() {
    let contribs = await s.getContributors()
    assert.equal(contribs.length, 0, 'Contributors are not correct')
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
    let actual = accounts[1]
    assert.equal(to, actual, 'Owner is incorrect')
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
})

contract('Submission Testing with Contributors', function() {
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

  it('Contributors have Download Permissions', async function() {
    await setup(artifacts, web3, 3, true)
    // add accounts[3] as a new contributor
    await s.addContributorsAndReferences([accounts[3]], [1], [s2.address])

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
