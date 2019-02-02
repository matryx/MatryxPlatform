const chalk = require('chalk')

const { setup, genId, genAddress, getMinedTx, sleep, stringToBytes, Contract } = require('./utils')
const toWei = n => web3.utils.toWei(n.toString())
web3.toWei = toWei

let MatryxTournament, MatryxRound, platform, token, wallet, commit
let IMatryxTournament, IMatryxRound
let timeouts = []

const init = async () => {
  const data = await setup(artifacts, web3, 0)
  MatryxTournament = data.MatryxTournament
  IMatryxTournament = data.IMatryxTournament
  MatryxRound = data.MatryxRound
  IMatryxRound = data.IMatryxRound
  wallet = data.wallet
  platform = data.platform
  token = data.token
  commit = data.commit
}

const createTournament = async (bounty, roundData, accountNumber) => {
  const { platform } = await setup(artifacts, web3, accountNumber)

  let account = platform.wallet.address
  let count = +await platform.getTournamentCount()

  console.log('Platform using account', platform.wallet.address)
  console.log(`Currently ${count} Tournaments on Platform`)

  const suffix = ('0' + (count + 1)).substr(-2)
  const title = stringToBytes('Test Tournament ' + suffix, 3)
  const descHash = stringToBytes('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
  const fileHash = stringToBytes('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
  const tournamentData = {
    title,
    descHash,
    fileHash,
    bounty,
    entryFee: toWei(2)
  }
  //   const startTime = Math.floor(new Date() / 1000)
  //   const endTime = startTime + 60
  // const roundData = {
  //   start: startTime,
  //   end: endTime,
  //   review,
  //   bounty
  // }

  let tx = await platform.createTournament(tournamentData, roundData)
  await getMinedTx(tx.hash)

  const address = (await platform.getTournaments()).pop()
  const tournament = Contract(address, IMatryxTournament, accountNumber)
  console.log(chalk`Tournament created: {green ${address}}`)

  let [_, roundAddress] = await tournament.getCurrentRound()
  let round = Contract(roundAddress, IMatryxRound, accountNumber)

  console.log(chalk`Current round: {green ${roundAddress}}\n`)

  let startTime = +await round.getStart()
  let endTime = +await round.getEnd()
  let reviewEnd = endTime + roundData.review

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
  commit.accountNumber = accountNumber
  const account = tournament.wallet.address

  const isEntrant = await tournament.isEntrant(account)
  if (!isEntrant) {
    let allowance = +await token.allowance(account, platform.address)
    if (!allowance) {
      let entryFee = await tournament.getEntryFee()
      token.accountNumber = accountNumber
      let { hash } = await token.approve(platform.address, entryFee)
      await getMinedTx(hash)
    }
    let { hash } = await tournament.enter()
    await getMinedTx(hash)
  }

  const title = stringToBytes('A submission ' + genId(6), 3)
  const descHash = stringToBytes('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
  const contentHash = stringToBytes(genId(32), 2)

  // let tx = await tournament.createSubmission(submissionData, contribsAndRefs)
  let tx = await commit.submitToTournament(tournament.address, title, descHash, contentHash, toWei(1), '0x00', genId(10))
  await getMinedTx(tx.hash)

  const [_, roundAddress] = await tournament.getCurrentRound()
  const round = Contract(roundAddress, IMatryxRound)
  const commitHash = (await round.getSubmissions()).pop()

  console.log(chalk`Submission created: {green ${commitHash}}\n`)
  return commitHash
}

const logSubmissions = async tournament => {
  const [_, roundAddress] = await tournament.getCurrentRound();
  console.log(chalk`Current round: {green ${roundAddress}}`)
  const round = Contract(roundAddress, IMatryxRound)
  const submissions = await round.getSubmissions()
  submissions.forEach((s, i) => {
    console.log(chalk`Submission ${i + 1}: {green ${s}}`)
  })
  return submissions
}

const logSubmissionMtx = async submissions => {
  await Promise.all(submissions.map(async (s, i) => {
    const mtx = await token.balanceOf(s) / 1e18
    console.log(chalk`Submission ${i + 1}: {green ${s}} (${mtx} MTX)`)
  }))
}

const logRoundState = async tournament => {
  const [_, roundAddress] = await tournament.getCurrentRound();
  const round = Contract(roundAddress, IMatryxRound)
  console.log(chalk`Current Round: {green ${roundAddress}} ${await round.getState()}`)
}

const waitUntilClose = async (tournament) => {
  const [_, roundAddress] = await tournament.getCurrentRound();
  const round = Contract(roundAddress, IMatryxRound)
  const roundEndTime = +await round.getEnd()
  const review = +await round.getReview()
  const timeTilClose = Math.max(0, roundEndTime + review - Date.now() / 1000)

  console.log(chalk`{grey [Waiting ${~~timeTilClose}s until current round over]}`)
  await sleep(timeTilClose * 1000)
}

const selectWinnersWhenInReview = async (tournament, accountNumber, winners, rewardDistribution, roundData, selectWinnerAction) => {
  tournament.accountNumber = accountNumber

  const [_, roundAddress] = await tournament.getCurrentRound()
  const round = Contract(roundAddress, IMatryxRound, accountNumber)
  const roundEndTime = await round.getEnd()

  let timeTilRoundInReview = roundEndTime - Date.now() / 1000
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

  console.log(chalk`{grey [Waiting ${~~timeTilRoundInReview}s until review period]}`)
  await sleep(timeTilRoundInReview * 1000)

  const tx = await tournament.selectWinners([winners, rewardDistribution, selectWinnerAction], roundData, { gasLimit: 8e6 })
  await getMinedTx(tx.hash)

  logSubmissionMtx(winners)
}

module.exports = async exit => {
  try {
    await init()
    let roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 3600,
      review: 10,
      bounty: toWei(3)
    }
    const tournament = await createTournament(toWei(10), roundData, 0)
    const submission = await createSubmission(tournament, 1)
    // let c = await submission.getContributors()
    // console.log(c)
    // await updateSubmission(submission)
    // c = await submission.getContributors()
    // console.log(c)
    await createSubmission(tournament, 2)
    await createSubmission(tournament, 3)

    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 20,
      review: 20,
      bounty: toWei(3)
    }
    let submissions = await logSubmissions(tournament)
    await selectWinnersWhenInReview(tournament, 0, submissions, submissions.map(s => 1), roundData, 1)
    // timeouts.forEach(t => clearTimeout(t))
    // await sleep(1000)
    // await createSubmission(tournament, 1)
    // await createSubmission(tournament, 2)

    // submissions = await logSubmissions(tournament)

    // await logRoundState(tournament)
    // await selectWinnersWhenInReview(tournament, tournamentCreator, submissions, submissions.map(s => 1), [0, 0, 0, 0], 0)
    // await logRoundState(tournament)
    // await tournament.closeTournament()
    // console.log(chalk`{grey calling closeTournament}`)
    // await logRoundState(tournament)
    // await logSubmissionMtx(submissions)

    // await waitUntilClose(tournament)
    // timeouts.forEach(t => clearTimeout(t))
    // await createSubmission(tournament, 1)
    // await createSubmission(tournament, 2)

    // roundData = {
    //   start: Math.floor(Date.now() / 1000),
    //   end: Math.floor(Date.now() / 1000) + 15,
    //   review: 15,
    //   bounty: toWei(3)
    // }

    // submissions = await logSubmissions(tournament)
    // await selectWinnersWhenInReview(tournament, tournamentCreator, submissions, submissions.map(s => 1), roundData, 2)
    // timeouts.forEach(t => clearTimeout(t))
    // await waitUntilClose(tournament)
  } catch (err) {
    console.log(err.message)
  } finally {
    timeouts.forEach(t => clearTimeout(t))
    exit()
  }
}
