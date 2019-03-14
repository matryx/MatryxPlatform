const { init, createTournament, createSubmission, selectWinnersWhenInReview } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform, commit, token

//
// Case 0
//
contract('Winner Selection Permissions', function() {
  let t
  let s
  let commitHash

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    s = await createSubmission(t, '0x00', toWei(1), 1)
  })
  
  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
  })

  it('Only the tournament owner can choose winning submissions', async () => {
    try {
      t.accountNumber = 1
      await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 2)
      assert.fail('Expected revert not received')
    } catch (error) {
      t.accountNumber = 0
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'This account should not have been able to choose winners')
    }
  })

  it('Unable to choose nonexisting submission to win the round', async () => {
    try {
      await selectWinnersWhenInReview(t, [t.address], [1], [0, 0, 0, 0], 2)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to choose nonexisting submission')
    }
  })
  
})

//
// Case 1
//
contract('Singleton Commit, Close Tournament', function() {
  let t //tournament
  let s //submission
  let commitHash

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    s = await createSubmission(t, '0x00', toWei(1), 1)
    commitHash = (await platform.getSubmission(s)).commitHash

    await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 2)
  })
  
  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    commit.accountNumber = 0
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Correct commit balance', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 10, 'Winner was not chosen')
  })

  it('Tournament should be closed', async () => {
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament is not Closed')
  })

  it('Round should be closed', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 5, 'Round is not Closed')
  })

  it('Tournament balance should now be 0', async () => {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 0, 'Tournament balance should be 0')
  })

  it('Submission owner able to withdraw reward', async () => {
    let balBefore = await token.balanceOf(accounts[1]).then(fromWei)

    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0

    let b = await commit.getBalance(commitHash).then(fromWei)
    let balAfter = await token.balanceOf(accounts[1]).then(fromWei)

    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter, balBefore + 10, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async () => {
    try {
      await commit.withdrawAvailableReward(commitHash)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

//
// Case 2
//
contract('Singleton Commit, Start Next Round', function() {
  let t  //tournament
  let s  //submission
  let commitHash

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let roundIndex = await t.getCurrentRoundIndex()

    s = await createSubmission(t, '0x00', toWei(1), 1)
    commitHash = (await platform.getSubmission(s)).commitHash

    let newRound = {
      start: 0,
      duration: 50,
      review: 120,
      bounty: web3.toWei(5)
    }

    await selectWinnersWhenInReview(t, [s], [1], newRound, 1)
  })
  
  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    commit.accountNumber = 0
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Correct commit balance', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 5, 'Winner was not chosen')
  })

  it('Tournament should be open', async () => {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('New round should be open', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)

    assert.equal(state, 2, 'Round is not Open')
  })

  it('New round details are correct', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let { review } = await t.getRoundDetails(roundIndex)

    assert.equal(review, 120, 'Incorrect new round review period')
  })

  it('New round bounty is correct', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let { bounty } = await t.getRoundDetails(roundIndex)

    assert.equal(fromWei(bounty), 5, 'Incorrect new round bounty')
  })

  it('Tournament balance should now be 5', async () => {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('Able to make a submission to the new round', async () => {
    let s2 = await createSubmission(t, '0x00', toWei(1), 1)
    assert.ok(s2, 'Unable to make submissions to the new round.')
  })

  it('Submission owner able to withdraw reward', async () => {
    let balBefore = await token.balanceOf(accounts[1]).then(fromWei)

    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0

    let b = await commit.getBalance(commitHash).then(fromWei)
    let balAfter = await token.balanceOf(accounts[1]).then(fromWei)

    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter, balBefore + 5, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async () => {
    try {
      await commit.withdrawAvailableReward(commitHash)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

// Case 3

contract('Singleton Commit, Do Nothing', function() {
  let t //tournament
  let s //submission
  let commitHash

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    s = await createSubmission(t, '0x00', toWei(1), 1)
    commitHash = (await platform.getSubmission(s)).commitHash

    await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 0)
  })
  
  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    commit.accountNumber = 0
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Correct commit balance', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 5, 'Winner was not chosen')
  })

  it('Tournament should be Open', async () => {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament is not Open')
  })

  it('Round should be in State HasWinners', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)

    assert.equal(state, 4, 'Round is not in state HasWinners')
  })

  it('Ghost round review and bounty is correct', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let { review, bounty } = await t.getRoundDetails(roundIndex + 1)

    assert.equal(review, 20, 'Incorrect ghost round Review Period Duration')
    assert.equal(fromWei(bounty), 5, 'Incorrect ghost round bounty')
  })

  it('Tournament balance should be 5', async () => {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 5, 'Tournament balance should be 5')
  })

  it('Submission owner able to withdraw reward', async () => {
    let balBefore = await token.balanceOf(accounts[1]).then(fromWei)

    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0

    let b = await commit.getBalance(commitHash).then(fromWei)
    let balAfter = await token.balanceOf(accounts[1]).then(fromWei)

    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter, balBefore + 5, 'Submission owner balance incorrect')
  })

  it('Unable to withdraw reward twice', async () => {
    try {
      await commit.withdrawAvailableReward(commitHash)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

//
// Case 4
//
contract('Singleton Commit, Do Nothing, then Close Tournament', function() {
  let t //tournament
  let s //submission
  let commitHash

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(10), roundData, 0)

    s = await createSubmission(t, '0x00', toWei(1), 1)
    commitHash = (await platform.getSubmission(s)).commitHash

    await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 0)

    await t.closeTournament()
  })

  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    commit.accountNumber = 0
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Correct commit balance', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 10, 'Winner was not chosen')
  })

  it('Able to Close the tournament after selecting winners & Do Nothing', async () => {
    let state = await t.getState()
    assert.equal(state, 3, 'Tournament should be Closed')
  })

  it('Round state should be Closed', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 5, 'Round should be Closed')
  })

  it('Tournament balance should now be 0', async () => {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 0, 'Tournament balance should be 0')
  })

  it('Correct winning submission balance', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 10, 'Incorrect commit balance')
  })

  it('Submission owner able to withdraw reward', async () => {
    let balBefore = await token.balanceOf(accounts[1]).then(fromWei)

    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0
    
    let b = await commit.getBalance(commitHash).then(fromWei)
    let balAfter = await token.balanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter - balBefore, 10, 'Submission owner balance incorrect')
  })
  
  it('Unable to withdraw reward twice', async () => {
    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)

    try {
      await commit.withdrawAvailableReward(commitHash)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })

})

