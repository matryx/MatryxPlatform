const ethers = require('ethers')
const { setup, stringToBytes32, stringToBytes, Contract } = require('./utils')
const sleep = ms => new Promise(done => setTimeout(done, ms))

let MatryxTournament, MatryxRound, MatryxSubmission, platform, token, wallet

const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')
const genAddress = () => '0x' + new Array(40).fill(0).map(() => Math.floor(16 * Math.random()).toString(16)).join('')

const init = async () => {
  const data = await setup(artifacts, web3, 0)
  MatryxTournament = data.MatryxTournament
  MatryxRound = data.MatryxRound
  MatryxSubmission = data.MatryxSubmission
  wallet = data.wallet
  platform = data.platform
  token = data.token
}

const createTournament = async (bounty, roundData, accountNumber) => {
  const { platform } = await setup(artifacts, web3, accountNumber)
  let count = +await platform.tournamentCount()

  console.log("Platform using account", platform.wallet.address)

  const suffix = ('0' + (count + 1)).substr(-2)
  const category = stringToBytes('math')
  const title = stringToBytes32('Test Tournament ' + suffix, 3)
  const descriptionHash = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
  const fileHash = stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
  const tournamentData = {
    category,
    title,
    descriptionHash,
    fileHash,
    initialBounty: bounty,
    entryFee: web3.toWei(2)
  }
  //   const startTime = Math.floor(new Date() / 1000)
  //   const endTime = startTime + 60
  // const roundData = {
  //   start: startTime,
  //   end: endTime,
  //   reviewPeriodDuration,
  //   bounty
  // }

  let tx = await platform.createJTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 25 })
  console.log('Tournament hash:', tx.hash)

  const address = await platform.allTournaments(count)
  const tournament = Contract(address, MatryxTournament, accountNumber)
  console.log('Tournament created: ' + address)

  return tournament
}

const createSubmission = async (tournament, accountNumber) => {
  await setup(artifacts, web3, accountNumber)

  tournament.accountNumber = accountNumber
  platform.accountNumber = accountNumber
  const account = tournament.wallet.address

  const isEntrant = await tournament.isEntrant(account)
  if (!isEntrant) await platform.enterTournament(tournament.address, { gasLimit: 5e6 })

  const title = stringToBytes32('A submission ' + genId(6), 3)
  const descriptionHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
  const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

  const submissionData = {
    title,
    descriptionHash,
    fileHash,
    timeSubmitted: 0,
    timeUpdated: 0
  }

  const contribsAndRefs = {
    contributors: new Array(0).fill(0).map(r => genAddress()),
    contributorRewardDistribution: new Array(0).fill(1),
    references: new Array(0).fill(0).map(r => genAddress())
  }

  let tx = await tournament.createSubmission(submissionData, contribsAndRefs, { gasLimit: 8e6 })
  console.log(tx)
  // console.log('Submission hash:', tx.hash)

  // const [_, roundAddress] = await tournament.currentRound()
  // const round = Contract(roundAddress, MatryxRound)
  // const submissions = await round.getSubmissions()
  // const submissionAddress = submissions.pop()
  // const submission = Contract(submissionAddress, MatryxSubmission)

  console.log('Submission created:', submission.address)
  return submission
}

const updateSubmission = async submission => {
  const modData = {
    title: stringToBytes32('AAAAAA', 3),
    descriptionHash: stringToBytes32('BBBBBB', 2),
    fileHash: stringToBytes32('CCCCCC', 2)
  }

  await submission.updateData(modData)
  console.log('Submission updated data:', submission.address)

  const conModData = {
    contributorsToAdd: new Array(3).fill(0).map(() => genAddress()),
    contributorRewardDistribution: new Array(3).fill(1),
    contributorsToRemove: []
  }

  await submission.updateContributors(conModData)
  console.log('Submission updated cons:', submission.address)

  const refModData = {
    referencesToAdd: new Array(3).fill(0).map(() => genAddress()),
    referencesToRemove: []
  }

  await submission.updateReferences(refModData)
  console.log('Submission updated refs:', submission.address)
}

const logSubmissions = async tournament => {
  const currentRoundResults = await tournament.currentRound();
  const currentRoundAddress = currentRoundResults[1];
  console.log('Current round: ' + currentRoundAddress)
  const round = Contract(currentRoundAddress, MatryxRound)
  const submissions = await round.getSubmissions()
  console.log(submissions)
  return submissions;
}

const selectWinnersWhenInReview = async (tournament, accountNumber, winners, rewardDistribution, roundData, selectWinnerAction) => {
  tournament.accountNumber = accountNumber

  const currentRoundResults = await tournament.currentRound();
  const roundAddress = currentRoundResults[1];
  const round = Contract(roundAddress, MatryxRound, accountNumber)
  const roundEndTime = await round.getEndTime()

  var timeTilRoundInReview = roundEndTime - Date.now() / 1000
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0
  await sleep(timeTilRoundInReview * 1000)

  const res = await tournament.selectWinners(winners, rewardDistribution, roundData, selectWinnerAction, { gasLimit: 5000000 })
  return res
}

module.exports = async exit => {
  try {
    await init()
    let roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 60,
      reviewPeriodDuration: 600,
      bounty: web3.toWei(5),
      closed: false
    }
    const tournament = await createTournament(web3.toWei(10), roundData, 1)
    const submission = await createSubmission(tournament, 0)
    // await updateSubmission(submission)
    // await createSubmission(tournament, 2)
    // await createSubmission(tournament, 3)
    // const roundTwoData = {
    //     start: Math.floor(Date.now()/1000),
    //     end: Math.floor(Date.now()/1000) + 10,
    //     reviewPeriodDuration: 600,
    //     bounty: web3.toWei(2)
    //   }
    // const submissions = await logSubmissions(tournament);
    // await selectWinnersWhenInReview(tournament, 0, submissions, submissions.map(s => 1), roundTwoData, 0)
    // await logSubmissions(tournament)
  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}
