const chalk = require('chalk')

const { setup, getMinedTx, sleep, stringToBytes32, stringToBytes, Contract } = require('./utils')

let MatryxTournament, MatryxRound, MatryxSubmission, platform, token, wallet
let timeouts = []

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

  let account = platform.wallet.address
  let count = +await platform.tournamentCount()

  console.log('Platform using account', platform.wallet.address)
  console.log(`Currently ${count} Tournaments on Platform`)

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

  let tx = await platform.createTournament(tournamentData, roundData, { gasLimit: 6e6, gasPrice: 25 })
  await getMinedTx('Platform.createTournament', tx.hash)

  const address = await platform.allTournaments(count)
  const tournament = Contract(address, MatryxTournament, accountNumber)
  console.log(chalk`Tournament created: {green ${address}}`)

  let [_, roundAddress] = await tournament.currentRound()
  let round = Contract(roundAddress, MatryxRound, accountNumber)

  console.log(chalk`Current round: {green ${roundAddress}}\n`)

  let startTime = +await round.getStartTime()
  let endTime = +await round.getEndTime()
  let reviewEnd = endTime + roundData.reviewPeriodDuration

  let now = Date.now()
  let timeTilStart = startTime * 1000 - now
  let timeTilEnd = endTime * 1000 - now
  let timeTilReviewEnd = reviewEnd * 1000 - now

  timeouts.push(setTimeout(() => console.log(chalk`{grey [Tournament round started]}`), timeTilStart))
  timeouts.push(setTimeout(() => console.log(chalk`{grey [Tournament round ended]}`), timeTilEnd))
  timeouts.push(setTimeout(() => console.log(chalk`{grey [Tournament round review ended]}`), timeTilReviewEnd))

  return tournament
}

const createSubmission = async (tournament, accountNumber) => {
  await setup(artifacts, web3, accountNumber)

  tournament.accountNumber = accountNumber
  platform.accountNumber = accountNumber
  const account = tournament.wallet.address

  const isEntrant = await tournament.isEntrant(account)
  if (!isEntrant) {
    let allowance = +await token.allowance(account, tournament.address)
    if (!allowance) {
      let entryFee = await tournament.getEntryFee().then(s => s.toString())
      token.accountNumber = accountNumber
      let { hash } = await token.approve(tournament.address, entryFee)
      await getMinedTx('Token.approve', hash)
    }
    let { hash } = await platform.enterTournament(tournament.address, { gasLimit: 5e6 })
    await getMinedTx('Platform.enterTournament', hash)
  }

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
    contributors: new Array(10).fill(0).map(r => genAddress()),
    contributorRewardDistribution: new Array(10).fill(1),
    references: new Array(10).fill(0).map(r => genAddress())
  }

  let tx = await tournament.createSubmission(submissionData, contribsAndRefs, { gasLimit: 8e6 })
  await getMinedTx('Tournament.createSubmission', tx.hash)

  const [_, roundAddress] = await tournament.currentRound()
  const round = Contract(roundAddress, MatryxRound)
  const submissions = await round.getSubmissions()
  const submissionAddress = submissions.pop()
  const submission = Contract(submissionAddress, MatryxSubmission, accountNumber)

  console.log(chalk`Submission created: {green ${submission.address}}\n`)
  return submission
}

const updateSubmission = async submission => {
  const modData = {
    title: stringToBytes32('AAAAAA', 3),
    descriptionHash: stringToBytes32('BBBBBB', 2),
    fileHash: stringToBytes32('CCCCCC', 2)
  }
  let tx

  tx = await submission.updateData(modData)
  await getMinedTx('Submission.updateData', tx.hash)

  const conModData = {
    contributorsToAdd: new Array(3).fill(0).map(() => genAddress()),
    contributorRewardDistribution: new Array(3).fill(1),
    contributorsToRemove: []
  }

  tx = await submission.updateContributors(conModData)
  await getMinedTx('Submission.updateContributors', tx.hash)

  const refModData = {
    referencesToAdd: new Array(3).fill(0).map(() => genAddress()),
    referencesToRemove: []
  }

  tx = await submission.updateReferences(refModData)
  await getMinedTx('Submission.updateReferences', tx.hash)
}

