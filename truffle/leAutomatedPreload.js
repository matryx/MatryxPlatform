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
  const { platform } = await setup(artifacts, web3, accountNumber)
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

  const descriptionHash = stringToBytes('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK')
  const fileHash = stringToBytes('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g')

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

const getSubmissions = async tournament => {
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
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview + 1 : 0
  await sleep(timeTilRoundInReview*1000)

  const params = [winners, rewardDistribution, Object.values(roundData), selectWinnerAction]
  console.log(params)

  const res = await tournament.selectWinners(...params, {gasLimit: 5000000})
  return res;
}

module.exports = async exit => {
  try {
    await init()
    let scOne_RoundData = { 
        start: Math.floor(Date.now()/1000) + 1e9, 
        end: Math.floor(Date.now()/1000) + 1e9 + 10, 
        reviewPeriodDuration: 1, 
        bounty: web3.toWei(5)
    } 
    const tournamentOne = await createTournament(web3.toWei(10), scOne_RoundData, 0)
    let scTwo_RoundData = { 
        start: Math.floor(Date.now()/1000), 
        end: Math.floor(Date.now()/1000) + 1e9, 
        reviewPeriodDuration: 1, 
        bounty: web3.toWei(5)
    } 
    const tournamentTwo = await createTournament(web3.toWei(10), scTwo_RoundData, 0)
    let scThree_RoundData = { 
        start: Math.floor(Date.now()/1000), 
        end: Math.floor(Date.now()/1000) + 1, 
        reviewPeriodDuration: 1e9, 
        bounty: web3.toWei(5)
      } 
    const tournamentThree = await createTournament(web3.toWei(10), scThree_RoundData, 0)
    let scFour_RoundData = { 
        start: Math.floor(Date.now()/1000), 
        end: Math.floor(Date.now()/1000) + 1e9, 
        reviewPeriodDuration: 1, 
        bounty: web3.toWei(5)
      } 
    const tournamentFour = await createTournament(web3.toWei(10), scFour_RoundData, 0)
    await createSubmission(tournamentFour, 1)
    await createSubmission(tournamentFour, 2)
    await createSubmission(tournamentFour, 3)
    let scFive_RoundData = { 
        start: Math.floor(Date.now()/1000), 
        end: Math.floor(Date.now()/1000) + 10, 
        reviewPeriodDuration: 1e9, 
        bounty: web3.toWei(5)
      } 
    const tournamentFive = await createTournament(web3.toWei(10), scFive_RoundData, 0)
    await createSubmission(tournamentFive, 1)
    await createSubmission(tournamentFive, 2)
    await createSubmission(tournamentFive, 3)
    let scSix_RoundData = { 
        start: Math.floor(Date.now()/1000), 
        end: Math.floor(Date.now()/1000) + 10, 
        reviewPeriodDuration: 1, 
        bounty: web3.toWei(5)
      }
      const tournamentSix = await createTournament(web3.toWei(10), scSix_RoundData, 0)
      await createSubmission(tournamentSix, 1);
      await createSubmission(tournamentSix, 2);
      await createSubmission(tournamentSix, 3);
      let scSeven_RoundData = { 
        start: Math.floor(Date.now()/1000), 
        end: Math.floor(Date.now()/1000) + 10, 
        reviewPeriodDuration: 1e9,
        bounty: web3.toWei(5)
      }
      let scSeven_RoundDataTwo = { 
        start: Math.floor(Date.now()/1000) + 30, 
        end: Math.floor(Date.now()/1000) + 1e9, 
        reviewPeriodDuration: 1e9,
        bounty: web3.toWei(5)
      }
      const tournamentSeven = await createTournament(web3.toWei(10), scSeven_RoundData, 0)
      await createSubmission(tournamentSeven, 1);
      await createSubmission(tournamentSeven, 2);
      await createSubmission(tournamentSeven, 3);
      const tournamentSevenSubmissions = await getSubmissions(tournamentSeven);
      await selectWinnersWhenInReview(tournamentSeven, 0, tournamentSevenSubmissions, tournamentSevenSubmissions.map(s => "1"), [0,0,0,0], 0)
    // await getSubmissions(tournament)
  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}