const { shouldFail } = require('openzeppelin-test-helpers')

const { setup } = require('../truffle/utils')
const { init, createTournament } = require('./helpers')(artifacts, web3)
const { accounts } = require('../truffle/network')

let platform
let token
let snapshot

contract('Platform Testing', () => {
  let t
  let roundData = {
    start: 0,
    duration: 3600,
    review: 10,
    bounty: web3.toWei(5)
  }

  before(async () => {
    let contracts = await init()
    platform = contracts.platform
    token = contracts.token
  })

  beforeEach(async () => {
    snapshot = await network.provider.send('evm_snapshot')
    platform.accountNumber = 0
  })

  afterEach(async () => {
    await network.provider.send('evm_revert', [snapshot])
  })

  it('Able to get platform info', async () => {
    let { owner } = await platform.getInfo()
    assert.equal(owner, accounts[0], 'Unable to get platform owner')
  })

  it('Unable to set platform token from another account', async () => {
    platform.accountNumber = 2
    let tx = platform.upgradeToken(platform.address)
    await shouldFail.reverting(tx)
  })

  it('Unable to set platform owner from another account', async () => {
    platform.accountNumber = 2
    let tx = platform.transferOwnership(accounts[2])
    await shouldFail.reverting(tx)
  })

  it('Platform has 0 tournaments', async () => {
    let count = await platform.getTournamentCount()
    let tournaments = await platform.getTournaments()
    assert.isTrue(
      count == 0 && tournaments.length == 0,
      'Tournament count should be 0 and tournaments array should be empty.'
    )
  })

  it('Able to create a tournament', async () => {
    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let count = +(await platform.getTournamentCount())
    assert.isTrue(count == 1, 'Tournament count should be 1.')
  })

  it('Unable to create a tournament from account without allowance', async () => {
    try {
      await createTournament('tournament', web3.toWei(10), roundData, 1)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a tournament')
    }
  })

  it('Able to get all tournaments in platform', async () => {
    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    let ts = await platform.getTournaments()
    assert.equal(ts[0], t.address, 'Unable to get tournaments.')
  })

  it('Platform can recognize the tournament address as a tournament', async () => {
    t = await createTournament('tournament', web3.toWei(10), roundData, 0)
    isT = await platform.isTournament(t.address)
    assert.isTrue(isT, 'Should be a tournament.')
  })

  it('Able to send tokens to the platform directly', async () => {
    let bb = await token.balanceOf(platform.address).then(fromWei)
    await token.transfer(platform.address, toWei(10))
    let ba = await token.balanceOf(platform.address).then(fromWei)
    assert.equal(bb + 10, ba, 'Incorrect platform balance')
  })

  it('Unable to withdraw platform tokens from another account', async () => {
    platform.accountNumber = 2
    let tx = platform.withdrawTokens(token.address)
    await shouldFail.reverting(tx)
  })

  it('Platform owner able to withdraw unallocated tokens from platform', async () => {
    await token.transfer(platform.address, toWei(10))
    let bb = await token.balanceOf(platform.address).then(fromWei)
    await platform.withdrawTokens(token.address)
    let ba = await token.balanceOf(platform.address).then(fromWei)
    assert.equal(bb - 10, ba, 'Unable to withdraw tokens')
  })

  it('Able to blacklist a user address', async () => {
    await setup(artifacts, web3, 3, true)
    await platform.setUserBlacklisted(accounts[3], true)

    try {
      await createTournament('tournament', web3.toWei(10), roundData, 3)
      assert.fail('Expected revert not received')
    } catch (error) {
      let revertFound = error.message.search('revert') >= 0
      assert(revertFound, 'Should not have been able to make a tournament')
    }
  })

  it('Only the platform owner can blacklist users', async () => {
    platform.accountNumber = 1
    let tx = platform.setUserBlacklisted(accounts[2], true)
    await shouldFail.reverting(tx)
  })

  it('Able to set a new platform owner', async () => {
    await platform.transferOwnership(accounts[2])
    platform.accountNumber = 2
    await platform.acceptOwnership()
    let { owner } = await platform.getInfo()
    assert.equal(owner, accounts[2], 'Set platform owner failed')
  })
})
