const { expectEvent, shouldFail } = require('openzeppelin-test-helpers');

const { genId, setup, stringToBytes, Contract } = require('../truffle/utils')
const { init, enterTournament, createTournament, selectWinnersWhenInReview, initCommit, commitChildren, addToGroup, commitCongaLine, forkCommit, createSubmission } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

const MatryxCommit = artifacts.require('MatryxCommit')
const IMatryxCommit = artifacts.require('IMatryxCommit')
const IMatryxRound = artifacts.require('IMatryxRound')

let platform, commit, tournament

contract('MatryxCommit', async () => {
  let t //tournament
  let r //round
  let s //submission

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
    tournament = await createTournament('tournament', toWei(100), roundData, 0)
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

  it('Able to get submission details', async () => {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 45,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(6), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    
    sHash = await createSubmission(t, '0x00', false, 1)

    s = await r.getSubmission(sHash)
    
    assert.isTrue(bts(s.title).includes("A submission"), "Submission title incorrect")
    assert.isTrue(bts(s.descHash).includes("Qm"), "Incorrect description hash")
  })

  it('Able to create commit with parent for a tournament', async () => {
    const group = genId(5)
    const parentHash = await initCommit(stb(genId(32), 2), toWei(1), group, 1)

    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 60,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(6), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    
    const commitHash = await createSubmission(t, parentHash, true, 1)
    
    const commitChild = (await commitChildren(parentHash))[0]
    assert.equal(commitChild, commitHash, 'Child commit should be same as what was submitted')
  })

  it('Correct winning submission rewards on round', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 45,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(6), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    // create first submission
    s1 = await createSubmission(t, '0x00', false, 1)
    // create a second submission off of it from another account
    s2 = await createSubmission(t, '0x00', false, 2)

    submissions = [s1, s2]

    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)
    let s1Reward = await platform.getCommitBalance(s1).then(fromWei)
    let s2Reward = await platform.getCommitBalance(s2).then(fromWei)

    assert.equal(s1Reward, 3, "Submission 1 reward doesn't match reward distribution")
    assert.equal(s2Reward, 3, "Submission 2 reward doesn't match reward distribution")
  })

  it('Correct user balances for winning submissions with a common parent', async function() {
    roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 45,
      review: 60,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(6), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, IMatryxRound, 0)
    // initial parent commit
    commit.accountNumber = 1
    const parentContent = stb(genId(32), 2)
    const groupName = 'multiple winner group'
    let p = await initCommit(parentContent, toWei(4), groupName, 0)
    // create submission off of it
    await addToGroup(0, groupName, accounts[1])
    
    s1 = await createSubmission(t, p, true, 1)
    // create a second submission off of it from another account
    await addToGroup(0, groupName, accounts[2])
    
    s2 = await createSubmission(t, p, true, 2)

    submissions = [s1, s2]

    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0], 2)

    await commit.distributeReward(s1)
    await commit.distributeReward(s2)

    let user0Bal = await platform.getBalanceOf(accounts[0]).then(fromWei)
    let user1Bal= await platform.getBalanceOf(accounts[1]).then(fromWei)
    let user2Bal = await platform.getBalanceOf(accounts[2]).then(fromWei)

    assert.equal(user0Bal, 4, "Parent commit balance does not match reward distribution")
    assert.equal(user1Bal, 1, "Submission 1 payout doesn't match reward distribution")
    assert.equal(user2Bal, 1, "Submission 2 payout doesn't match reward distribution")
  })

  it('Able to withdraw reward from commit with height less than commit chain max length', async () => {
    // create conga line of commits from account 1
    const group = genId(5)
    let commitHash = await initCommit(stb(genId(32), 2), toWei(1), group, 1)

    // first 20 from account 1
    let congaLine = await commitCongaLine(commitHash, 4, 1)
    let lastCommit = congaLine[congaLine.length - 1]

    await addToGroup(1, group, network.accounts[2])
    
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

    // first 15 from account 1
    let congaLine = await commitCongaLine(commitHash, 14, 1)
    let lastCommit = congaLine[congaLine.length - 1]

    await addToGroup(1, group, network.accounts[2])
    
    // next 10 from account 2
    congaLine = await commitCongaLine(lastCommit, 10, 2)
    lastCommit = congaLine[congaLine.length - 1]

    // create a tournament from account 0
    const roundData = {
      start: Math.floor(Date.now() / 1000),
      end: Math.floor(Date.now() / 1000) + 40,
      review: 60,
      bounty: toWei(100)
    }
    tournament = await createTournament('tournament', toWei(100), roundData, 0)
    
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