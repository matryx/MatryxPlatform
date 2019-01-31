const { expectEvent, shouldFail } = require('openzeppelin-test-helpers');

const { genId, setup, stringToBytes, Contract } = require('../truffle/utils')
const { init, enterTournament, createTournament, selectWinnersWhenInReview, initCommit, commitChildren, addToGroup, submitToTournament, commitCongaLine, forkCommit } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')
const IMatryxRound = artifacts.require('IMatryxRound')

let platform, commit, tournament

contract('MatryxCommit', async () => {
  before(async () => {
    platform = (await init()).platform
    commit = Contract(MatryxCommit.address, IMatryxCommit)
    await setup(artifacts, web3, 1, true)
    await setup(artifacts, web3, 2, true)
  })

  beforeEach(async () => {
    // create a tournament from account 0
    const roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 60,
      review: 60,
      bounty: toWei(100)
    }
    tournament = await createTournament('tournament', 'math', toWei(100), roundData, 0)
    tournament.accountNumber = 1
    await tournament.enter()
  })

  // reset contract accounts
  afterEach(() => {
    commit.accountNumber = 0
  })

  it('Able to create a new initial commit for a tournament', async () => {
    await setup(artifacts, web3, 1, true)
    
    // submit to tournament from account 1
    commit.accountNumber = 1
    
    const initialCommitsBefore = await commit.getInitialCommits()
    await commit.submitToTournament(tournament.address, stb('submission', 3), stb(genId(32), 2), stb(genId(32), 2), toWei(1), '0x00', 'new group')
    const initialCommitsAfter = await commit.getInitialCommits()

    const groupName = await commit.getGroupName(keccak('new group'))
    assert.equal(groupName, 'new group', 'New group exists')
    
    assert.equal(initialCommitsBefore.length+1, initialCommitsAfter.length, 'Commit creation for tournament should increase initial commit list size')
  })

  it('Able to create commit with parent for a tournament', async () => {
    const group = genId(5)
    const parentHash = await initCommit(stb(genId(32), 2), toWei(1), group, 1)
    
    const content = stb(genId(32), 2)
    const commitHash = await submitToTournament(tournament.address, stb('submission', 3), stb(genId(32), 2), content, toWei(1), parentHash, 1)
    
    const commitChild = (await commitChildren(parentHash))[0]
    assert.equal(commitChild, commitHash, 'Child commit should be same as what was submitted')
  })
  
  it('Able to withdraw reward from commit with height less than commit chain max length', async () => {
    // create conga line of commits from account 1
    const group = genId(5)
    let commitHash = await initCommit(stb(genId(32), 2), toWei(1), group, 1)

    // first 20 from account 1
    let congaLine = await commitCongaLine(commitHash, 4, 1)
    let lastCommit = congaLine[congaLine.length - 1]

    await addToGroup(1, group, accounts[2])
    
    // next 80 from account 2
    congaLine = await commitCongaLine(lastCommit, 5, 2)
    lastCommit = congaLine[congaLine.length - 1]
    
    await enterTournament(tournament, 2)
    tournament.accountNumber = 2
    await tournament.createSubmission(stb('submission', 3), stb(genId(32), 2), lastCommit)
    tournament.accountNumber = 0

    // select winners of tournament and distribute reward
    await selectWinnersWhenInReview(tournament, [lastCommit], [1], [0, 0, 0, 0], 0)
    
    const balBefore1 = await platform.getBalanceOf(accounts[1]).then(fromWei)
    const balBefore2 = await platform.getBalanceOf(accounts[2]).then(fromWei)
    await commit.distributeReward(lastCommit)
    const balAfter1 = await platform.getBalanceOf(accounts[1]).then(fromWei)
    const balAfter2 = await platform.getBalanceOf(accounts[2]).then(fromWei)

    assert.equal(balAfter1 - balBefore1, 50, "Account 1 did not get correct reward")
    assert.equal(balAfter2 - balBefore2, 50, "Account 2 did not get correct reward")
  })
  
  it('Able to withdraw reward from commit with height greater than commit chain max length', async () => {
    // create conga line of commits from account 1
    const group = genId(5)
    let commitHash = await initCommit(stb(genId(32), 2), toWei(1), group, 1)

    // first 200 from account 1
    let congaLine = await commitCongaLine(commitHash, 14, 1)
    let lastCommit = congaLine[congaLine.length - 1]

    await addToGroup(1, group, accounts[2])
    
    // next 80 from account 2
    congaLine = await commitCongaLine(lastCommit, 10, 2)
    lastCommit = congaLine[congaLine.length - 1]

    // create a tournament from account 0
    const roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 40,
      review: 60,
      bounty: toWei(100)
    }
    tournament = await createTournament('tournament', 'math', toWei(100), roundData, 0)
    
    await enterTournament(tournament, 2)
    tournament.accountNumber = 2
    await tournament.createSubmission(stb('submission', 3), stb(genId(32), 2), lastCommit)
    tournament.accountNumber = 0

    // select winners of tournament and distribute reward
    await selectWinnersWhenInReview(tournament, [lastCommit], [1], [0, 0, 0, 0], 0)
    
    const balBefore1 = await platform.getBalanceOf(accounts[1]).then(fromWei)
    const balBefore2 = await platform.getBalanceOf(accounts[2]).then(fromWei)
    await commit.distributeReward(lastCommit)
    const balAfter1 = await platform.getBalanceOf(accounts[1]).then(fromWei)
    const balAfter2 = await platform.getBalanceOf(accounts[2]).then(fromWei)

    assert.equal(balAfter1 - balBefore1, 50, "Account 1 did not get correct reward")
    assert.equal(balAfter2 - balBefore2, 50, "Account 2 did not get correct reward")
  })

  it('Correct reward distribution when submitting a fork to the tournament', async () => {
    // create conga line of commits from account 1
    const group = genId(5)
    const commitHash = await initCommit(stb(genId(32), 2), toWei(1), group, 1)

    const fork = await forkCommit(stb(genId(32), 2), toWei(3), commitHash, 2)

    await enterTournament(tournament, 2)
    tournament.accountNumber = 2
    await tournament.createSubmission(stb('submission', 3), stb(genId(32), 2), fork)
    tournament.accountNumber = 0

    // select winners of tournament and distribute reward
    await selectWinnersWhenInReview(tournament, [fork], [1], [0, 0, 0, 0], 0)
    
    const balBefore1 = await platform.getBalanceOf(accounts[1]).then(fromWei)
    const balBefore2 = await platform.getBalanceOf(accounts[2]).then(fromWei)
    await commit.distributeReward(fork)
    const balAfter1 = await platform.getBalanceOf(accounts[1]).then(fromWei)
    const balAfter2 = await platform.getBalanceOf(accounts[2]).then(fromWei)

    assert.equal(balAfter1 - balBefore1, 25, "Account 1 did not get correct reward")
    assert.equal(balAfter2 - balBefore2, 75, "Account 2 did not get correct reward")
  })
})