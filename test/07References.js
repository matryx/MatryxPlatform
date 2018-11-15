const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')
const MatryxUser = artifacts.require('MatryxUser')
const IMatryxUser = artifacts.require('IMatryxUser')

const { Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)

let users = Contract(MatryxUser.address, IMatryxUser, 0)

contract('Adding and removing Contributors and References', function(accounts) {
  let t //tournament
  let s //submission
  let ref //reference
  let ref2 //reference

  it('Able to add a multiple contributors and references to a submission', async function() {
    await init()
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 30,
      review: 20,
      bounty: web3.toWei(5)
    }
    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)

    s = await createSubmission(t, false, 1)
    s = Contract(s.address, IMatryxSubmission, 1)

    ref = await createSubmission(t, false, 2)
    ref = Contract(ref.address, IMatryxSubmission, 2)
    ref2 = await createSubmission(t, false, 3)
    ref2 = Contract(ref2.address, IMatryxSubmission, 3)

    let contribs = [accounts[3], accounts[4]]
    let refs = [ref.address, ref2.address]
    await s.addContributorsAndReferences(contribs, [1, 2], refs)

    let c = await s.getContributors()
    let r = await s.getReferences()

    assert.isTrue(c.length == 2 && r.length == 2, 'Incorrect number of contributors or references')
  })

  it('User data for the contributors updated correctly', async function() {
    let ct = await users.getContributedTo(accounts[4])
    assert.isTrue(ct[0] == s.address, "contributedTo not updated correctly in user data")
  })

  it('Reference data updated correctly', async function() {
    let ri = await ref.getReferencedIn()
    assert.isTrue(ri[0] == s.address, "referencedIn not updated correctly in reference data")
  })

  it('Unable to remove nonexisting contributor or reference', async function() {
    await s.removeContributorsAndReferences([accounts[5]], [accounts[5]]);
    let c = await s.getContributors()
    let r = await s.getReferences()

    assert.isTrue(c.length == 2 && r.length == 2, 'Should not have removed any contributors or references')
  })

  it('Unable to add repeated contributor or reference', async function() {
      await s.addContributorsAndReferences([accounts[3]], [1], [ref.address])
      let c = await s.getContributors()
      let r = await s.getReferences()

      assert.isTrue(c.length == 2 && r.length == 2, 'Should not have added the same contributor or reference')
  })

  it('Only the submission owner can add more contributors or references', async function() {
    try {
        s.accountNumber = 2
        await s.addContributorsAndReferences([], [], [])
        assert.fail('Expected revert not received')
      } catch (error) {
        // switch back
        s.accountNumber = 1
        let revertFound = error.message.search('revert') >= 0
        assert(revertFound, 'Should not have been able to add contributors or references')
    }
  })

  it('Able to remove a contributor', async function() {
    await s.removeContributorsAndReferences([accounts[3]], [])
    let c = await s.getContributors()
    assert.isTrue(c.length == 1 && c[0].toLowerCase() == accounts[4], 'Contributor not removed correctly')
  })

  it('Submission is also removed from contributor data', async function() {
    let ct = await users.getContributedTo(accounts[3])
    assert.isTrue(ct.length == 0, "contributedTo not updated correctly in user data")
  })

  it('Able to remove all references', async function() {
    await s.removeContributorsAndReferences([], [t.address, ref.address, ref2.address])
    let c = await s.getReferences()
    assert.isTrue(c.length == 0, 'References not removed correctly')
  })

  it('Submission is also removed from all references\' data', async function() {
    let ri = await ref.getReferencedIn()
    let ri2 = await ref2.getReferencedIn()
    assert.isTrue(ri.length == 0 && ri2.length == 0, "referencedIn not updated correctly in references data")
  })

})


contract('References Reward Distribution Testing', function(accounts) {
    let t //tournament
    let r //round
    let s //submission
    let ref //reference

    it('Able to choose a winning submission with a reference', async function() {
      await init()
      roundData = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 30,
        review: 20,
        bounty: web3.toWei(5)
      }

      t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
      let [_, roundAddress] = await t.getCurrentRound()
      r = Contract(roundAddress, IMatryxRound, 0)

      s = await createSubmission(t, false, 1)
      s = Contract(s.address, IMatryxSubmission, 1)

      ref = await createSubmission(t, false, 2)
      ref = Contract(ref.address, IMatryxSubmission, 2)

      // add ref as a reference
      let refs = [ref.address]
      await s.addContributorsAndReferences([], [], refs)

      let submissions = await r.getSubmissions(0, 1)
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
      let winnings = await s.getTotalWinnings().then(fromWei)

      assert.isTrue(winnings > 0, 'Winner was not chosen')
    })

    it('Correct winning submission balance', async function() {
      let b = await s.getBalance().then(fromWei)
      assert.equal(b, 10, 'Winning submission balance should be 10')
    })

    it('Correct winning submission owner available reward', async function() {
      let b = await s.getAvailableReward().then(fromWei)
      assert.equal(b, 9, 'Available reward should be 9')
    })

    it('Reference balance is correct after original owner withdraws their reward', async function() {
      await s.withdrawReward()
      let b = await ref.getBalance().then(fromWei)
      assert.equal(b, 1, 'Reference balance should be 1')
    })

    it('Correct reference available reward', async function() {
      let b = await ref.getAvailableReward().then(fromWei)
      assert.equal(b, 1, 'Reference available reward should be 1')
    })

  })