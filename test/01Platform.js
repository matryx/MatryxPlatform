const MatryxPlatform = artifacts.require('MatryxPlatform')

const { init, createTournament } = require('./helpers')(artifacts, web3)
let platform

contract('Platform Testing', function(accounts) {
  let t
  let roundData = {
    start: Math.floor(Date.now() / 1000) + 60,
    end: Math.floor(Date.now() / 1000) + 120,
    review: 60,
    bounty: web3.toWei(5)
  }

  it('Platform initialized correctly', async function() {
    platform = (await init()).platform
    assert.equal(platform.address, MatryxPlatform.address, 'Platform address was not set correctly.')
  })

  it('Platform has 0 tournaments', async function() {
    let count = await platform.getTournamentCount()
    let tournaments = await platform.getTournaments(0, 0)
    assert.isTrue(count == 0 && tournaments.length == 0, 'Tournament count should be 0 and tournaments array should be empty.')
  })

  it('Platform has 1 preloaded category', async function() {
    let cat = await platform.getCategories(0, 0)
    assert.isTrue(cat.length == 1, 'Platform should only contain 1 category.')
  })

  it('Able to create a tournament', async function() {
    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 1, 'Tournament count should be 1.')
  })

  it('Able to get all my tournaments', async function() {
    let myTournaments = await platform.getTournamentsByUser(platform.wallet.address)
    assert.isTrue(t.address == myTournaments[0] && myTournaments.length == 1, 'Unable to get all my tournaments correctly.')
  })

  it('I cannot enter my own tournament', async function() {
    try {
      await t.enter()
      assert.fail('I should not be able to enter my own tournament')
    } catch (error) {
      const revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Successfully unable to enter my own tournament')
    }
  })

  it('Able to get tournaments by category', async function() {
    let cat = await t.getCategory()
    let tourCat = await platform.getTournamentsByCategory(cat, 0, 0)
    assert.isTrue(tourCat == t.address, 'Unable to get tournaments by category.')
  })

  it('My submissions should be empty', async function() {
    let mySubmissions = await platform.getSubmissionsByUser(platform.wallet.address)
    assert.equal(mySubmissions.length, 0, 'Tournament count should be 0 and tournaments array should be empty.')
  })

  it('Able to create a new category', async function() {
    await platform.createCategory(stb('science'))
    let cat = await platform.getCategories(0, 0)
    assert.isTrue(cat.length == 2, 'Platform should contain 2 categories.')
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

})
