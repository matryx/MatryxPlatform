const fs = require('fs')
const { setup, genId, genAddress, getMinedTx, sleep, stringToBytes32, stringToBytes, Contract } = require('../truffle/utils')

module.exports = function (artifacts, web3) {
  const MatryxSystem = artifacts.require("MatryxSystem")
  const MatryxPlatform = artifacts.require("MatryxPlatform")
  const IMatryxPlatform = artifacts.require("IMatryxPlatform")
  const IMatryxTournament = artifacts.require("IMatryxTournament")
  const IMatryxRound = artifacts.require("IMatryxRound")
  const IMatryxSubmission = artifacts.require("IMatryxSubmission")
  const MatryxToken = artifacts.require("MatryxToken")
  const MatryxUser = artifacts.require("MatryxUser")
  const IMatryxUser = artifacts.require("IMatryxUser")
  const LibUtils = artifacts.require('LibUtils')
  const LibUser = artifacts.require('LibUser')
  const LibPlatform = artifacts.require('LibPlatform')
  const LibTournament = artifacts.require('LibTournament')
  const LibRound = artifacts.require('LibRound')
  const LibSubmission = artifacts.require('LibSubmission')

  let token, platform, wallet

  async function init() {
    const contract = Contract
    let commands = fs.readFileSync('./setup', 'utf8').split('\n')
    for (let command of commands) {
      await eval(command)
    }

    // console.log("token:", network.tokenAddress)
    const data = await setup(artifacts, web3, 0, true)
    platform = data.platform
    token = data.token
    return { platform, token }
  }

  async function createTournament(_title, _category, bounty, roundData, accountNumber) {
    const { platform } = await setup(artifacts, web3, accountNumber, true)

    const category = stringToBytes(_category)
    const title = stringToBytes32(_title, 3)
    const descHash = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
    const fileHash = stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
    const tournamentData = {
      category,
      title,
      descHash,
      fileHash,
      bounty,
      entryFee: web3.toWei(2)
    }

    let tx = await platform.createTournament(tournamentData, roundData)
    await getMinedTx(tx.hash)

    const address = (await platform.getTournaments(0, 0)).pop()
    const tournament = Contract(address, IMatryxTournament, accountNumber)

    return tournament
  }

  async function waitUntilClose(round) {
    let roundEndTime = +(await round.getEnd())
    let review = +(await round.getReview())
    let timeTilClose = Math.max(0, roundEndTime + review - Date.now() / 1000)
    timeTilClose = timeTilClose > 0 ? timeTilClose : 0

    await sleep(timeTilClose * 1000)
  }

  async function waitUntilOpen(round) {
    let roundStartTime = +(await round.getStart())
    let timeTilOpen = Math.max(0, roundStartTime - Date.now() / 1000)
    timeTilOpen = timeTilOpen > 0 ? timeTilOpen : 0

    await sleep(timeTilOpen * 1000)
  }

  const waitUntilInReview = async (round) => {
    let roundEndTime = await round.getEnd()

    let timeTilRoundInReview = roundEndTime - Date.now() / 1000
    timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

    await sleep(timeTilRoundInReview * 1000)
  }

  async function createSubmission(tournament, contribs, accountNumber) {
    const tAccount = tournament.accountNumber
    const pAccount = platform.accountNumber
    const tokAccount = token.accountNumber

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    token.accountNumber = accountNumber

    await enterTournament(tournament, accountNumber)

    const title = stringToBytes32('A submission ' + genId(6), 3)
    const descHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
    const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

    const submissionData = {
      title,
      descHash,
      fileHash
    }

    const noContribsAndRefs = {
      contributors: new Array(0).fill(0).map(r => genAddress()),
      distribution: new Array(1).fill(1),
      references: new Array(0).fill(0).map(r => genAddress())
    }

    const contribsAndRefs = {
      contributors: new Array(10).fill(0).map(r => genAddress()),
      distribution: new Array(11).fill(1),
      references: new Array(10).fill(0).map(r => genAddress())
    }

    if (contribs) {
      let tx = await tournament.createSubmission({ ...submissionData, ...contribsAndRefs }, {gasLimit: 3e6})
      await getMinedTx(tx.hash)
    } else {
      let tx = await tournament.createSubmission({ ...submissionData, ...noContribsAndRefs })
      await getMinedTx(tx.hash)
    }

    const [_, roundAddress] = await tournament.getCurrentRound()
    const round = Contract(roundAddress, IMatryxRound)
    const submissions = await round.getSubmissions(0, 0)
    const submissionAddress = submissions[submissions.length - 1]
    const submission = Contract(
      submissionAddress,
      IMatryxSubmission,
      accountNumber
    )

    tournament.accountNumber = tAccount
    platform.accountNumber = pAccount
    token.accountNumber = tokAccount

    return submission
  }

  async function updateSubmission(submission) {
    const modData = {
      title: stringToBytes32('AAAAAA', 3),
      descHash: stringToBytes32('BBBBBB', 2),
      fileHash: stringToBytes32('CCCCCC', 2)
    }
    let tx

    tx = await submission.updateDetails(modData)
    await getMinedTx(tx.hash)

    const contribs = {
      indices:[],
      addresses: new Array(3).fill(0).map(() => genAddress())
    }

    const distribution = new Array(3).fill(1)

    const references = {
      indices: [],
      addresses: new Array(3).fill(0).map(() => genAddress())
    }

    tx = await submission.setContributorsAndReferences(contribs, distribution, references)
    await getMinedTx(tx.hash)
  }

  async function selectWinnersWhenInReview(tournament, winners, rewardDistribution, roundData, selectWinnerAction) {
    const [_, roundAddress] = await tournament.getCurrentRound()
    const round = Contract(roundAddress, IMatryxRound, tournament.accountNumber)
    const roundEndTime = await round.getEnd()

    let timeTilRoundInReview = roundEndTime - Date.now() / 1000
    timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

    await sleep(timeTilRoundInReview * 1000)

    const tx = await tournament.selectWinners([winners, rewardDistribution, selectWinnerAction], roundData)
    await getMinedTx(tx.hash)
  }

  async function enterTournament(tournament, accountNumber) {
    await setup(artifacts, web3, accountNumber, true)
    const tAccount = tournament.accountNumber
    const pAccount = platform.accountNumber
    const tokAccount = token.accountNumber

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    token.accountNumber = accountNumber

    const account = tournament.wallet.address

    const isEntrant = await tournament.isEntrant(account)
    if (!isEntrant) {
      let allowance = +(await token.allowance(account, tournament.address))
      if (!allowance) {
        let entryFee = await tournament.getEntryFee()
        let { hash } = await token.approve(tournament.address, entryFee)
        await getMinedTx(hash)
      }
      let { hash } = await tournament.enter()
      await getMinedTx(hash)
    }

    tournament.accountNumber = tAccount
    platform.accountNumber = pAccount
    token.accountNumber = tokAccount

    let isEnt = await tournament.isEntrant(account)
    return isEnt
  }

  return {
    init,
    createTournament,
    waitUntilClose,
    waitUntilOpen,
    waitUntilInReview,
    createSubmission,
    updateSubmission,
    selectWinnersWhenInReview,
    enterTournament
  }
}
