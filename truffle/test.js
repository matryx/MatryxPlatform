const Web3 = require('web3')
const web3 = new Web3('taco')
const { setupContracts, createTournament, createSubmission, selectWinnersWhenInReview } = require('../test/helpers')(artifacts, web3)
const { Contract } = require('./utils')
Contract.logLevel = 2

let platform, commit

const toWei = n => web3.utils.toWei(n.toString())
web3.toWei = toWei

module.exports = async exit => {
  try {
    let data = await setupContracts()
    platform = data.platform
    commit = data.commit

    roundData = {
      start: 0,
      duration: 10,
      review: 10,
      bounty: toWei(5)
    }

    t = await createTournament('tournament', toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()

    s = await createSubmission(t, '0x00', toWei(1), 1)
    commitHash = (await platform.getSubmission(s)).commitHash

    await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 2)

    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0

  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}
