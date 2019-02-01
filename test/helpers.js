const fs = require('fs')
const { setup, genId, genAddress, getMinedTx, sleep, stringToBytes, Contract } = require('../truffle/utils')

const toWei = n => web3.utils.toWei(n.toString())
web3.toWei = toWei

Contract.logLevel = 1

module.exports = function (artifacts, web3) {
  const MatryxSystem = artifacts.require("MatryxSystem")
  const MatryxPlatform = artifacts.require("MatryxPlatform")
  const IMatryxPlatform = artifacts.require("IMatryxPlatform")
  const IMatryxTournament = artifacts.require("IMatryxTournament")
  const IMatryxRound = artifacts.require("IMatryxRound")
  const MatryxToken = artifacts.require("MatryxToken")
  const MatryxUser = artifacts.require("MatryxUser")
  const IMatryxUser = artifacts.require("IMatryxUser")
  const LibUser = artifacts.require('LibUser')
  const MatryxCommit = artifacts.require("MatryxCommit")
  const IMatryxCommit = artifacts.require("IMatryxCommit")
  const LibCommit = artifacts.require('LibCommit')
  const LibPlatform = artifacts.require('LibPlatform')
  const LibTournament = artifacts.require('LibTournament')
  const LibRound = artifacts.require('LibRound')

  let token, platform, commit, wallet

  async function init() {
    const contract = Contract
    let commands = fs.readFileSync('./setup', 'utf8').split('\n')
    for (let command of commands) {
      await eval(command)
    }

    // console.log("token:", network.tokenAddress)
    const data = await setup(artifacts, web3, 0, true)
    platform = data.platform
    commit = data.commit
    token = data.token
    return { platform, token }
  }

  async function createTournament(_title, bounty, roundData, accountNumber) {
    const { platform } = await setup(artifacts, web3, accountNumber, true)

    const title = stringToBytes(_title, 3)
    const descHash = stringToBytes('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
    const fileHash = stringToBytes('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
    const tournamentData = {
      title,
      descHash,
      fileHash,
      bounty,
      entryFee: toWei(2)
    }

    let tx = await platform.createTournament(tournamentData, roundData)
    await getMinedTx(tx.hash)

    const address = (await platform.getTournaments()).pop()
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

  async function createSubmission(tournament, accountNumber) {
    const tAccount = tournament.accountNumber
    const pAccount = platform.accountNumber
    const cAccount = commit.accountNumber
    const tokAccount = token.accountNumber

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    commit.accountNumber = accountNumber
    token.accountNumber = accountNumber

    await enterTournament(tournament, accountNumber)

    const title = stringToBytes('A submission ' + genId(6), 3)
    const descHash = stringToBytes('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
    const fileHash = stringToBytes(genId(32), 2)

    let tx = await commit.submitToTournament(tournament.address, title, descHash, fileHash, toWei(2), '0x00', genId(5))
    await getMinedTx(tx.hash)

    const [_, roundAddress] = await tournament.getCurrentRound()
    const round = Contract(roundAddress, IMatryxRound)
    const submissions = await round.getSubmissions()
    const submission = submissions[submissions.length - 1]

    tournament.accountNumber = tAccount
    platform.accountNumber = pAccount
    commit.accountNumber = cAccount
    token.accountNumber = tokAccount

    return submission
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
      let allowance = +(await token.allowance(account, platform.address))
      if (!allowance) {
        let entryFee = await tournament.getEntryFee()
        let { hash } = await token.approve(platform.address, entryFee)
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

  async function createCommit (contentHash, value, parent, account) {
    const cAccount = commit.accountNumber
    commit.accountNumber = account
    await commit.commit(contentHash, value, parent)
    commit.accountNumber = cAccount

    // return the newly created commit hash
    const parentCommit = await commit.getCommit(parent)
    return parentCommit.children[parentCommit.children.length - 1]
  }

  async function initCommit (contentHash, value, group, account) {
    const cAccount = commit.accountNumber
    commit.accountNumber = account
    await commit.initialCommit(contentHash, value, group)
    commit.accountNumber = cAccount

    const theCommit = await commit.getCommitByContentHash(contentHash)
    return theCommit.commitHash
  }

  async function commitChildren (commitHash) {
    const theCommit = await commit.getCommit(commitHash)
    const children = theCommit.children
    return children
  }

  async function addToGroup (member, group, newMember) {
    const cAccount = commit.accountNumber
    commit.accountNumber = member

    await commit.addGroupMember(group, newMember)

    commit.accountNumber = cAccount
  }

  async function submitToTournament (tAddress, title, descHash, contentHash, value, parent, account) {
    const tournament = Contract(tAddress, IMatryxTournament)
    const cAccount = commit.accountNumber

    commit.accountNumber = account

    // random group if no parent
    let group = genId(5) 
    if (parent != '0x00') {
      const parentCommit = await commit.getCommit(parent)
      group = parentCommit.groupHash
    }

    await commit.submitToTournament(tAddress, title, descHash, contentHash, value, parent, group)
    const round = Contract((await tournament.getCurrentRound())[1], IMatryxRound)
    commit.accountNumber = cAccount

    const submissions = await round.getSubmissions()
    return submissions[submissions.length-1]
  }

  async function commitCongaLine (root, length, account) {
    const congaLine = [root]

    let parent = root
    for (let i = 0; i < length; i++) {
      parent = await createCommit(stringToBytes(genId(34), 2), toWei(1), parent, account)
      congaLine.push(parent)
    }

    return congaLine
  }

  async function forkCommit (contentHash, value, parent, accountNumber) {
    const lastAccount = commit.accountNumber
    commit.accountNumber = accountNumber

    const group = "group " + genId(5)
    await commit.createGroup(group)
    await commit.fork(contentHash, value, parent, group, { gasLimit: 8e6 })

    const parentCommit = await commit.getCommit(parent)
    const commitHash = parentCommit.children[parentCommit.children.length - 1]

    commit.accountNumber = lastAccount
    return commitHash
  }

  return {
    init,
    createTournament,
    waitUntilClose,
    waitUntilOpen,
    waitUntilInReview,
    createSubmission,
    selectWinnersWhenInReview,
    enterTournament,
    
    createCommit,
    initCommit,
    commitChildren,
    addToGroup,
    submitToTournament,
    commitCongaLine,
    forkCommit
  }
}
