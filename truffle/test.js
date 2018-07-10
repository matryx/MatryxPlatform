const ethers = require('ethers')
const { setup, stringToBytes32 } = require('./helper')
const sleep = ms => new Promise(done => setTimeout(done, ms))

let MatryxTournament, MatryxRound, platform, token, wallet

const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')

const init = async () => {
  const data = await setup(artifacts, web3)
  MatryxTournament = data.MatryxTournament
  MatryxRound = data.MatryxRound
  account = data.account
  wallet = data.wallet
  platform = data.platform
  token = data.token
}

const createTournament = async () => {
  let count = +await platform.tournamentCount()

  const title = stringToBytes32('Test Tournament ' + (count + 1), 3)
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
    initialBounty: web3.toWei(10),
    entryFee: web3.toWei(2)
  }
  const startTime = Math.floor(new Date() / 1000)
  const endTime = startTime + 10
  const roundData = {
    start: startTime,
    end: endTime,
    reviewPeriodDuration: 300,
    bounty: web3.toWei(5)
  }

  await platform.createTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 25 })

  const address = await platform.allTournaments(count)
  const tournament = new ethers.Contract(address, MatryxTournament.abi, wallet)
  console.log('Tournament: ' + address)

  return tournament
}

const createSubmission = async tournament => {
  const isEntrant = await tournament.isEntrant(account)
  if (!isEntrant) await platform.enterTournament(tournament.address, { gasLimit: 5e6 })

  const content = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 1)
  const submissionData = {
    title: 'A submission ' + genId(6),
    owner: account,
    contentHash: content[0] + content[1].substr(2),
    isPublic: false
  }
  await tournament.createSubmission([], [], [], submissionData, { gasLimit: 6.5e6 })

  console.log('Submission created')
}

const logSubmissions = async tournament => {
  const rounds = await tournament.getRounds()
  console.log('Round 1: ' + rounds[0])
  const round = new ethers.Contract(rounds[0], MatryxRound.abi, wallet)
  console.log(await round.getSubmissions())
}

module.exports = async exit => {
  try {
    await init()
    const tournament = await createTournament()
    await createSubmission(tournament)
    await createSubmission(tournament)
    await createSubmission(tournament)
    await logSubmissions(tournament)
  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}
