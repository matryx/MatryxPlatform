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
  const MatryxToken = artifacts.require("MatryxToken")
  const MatryxCommit = artifacts.require("MatryxCommit")
  const IMatryxCommit = artifacts.require("IMatryxCommit")
  const LibCommit = artifacts.require('LibCommit')
  const LibPlatform = artifacts.require('LibPlatform')
  const LibTournament = artifacts.require('LibTournament')

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
    return { platform, commit, token }
  }

  async function createTournament(content, bounty, roundData, accountNumber) {
    const { platform } = await setup(artifacts, web3, accountNumber, true)

    const tournamentData = {
      content,
      bounty,
      entryFee: toWei(2)
    }

    let tx = await platform.createTournament(tournamentData, roundData)
    await getMinedTx(tx.hash)

    const address = (await platform.getTournaments()).pop()
    const tournament = Contract(address, IMatryxTournament, accountNumber)

    return tournament
  }

  async function waitUntilClose(tournament, roundIndex) {
    let { start, duration, review } = await tournament.getRoundDetails(roundIndex)
    let time = Math.max(0, (+start) + (+duration) + (+review) - Date.now() / 1000)
    await sleep(time * 1000)
  }

  async function waitUntilOpen(tournament, roundIndex) {
    let { start } = await tournament.getRoundDetails(roundIndex)
    let time = Math.max(0, (+start) - Date.now() / 1000)
    await sleep(time * 1000)
  }

  async function waitUntilInReview(tournament, roundIndex) {
    let { start, duration } = await tournament.getRoundDetails(roundIndex)
    let time = Math.max(0, (+start) + (+duration) - Date.now() / 1000)
    await sleep(time * 1000)
  }

  async function createSubmission(tournament, parent, value, accountNumber) {
    const tAccount = tournament.accountNumber
    const pAccount = platform.accountNumber
    const cAccount = commit.accountNumber
    const tokAccount = token.accountNumber

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    commit.accountNumber = accountNumber
    token.accountNumber = accountNumber

    await enterTournament(tournament, accountNumber)

    const contentHash = genId(10)
    
    let account = tournament.wallet.address
    let salt = "mmm salty"
    let commitHash = web3.utils.soliditySha3(account, { t: 'bytes32', v: salt }, contentHash)
    
    let tx = await commit.claimCommit(commitHash)
    await getMinedTx(tx.hash)
    
    const content = genId(10)
    tx = await commit.createSubmission(tournament.address, content, parent, false, contentHash, value)
    await getMinedTx(tx.hash)

    const roundIndex = await tournament.getCurrentRoundIndex()
    const { submissions } = await tournament.getRoundInfo(roundIndex)
    const submission = submissions[submissions.length - 1]

    tournament.accountNumber = tAccount
    platform.accountNumber = pAccount
    commit.accountNumber = cAccount
    token.accountNumber = tokAccount

    return submission
  }

  async function selectWinnersWhenInReview(tournament, winners, rewardDistribution, roundData, selectWinnerAction) {
    let roundIndex = await tournament.getCurrentRoundIndex()
    await waitUntilInReview(tournament, roundIndex)

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

  async function claimCommit(salt, contentHash, account) {
    const cAccount = commit.accountNumber
    commit.accountNumber = account

    let commitHash = web3.utils.soliditySha3(commit.wallet.address, { t:'bytes32', v:salt }, contentHash)
    
    let tx = await commit.claimCommit(commitHash)
    await getMinedTx(tx.hash)
    
    commit.accountNumber = cAccount
  }
  
  async function createCommit(parent, isFork, contentHash, value, account) {
    const cAccount = commit.accountNumber
    commit.accountNumber = account

    const salt = stringToBytes('NaCl')
    await claimCommit(salt, contentHash, account)
    tx = await commit.createCommit(parent, isFork, salt, contentHash, value)
    await getMinedTx(tx.hash)

    commit.accountNumber = cAccount

    // return the newly created commit hash
    let theCommit = await commit.getCommitByContentHash(contentHash)
    return theCommit.commitHash
  }

  async function commitChildren (commitHash) {
    const theCommit = await commit.getCommit(commitHash)
    return theCommit.children
  }

  async function commitCongaLine (root, length, account) {
    const congaLine = [root]

    let parent = root
    for (let i = 0; i < length; i++) {
      parent = await createCommit(parent, false, genId(10), toWei(1), account)
      congaLine.push(parent)
    }

    return congaLine
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
    
    claimCommit,
    createCommit,
    commitChildren,
    commitCongaLine
  }
}