//
// Case 5
//
contract('Singleton Commit, Do Nothing, then Start Next Round', function() {
  let t //tournament
  let s //submission
  let commitHash

  before(async () => {
    let data = await init()
    platform = data.platform
    commit = data.commit
    token = data.token

    roundData = {
      start: 0,
      duration: 30,
      review: 20,
      bounty: web3.toWei(5)
    }

    t = await createTournament('tournament', web3.toWei(15), roundData, 0)
    s = await createSubmission(t, '0x00', toWei(1), 1)
    commitHash = (await platform.getSubmission(s)).commitHash

    await selectWinnersWhenInReview(t, [s], [1], [0, 0, 0, 0], 0)

    await t.startNextRound()
  })
  
  beforeEach(async () => {
    snapshot = await network.provider.send("evm_snapshot", [])
    commit.accountNumber = 0
  })

  // reset
  afterEach(async () => {
    await network.provider.send("evm_revert", [snapshot])
    commit.accountNumber = 0
  })

  it('Commit balance is correct', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 5, 'Winner was not chosen')
  })

  it('New round should be open', async () => {
    let state = await t.getState()
    assert.equal(state, 2, 'Tournament should be Open')
  })

  it('Previous round should be Closed', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex - 1)
    assert.equal(state, 5, 'Initial round should be Closed')
  })

  it('New round should be Open', async () => {
    let roundIndex = await t.getCurrentRoundIndex()
    let state = await t.getRoundState(roundIndex)
    assert.equal(state, 2, 'New round should be Open')
  })
  
  it('Tournament balance should be 10', async () => {
    let tB = await t.getBalance().then(fromWei)
    assert.equal(tB, 10, 'Tournament balance should be 10')
  })
  
  it('Correct winning submission balance', async () => {
    let b = await commit.getBalance(commitHash).then(fromWei)
    assert.equal(b, 5, 'Incorrect commit balance')
  })
  
  it('Submission owner able to withdraw reward', async () => {
    let balBefore = await token.balanceOf(accounts[1]).then(fromWei)
    
    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)
    commit.accountNumber = 0
    
    let b = await commit.getBalance(commitHash).then(fromWei)
    let balAfter = await token.balanceOf(accounts[1]).then(fromWei)
    
    assert.equal(b, 0, 'Commit balance non-zero')
    assert.equal(balAfter, balBefore + 5, 'Submission owner balance incorrect')
  })
  
  it('Unable to withdraw reward twice', async () => {
    commit.accountNumber = 1
    await commit.withdrawAvailableReward(commitHash)

    try {
      await commit.withdrawAvailableReward(commitHash)
      commit.accountNumber = 0
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to withdraw reward again')
    }
  })
})
