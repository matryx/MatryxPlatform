const IMatryxRound = artifacts.require('IMatryxRound')
const IMatryxSubmission = artifacts.require('IMatryxSubmission')

const { Contract } = require('../truffle/utils')
const { init, createTournament, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)

contract('References Reward Distribution Testing', function(accounts) {
    let t //tournament
    let r //round
    let s //submission
    let ref //reference

    it('Able to choose a winning submission and Do Nothing', async function() {
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
      let refs = {
        indices: [],
        addresses: [ref.address]
      }
      await s.setContributorsAndReferences([[], []], [], refs)

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