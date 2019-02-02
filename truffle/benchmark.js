const fs = require('fs')
const chalk = require('chalk')

const { setup, genId, genAddress, getMinedTx, sleep, stringToBytes32, stringToBytes, Contract } = require('./utils')
const toWei = n => web3.utils.toWei(n.toString())
web3.toWei = toWei

let MatryxTournament, MatryxRound, MatryxSubmission, platform, token, wallet
let IMatryxTournament, IMatryxRound, IMatryxSubmission
let timeouts = []

const init = async () => {
  const data = await setup(artifacts, web3, 0)
  MatryxTournament = data.MatryxTournament
  IMatryxTournament = data.IMatryxTournament
  MatryxRound = data.MatryxRound
  IMatryxRound = data.IMatryxRound
  MatryxSubmission = data.MatryxSubmission
  IMatryxSubmission = data.IMatryxSubmission
  wallet = data.wallet
  platform = data.platform
  token = data.token
}

let benchmarkReport = ''
const report = msg => {
  console.log(msg)
  benchmarkReport += msg + '\n'
}

const createTournament = async (accountNumber) => {
  const tournamentData = {
    title: stringToBytes32('Benchmark Tournament', 3),
    descHash: stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2),
    fileHash: stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2),
    bounty: web3.toWei(10),
    entryFee: web3.toWei(2)
  }

  const start = Math.floor(new Date() / 1000)
  const roundData = {
    start,
    end: start + 600,
    review: 600,
    bounty: web3.toWei(5)
  }

  const tx = await platform.createTournament(tournamentData, roundData)
  const txr = await getMinedTx(tx.hash)

  return txr
}

let refs = []
const createSubmission = async (tournament, accountNumber, numContribs, numRefs) => {
  tournament.accountNumber = accountNumber
  platform.accountNumber = accountNumber
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

  const submissionData = {
    title: stringToBytes32('Benchmark Submission', 3),
    descHash: stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2),
    fileHash: stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2),
    distribution: new Array(numContribs + 1).fill(0).map((_, i) => 1),
    contributors: new Array(numContribs).fill(0).map(r => genAddress()),
    references: refs.slice(0, numRefs)
  }

  const tx = await tournament.createSubmission(submissionData)
  const txr = await getMinedTx(tx.hash)

  const [_, roundAddress] = await tournament.getCurrentRound()
  const round = Contract(roundAddress, IMatryxRound)
  const submissionAddress = (await round.getSubmissions(0,0)).pop()
  refs.push(submissionAddress)

  return txr
}

const benchmarkTournaments = async () => {
  await setup(artifacts, web3, 0, true)

  const gasUsed = []

  for (let i = 0; i < 10; i++) {
    const txr = await createTournament(0)
    gasUsed.push(+txr.gasUsed)
  }

  const first = gasUsed.shift()
  const average = gasUsed.reduce((a, x) => a + x) / gasUsed.length
  report(`first tournament: ${first}`)
  report(`average tournament: ${average}\n`)
}

const benchmarkSubmissions = async () => {
  await setup(artifacts, web3, 1, true)

  let gasUsed

  const tAddress = (await platform.getTournaments(0, 0)).pop()
  const t = Contract(tAddress, IMatryxTournament)

  gasUsed = []
  for (let i = 0; i < 10; i++) {
    const txr = await createSubmission(t, '0x00',  false, 1, 0, 0)
    gasUsed.push(+txr.gasUsed)
  }

  let first = gasUsed.shift()
  let average = gasUsed.reduce((a, x) => a + x) / gasUsed.length
  report(`first submission (0 contribs, 0 refs): ${first}`)
  report(`average submission (0 contribs, 0 refs): ${average}`)

  gasUsed = []
  for (let i = 0; i < 5; i++) {
    const txr = await createSubmission(t, '0x00',  false, 1, 5, 0)
    gasUsed.push(+txr.gasUsed)
  }

  average = gasUsed.reduce((a, x) => a + x) / gasUsed.length
  report(`average submission (5 contribs, 0 refs): ${average}`)

  gasUsed = []
  for (let i = 0; i < 5; i++) {
    const txr = await createSubmission(t, '0x00',  false, 1, 0, 5)
    gasUsed.push(+txr.gasUsed)
  }

  average = gasUsed.reduce((a, x) => a + x) / gasUsed.length
  report(`average submission (0 contribs, 5 refs): ${average}`)

  gasUsed = []
  for (let i = 0; i < 5; i++) {
    const txr = await createSubmission(t, '0x00',  false, 1, 5, 5)
    gasUsed.push(+txr.gasUsed)
  }

  average = gasUsed.reduce((a, x) => a + x) / gasUsed.length
  report(`average submission (5 contribs, 5 refs): ${average}`)
}

module.exports = async exit => {
  try {
    await init()
    await benchmarkTournaments()
    await benchmarkSubmissions()

    const dateStr = new Date().toLocaleString().replace(/:\d\d$/, '')
    const reportFile = `./truffle/benchmarks/benchmark ${dateStr}.txt`
    fs.writeFileSync(reportFile, benchmarkReport)
  } catch (err) {
    console.log(err.message)
  } finally {
    timeouts.forEach(t => clearTimeout(t))
    exit()
  }
}