const logSubmissions = async tournament => {
  const [_, roundAddress] = await tournament.currentRound();
  console.log(chalk`Current round: {green ${roundAddress}}`)
  const round = Contract(roundAddress, MatryxRound)
  const submissions = await round.getSubmissions()
  submissions.forEach((s, i) => {
    console.log(chalk`Submission ${i + 1}: {green ${s}}`)
  })
  return submissions
}

const waitUntilClose = async (tournament) => {
  const [_, roundAddress] = await tournament.currentRound();
  const round = Contract(roundAddress, MatryxRound)
  const roundEndTime = +await round.getEndTime()
  const reviewPeriodDuration = +await round.getReviewPeriodDuration()
  const timeTilClose = Math.max(0, roundEndTime + reviewPeriodDuration - Date.now() / 1000)

  console.log(chalk`{grey [Waiting ${~~timeTilClose}s until current round over]}`)
  await sleep(timeTilClose * 1000)
}

const selectWinnersWhenInReview = async (tournament, accountNumber, winners, rewardDistribution, roundData, selectWinnerAction) => {
  tournament.accountNumber = accountNumber

  const [_, roundAddress] = await tournament.currentRound()
  const round = Contract(roundAddress, MatryxRound, accountNumber)
  const roundEndTime = await round.getEndTime()

  let timeTilRoundInReview = roundEndTime - Date.now() / 1000
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

  console.log(chalk`{grey [Waiting ${~~timeTilRoundInReview}s until review period]}`)
  await sleep(timeTilRoundInReview * 1000)

  const tx = await tournament.selectWinners([winners, rewardDistribution, selectWinnerAction, 0], roundData, { gasLimit: 5000000 })
  await getMinedTx('Tournament.selectWinners', tx.hash)
}

module.exports = async exit => {
  try {
    await init()
    let roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 420,
      reviewPeriodDuration: 120,
      bounty: web3.toWei(3),
      closed: false
    }
    const tournamentCreator = 0
    const tournament = await createTournament(web3.toWei(10), roundData, tournamentCreator)
    const submission = await createSubmission(tournament, 1)
    await updateSubmission(submission)
    await createSubmission(tournament, 2)
    await createSubmission(tournament, 3)

    roundData = {
      start: Math.floor(Date.now() / 1000) + 420,
      end: Math.floor(Date.now() / 1000) + 420,
      reviewPeriodDuration: 120,
      bounty: web3.toWei(3),
      closed: false
    }
    let submissions = await logSubmissions(tournament)
    await selectWinnersWhenInReview(tournament, tournamentCreator, submissions, submissions.map(s => 1), roundData, 1)
    timeouts.forEach(t => clearTimeout(t))
    await sleep(1000)
    await createSubmission(tournament, 1)
    await createSubmission(tournament, 2)

    submissions = await logSubmissions(tournament)
    await selectWinnersWhenInReview(tournament, tournamentCreator, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)
    await waitUntilClose(tournament)
    timeouts.forEach(t => clearTimeout(t))
    await createSubmission(tournament, 1)
    await createSubmission(tournament, 2)

    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 15,
      reviewPeriodDuration: 15,
      bounty: web3.toWei(3),
      closed: false
    }

    submissions = await logSubmissions(tournament)
    await selectWinnersWhenInReview(tournament, tournamentCreator, submissions, submissions.map(s => 1), roundData, 2)
    timeouts.forEach(t => clearTimeout(t))
    await logSubmissions(tournament)
    await waitUntilClose(tournament)
  } catch (err) {
    console.log(err.message)
  } finally {
    timeouts.forEach(t => clearTimeout(t))
    exit()
  }
}
