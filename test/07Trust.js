const MatryxPlatform = artifacts.require('MatryxPlatform')
const MatryxUser = artifacts.require('MatryxUser')
const IMatryxUser = artifacts.require('IMatryxUser')

const { setup, Contract } = require('../truffle/utils')
const { init } = require('./helpers')(artifacts, web3)
let platform
let users
let u0
let u1
let u2

contract('Platform Testing', function(accounts) {
  it('Platform initialized correctly', async function() {
    platform = (await init()).platform
    users = Contract(MatryxUser.address, IMatryxUser)
    assert.equal(platform.address, MatryxPlatform.address, 'Platform address was not set correctly.')
  })

  it('Able to enter Matryx from 3 different accounts', async function() {
    await setup(artifacts, web3, 0, true)
    await setup(artifacts, web3, 1, true)
    await setup(artifacts, web3, 2, true)
    let u = await platform.getUserCount();
    assert.equal(u, 3, "Platform should have 3 users")
  })

  it('All users stored correctly on platform', async function() {
    let u = await platform.getUsers(0,0);
    u0 = u[0]
    u1 = u[1]
    u2 = u[2]

    let allTrue = (u0.toLowerCase() == accounts[0]) && (u1.toLowerCase() == accounts[1]) && (u2.toLowerCase() == accounts[2]);
    assert.isTrue(allTrue, "Users are incorrect")
  })

  it('All users should have an initial reputation > 0', async function() {
    let r0 = await users.getReputation(u0)
    let r1 = await users.getReputation(u1)
    let r2 = await users.getReputation(u2)
    assert.isTrue(r0 > r1 && r1 > r2 && r2 > 0, "All users should have an initial reputation > 0")
  })

  it('Able to trust another peer', async function() {
    let rBefore = await users.getReputation(u1)
    await platform.trustUser(u1)
    let rAfter = await users.getReputation(u1)
    assert.isTrue(rBefore < rAfter, "Unable to give trust correctly")
  })

  it('Able to distrust another peer', async function() {
    let rBefore = await users.getReputation(u1)
    await platform.distrustUser(u1)
    let rAfter = await users.getReputation(u1)
    assert.isTrue(rBefore > rAfter, "Unable to give distrust correctly")
  })


})
