const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')

const { setup, bytesToString, Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, updateSubmission, waitUntilInReview } = require('./helpers')(artifacts, web3)

let platform

contract('Submission Testing with No Contributors and References', function(accounts) {
  let t //tournament
  let r //round
  let s //submission
  let stime //time at submission creation
  let utime //time at submission updating

  it('Able to create a Submission', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 20,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)

    //Create submission with no contributors
    s = await createSubmission(t, false, 2)
    s = await createSubmission(t, false, 1)
    stime = Math.floor(Date.now() / 1000)
    utime = Math.floor(Date.now() / 1000)

    assert.ok(s.address, 'Submission is not valid.')
  })

  // it("Submission should exist in round", async function () {
  //   let exists = await r.submissionExists(s.address)
  //   assert.isTrue(exists, "Submission does not exist in round")
  // })

  // it("Non-submission address does not exist as a submission in round", async function () {
  //   let exists = await r.submissionExists(r.address)
  //   assert.isFalse(exists, "This address should not exist as a submission in round")
  // })

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
    assert.equal(contribs.length, 0, 'References are not correct')
  })

  it('Get Reward Distribution', async function() {
    let crd = await s.getDistribution()
    assert.equal(crd.length, 1, 'Reward distribution incorrect')
  })

  it('Get Submission Tournament', async function() {
    let ts = await s.getTournament()
    assert.equal(ts, t.address, 'Tournament Address is incorrect')
  })

  it('Get Submission Round', async function() {
    let tr = await s.getRound()
    assert.equal(tr, r.address, 'Round Address is incorrect')
  })

  it('Get Submission Owner', async function() {
    let to = await s.getOwner()
    let actual = web3.eth.accounts[1]
    assert.equal(to.toLowerCase(), actual.toLowerCase(), 'Owner Address is incorrect')
  })

  it('Get Time Submitted', async function() {
    let submission_time = await s.getTimeSubmitted().then(Number)
    assert.isTrue(Math.abs(submission_time - stime) < 10, 'Submission Time is not correct')
  })

  it('Submission title correctly updated', async function() {
    await updateSubmission(s)
    utime = Math.floor(Date.now() / 1000)
    let title = await s.getTitle()
    assert.equal(bytesToString(title[0]), 'AAAAAA', 'Submission Title should be Updated')
  })

  it('Able to update contributors', async function() {
    let con = await s.getContributors()
    assert.equal(con.length, 3, 'Contributors not updated correctly.')
  })

  it('Able to update references', async function() {
    let ref = await s.getReferences()
    assert.equal(ref.length, 3, 'Refernces not updated correctly.')
  })

  it('Get Time Updated', async function() {
    let update_time = await s.getTimeUpdated().then(Number)
    assert.isTrue(Math.abs(update_time - utime) < 10, 'Update Time is not correct')
  })

  it('Any Matryx entrant able to request download permissions', async function() {
    //switch to accounts[2]
    s.accountNumber = 2
    await waitUntilInReview(r)

    //unlock the files from accounts[2]
    await s.unlockFile()

    let permitted = await s.getViewers()
    let p2 = permitted.some(x => x.toLowerCase() == accounts[2])

    assert.isTrue(p2, 'Permissions are not correct')
  })

  it('Non Matryx entrant unable to request download permissions', async function() {
    //switch to accounts[3]
    s.accountNumber = 3

    //try to unlock the files from accounts[3]
    try {
      await s.unlockFile()
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to view files')
    }
  })
})

contract('Submission Testing with Contributors', function(accounts) {
  it('Able to create a Submission with Contributors and References', async function() {
    platform = (await init()).platform
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
    s = await createSubmission(t, true, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, IMatryxSubmission, 1)
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
    let contribs = {
      indices: [],
      addresses: [accounts[3]]
    }

    await s.setContributorsAndReferences(contribs, [1], [[], []])

    await setup(artifacts, web3, 3, true)

    // check contributors can unlock files
    s.accountNumber = 3
    await s.unlockFile()
    let unlocked = (await s.getFileHash()) != ''

    assert.isTrue(unlocked, 'Download permissions are not correct')
  })

  it('Submission has References', async function() {
    let ref = await s.getReferences()
    assert.equal(ref.length, 10, 'References are not correct')
  })

  it('Submission has Contributors', async function() {
    let contribs = await s.getContributors()
    assert.equal(contribs.length, 11, 'References are not correct')
  })

  it('Get Contributor Reward Distribution', async function() {
    let crd = await s.getDistribution()
    assert.equal(crd.length, 12, 'Contributor reward distribution incorrect')
  })
})
