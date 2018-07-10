const ethers = require('ethers')
const { setup, stringToBytes32, stringToBytes, Contract } = require('./helper')
const sleep = ms => new Promise(done => setTimeout(done, ms))

let MatryxTournament, MatryxRound, platform, token, wallet

const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')

const init = async () => {
  const data = await setup(artifacts, web3, 0)
  MatryxTournament = data.MatryxTournament
  MatryxRound = data.MatryxRound
  wallet = data.wallet
  platform = data.platform
  token = data.token
}

const createTournament = async (bounty, roundData, accountNumber) => {
  // const { platform } = await setup(artifacts, web3, accountNumber)
  let count = +await platform.tournamentCount()

  console.log("Platform using account", platform.wallet.address)

  const suffix = ('0' + (count + 1)).substr(-2)
  const title = stringToBytes32('Test Tournament ' + suffix, 3)
  const descriptionHash = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
  const fileHash = stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
  const tournamentData = {
    category: 'math',
    title_1: title[0],
    title_2: title[1],
    title_3: title[2],
    descriptionHash_1: descriptionHash[0],
    descriptionHash_2: descriptionHash[1],
    fileHash_1: fileHash[0],
    fileHash_2: fileHash[1],
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

  await platform.createTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 25 })

  const address = await platform.allTournaments(count)
  const tournament = Contract(address, MatryxTournament, accountNumber)
  console.log('Tournament: ' + address)

  return tournament
}

const createSubmission = async (tournament, accountNumber) => {
  await setup(artifacts, web3, accountNumber)

  tournament.accountNumber = accountNumber
  platform.accountNumber = accountNumber
  const account = tournament.wallet.address
  
  const isEntrant = await tournament.isEntrant(account)
  if (!isEntrant) await platform.enterTournament(tournament.address, { gasLimit: 5e6 })

  const descriptionHash = stringToBytes('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke')
  const fileHash = stringToBytes('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke')

  const submissionData = {
    title: 'A submission ' + genId(6),
    owner: account,
    descriptionHash,
    fileHash,
    isPublic: false
  }
  await tournament.createSubmission([], [], [], submissionData, { gasLimit: 6.5e6 })

  console.log('Submission created')
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

  var timeTilRoundInReview = roundEndTime - Date.now()/1000
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0
  await sleep(timeTilRoundInReview*1000)

  const res = await tournament.selectWinners(winners, rewardDistribution, roundData, selectWinnerAction)
  return res;
}

module.exports = async exit => {
  try {
    await init()
    let roundData = { 
      start: Math.floor(Date.now()/1000), 
      end: Math.floor(Date.now()/1000) + 10, 
      reviewPeriodDuration: 600, 
      bounty: web3.toWei(5)
    } 
    const tournament = await createTournament(web3.toWei(10), roundData, 0)
    await createSubmission(tournament, 1)
    await createSubmission(tournament, 2)
    await createSubmission(tournament, 3)
    const roundTwoData = {
        start: Math.floor(Date.now()/1000),
        end: Math.floor(Date.now()/1000) + 10,
        reviewPeriodDuration: 600, 
        bounty: web3.toWei(2)
      }
    const submissions = await logSubmissions(tournament);
    await selectWinnersWhenInReview(tournament, 0, submissions, submissions.map(s => 1), roundTwoData, 2)
    await logSubmissions(tournament)
  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}
