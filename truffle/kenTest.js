const ethers = require('ethers')
const chalk = require('chalk')

const { setup, getMinedTx, stringToBytes32, stringToBytes, Contract } = require('./utils')
const sleep = ms => new Promise(done => setTimeout(done, ms))

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
    contributors: new Array(0).fill(0).map(r => genAddress()),
    contributorRewardDistribution: new Array(0).fill(1),
    references: new Array(0).fill(0).map(r => genAddress())
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
  console.log(submissions)
  return submissions;
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


const roundState = {}
roundState[0] = 'Not Yet Open'
roundState[1] = 'Unfunded'
roundState[2] = 'Open'
roundState[3] = 'InReview'
roundState[4] = 'HasWinners'
roundState[5] = 'Closed'
roundState[6] = 'Abandoned'


const logState = async (tournament, accountNumber) => {
    const [_, roundAddress] = await tournament.currentRound()
    const round = Contract(roundAddress, MatryxRound, accountNumber)
    const roundEndTime = await round.getEndTime()
    //const state = await round.getState().then(Number)
    const tstate = await tournament.getState().then(Number)
    //console.log("State of Round: " + roundState[tstate])
    console.log(chalk`{underline State of Round:} {magenta ${roundState[tstate]}}`)
    //await getMinedTx('Tournament.getState', tstate.hash)
}


module.exports = async exit => {
    try {
      await init()

      // Not Yet Open Tournament
      let round_state0 = {
        start: Math.floor(Date.now() / 1000) + 3,
        end: Math.floor(Date.now() / 1000) + 10,
        reviewPeriodDuration: 15,
        bounty: web3.toWei(3),
        closed: false
    }
      const creator = 0
      const tournament = await createTournament(web3.toWei(10), round_state0, creator)
      const state = await logState(tournament, 1)

      // Unfunded


    //Open Tournament
      let round_state2 = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 10,
        reviewPeriodDuration: 15,
        bounty: web3.toWei(3),
        closed: false
    }
    const tournament2 = await createTournament(web3.toWei(10), round_state2, creator)
    const state2 = await logState(tournament2, 1)

    //Tournament In Review
    let round_state3 = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 1,
        reviewPeriodDuration: 15,
        bounty: web3.toWei(3),
        closed: false
    }
    const tournament3 = await createTournament(web3.toWei(10), round_state3, creator)
    let submissions = await logSubmissions(tournament3)
    setTimeout(async function(){ await logState(tournament3, 1) }, 2000);
    //const state3 = await logState(tournament3, 1)


    let round_state4 = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 5,
        reviewPeriodDuration: 15,
        bounty: web3.toWei(3),
        closed: false
    }
    let next_round = {
        start: Math.floor(Date.now() / 1000) + 5,
        end: Math.floor(Date.now() / 1000) + 10,
        reviewPeriodDuration: 15,
        bounty: web3.toWei(3),
        closed: false
    }
    const tournament4 = await createTournament(web3.toWei(10), round_state4, creator)
    //let s = await logSubmissions(tournament4)
    const submission4 = await createSubmission(tournament4, 1)
    let s_log = await logSubmissions(tournament4)
    await selectWinnersWhenInReview(tournament4, creator, s_log, s_log.map(s => 1), next_round, 1)
    setTimeout(async function(){ await logState(tournament4, 1) }, 1000);
    //const state3 = await logState(tournament3, 1)

    let round_state5 = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 5,
        reviewPeriodDuration: 10,
        bounty: web3.toWei(3),
        closed: false
    }

    const tournament5 = await createTournament(web3.toWei(10), round_state5, creator)
    //let s = await logSubmissions(tournament4)
    const submission5 = await createSubmission(tournament5, 1)
    let s_log2 = await logSubmissions(tournament5)
    await selectWinnersWhenInReview(tournament5, creator, s_log2, s_log2.map(s => 1), next_round, 2)
    setTimeout(function() {console.log("Tournament Should be Closed") }, 1000)
    setTimeout(async function() {await logState(tournament5, 1) }, 1000)

    let round_state6 = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 1,
        reviewPeriodDuration: 1,
        bounty: web3.toWei(3),
        closed: false
    }


    const tournament6 = await createTournament(web3.toWei(10), round_state6, creator)
    //let s = await logSubmissions(tournament4)
    //const submission6 = await createSubmission(tournament6, 1)
    let s_log3 = await logSubmissions(tournament6)
    //await selectWinnersWhenInReview(tournament6, creator, s_log3, s_log3.map(s => 1), next_round, 2)
    setTimeout(async function(){ await logState(tournament6, 1) }, 5000);





    } catch (err) {
      console.log(err.message)
    } finally {
      timeouts.forEach(t => clearTimeout(t))
      exit()
    }
  }