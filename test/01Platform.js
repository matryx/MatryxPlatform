const MatryxPlatform = artifacts.require('MatryxPlatform')

const { init, createTournament, enterTournament } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform
let token

contract('Platform Testing', function() {
  let t
  let roundData = {
    start: Math.floor(Date.now() / 1000),
    end: Math.floor(Date.now() / 1000) + 200,
    review: 60,
    bounty: web3.toWei(5)
  }

  it('Platform initialized correctly', async function() {
    let contracts = await init()
    platform = contracts.platform
    token = contracts.token
    assert.equal(platform.address, MatryxPlatform.address, 'Platform address was not set correctly.')
  })

  it('Able to get platform info', async function() {
    let info = await platform.getInfo()
    assert.equal(info.owner, accounts[0], 'Unable to get platform info')
  })

  it('Unable to set platform token from another account', async function() {
    try {
      platform.accountNumber = 2
      await platform.upgradeToken(platform.address)
      assert.fail('Should not have been able to set platform token from this account')
    } catch (error) {
      platform.accountNumber = 0
      const revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Successfully unable to set platform token')
    }
  })

  it('Unable to set platform owner from another account', async function() {
    try {
      platform.accountNumber = 2
      await platform.setOwner(accounts[2])
      assert.fail('Should not have been able to set platform owner from this account')
    } catch (error) {
      platform.accountNumber = 0
      const revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Successfully unable to set platform owner')
    }
  })

  it('Platform has 0 tournaments', async function() {
    let count = await platform.getTournamentCount()
    let tournaments = await platform.getTournaments(0, 0)
    assert.isTrue(count == 0 && tournaments.length == 0, 'Tournament count should be 0 and tournaments array should be empty.')
  })

  it('Platform has 6 preloaded categories', async function() {
    let cat = await platform.getCategories(0, 0)
    assert.isTrue(cat.length == 6, 'Platform should only contain 6 categories.')
  })

  it('Able to create a tournament', async function() {
    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 1, 'Tournament count should be 1.')
  })

  it('Platform can recognize the tournament address as a tournament', async function() {
    isT = await platform.isTournament(t.address)
    assert.isTrue(isT, 'Should be a tournament.')
  })

  it('Able to get tournaments by category', async function() {
    let cat = await t.getCategory()
    let tourCat = await platform.getTournamentsByCategory(cat, 0, 0)
    assert.isTrue(tourCat[0] == t.address, 'Unable to get tournaments by category.')
  })

  it('Able to create a new category', async function() {
    await platform.createCategory(stb('music'))
    let cat = await platform.getCategories(0, 0)
    assert.isTrue(cat.length == 7, 'Platform should contain 7 categories.')
  })

  it('Able to create second tournament in first category', async function() {
    t = await createTournament('second tournament', 'math', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 2, 'Tournament count should be 2.')
  })

  it('Able to create first tournament in second category', async function() {
    t = await createTournament('third tournament', 'science', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 3, 'Tournament count should be 3.')
  })

  it('Unable to create tournament in nonexistent category', async function() {
    try {
      await createTournament('tournament', 'not a category', web3.toWei(10), roundData, 0)
      assert.fail('I should not be able to create a tournament in nonexistent category')
    } catch (error) {
      const revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Successfully unable to create tournament in nonexistent category')
    }
  })

  it('Tournament owner cannot enter own tournament', async function() {
    try {
      await t.enter()
      assert.fail('Should not be able to enter tournament')
    } catch (error) {
      const revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Successfully unable to enter my own tournament')
    }
  })

  it('Able to enter first tournament from another account', async function() {
    await enterTournament(t, 1)
    let ent = await t.getEntrantCount()
    assert.equal(ent, 1, 'Tournament should have 1 entrant')
  })

  it('Able to get the total nubmer of users in the platform', async function() {
    let users = +await platform.getUserCount()
    assert.equal(users, 2, 'Platform should have 2 users')
  })

  it('Able to get all users in the platform', async function() {
    let users = await platform.getUsers(0, 0)
    let isTrue = users[0] == accounts[0] && users[1] == accounts[1]
    assert.isTrue(isTrue, 'Platform should have 2 users')
  })

  it('Able to send tokens to the platform directly', async function() {
    let bb = await token.balanceOf(platform.address).then(fromWei)
    await token.transfer(platform.address, toWei(10))
    let ba = await token.balanceOf(platform.address).then(fromWei)
    assert.equal(bb + 10, ba, 'Incorrect platform balance')
  })

  it('Unable to withdraw platform tokens from another account', async function() {
    try {
      platform.accountNumber = 2
      await platform.withdrawTokens(token.address)
      assert.fail('Should not have been able to withdraw tokens')
    } catch (error) {
      platform.accountNumber = 0
      const revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Successfully unable to withdraw tokens')
    }
  })

  it('Platform owner able to withdraw unallocated tokens from platform', async function() {
    let bb = await token.balanceOf(platform.address).then(fromWei)
    await platform.withdrawTokens(token.address)
    let ba = await token.balanceOf(platform.address).then(fromWei)
    assert.equal(bb - 10, ba, 'Unable to withdraw tokens')
  })

})
