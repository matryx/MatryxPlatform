const MatryxPlatform = artifacts.require('MatryxPlatform');

contract('MatryxPlatform', async function(accounts) {

  it("Platform Preloading", async function () {
    const ethers = require('ethers')
  const { setup, stringToBytes32, stringToBytes, Contract } = require('../truffle/utils')
  const sleep = ms => new Promise(done => setTimeout(done, ms))

  let MatryxTournament, MatryxRound, platform, token, wallet

  const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')

  const init = async () => {
    const data = await setup(artifacts, web3, 0)
    MatryxTournament = data.MatryxTournament
    MatryxRound = data.MatryxRound
    wallet = data.wallet
    platform = data.platform
    token = data.token
  }

module.exports = {
  Contract,

  stringToBytes(text) {
    let bytes = ethers.utils.toUtf8Bytes(text)
    return ethers.utils.hexlify(bytes)
  },

  stringToBytes32(text, requiredLength) {
    var data = ethers.utils.toUtf8Bytes(text)
    var l = data.length
    var pad_length = 64 - ((l * 2) % 64)
    data = ethers.utils.hexlify(data)
    data = data + '0'.repeat(pad_length)
    data = data.substring(2)
    data = data.match(/.{1,64}/g)
    data = data.map(v => '0x' + v)
    while (data.length < requiredLength) {
      data.push('0x0')
    }
    return data
  },
}

  // module.exports = async exit => {
  //   try {
  //     await init()
  //     let scOne_RoundData = {
  //         start: Math.floor(Date.now()/1000) + 1e9,
  //         end: Math.floor(Date.now()/1000) + 1e9 + 10,
  //         reviewPeriodDuration: 1,
  //         bounty: web3.toWei(5)
  //     }
  //     const tournamentOne = await createTournament(web3.toWei(10), scOne_RoundData, 0)
  //   } catch (err) {
  //     console.log(err.message)
  //   } finally {
  //     exit()
  //   }
  // }

  const createTournament = async (bounty, roundData, accountNumber) => {
    const { platform } = await setup(artifacts, web3, accountNumber)
    let platform2 = await MatryxPlatform.deployed();
    console.log("platform2 address: " + platform2.address);
  let count = +await platform.tournamentCount()

  console.log("Platform using account", platform.wallet.address)

  const suffix = ('0' + (count + 1)).substr(-2)
  const title = stringToBytes32('Test Tournament ' + suffix, 3)
  const descriptionHash = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
  const fileHash = stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
  const tournamentData = {
    category: 'math',
    title_1: title[0],
    title_2: title[1],
    title_3: title[2],
    descriptionHash_1: descriptionHash[0],
    descriptionHash_2: descriptionHash[1],
    fileHash_1: fileHash[0],
    fileHash_2: fileHash[1],
    initialBounty: bounty,
    entryFee: web3.toWei(2)
  }
//   const startTime = Math.floor(new Date() / 1000)
//   const endTime = startTime + 60
  // const roundData = {
  //   start: startTime,
  //   end: endTime,
  //   reviewPeriodDuration,
  //   bounty
  // }

    console.log("tournamentData: " + tournamentData);
    console.log("roundData: " + roundData);

    let platformTokenAddress = await platform.getTokenAddress();
    console.log("platformTokenAddress: " + platformTokenAddress);

    let myTournaments = await platform.myTournaments();
    console.log("myTournaments: " + myTournaments);

    let hasPeer = await platform.hasPeer(accounts[0]);
    console.log("hasPeer: " + hasPeer);

    await platform.createTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 21e9 })
    console.log("created a tournament!");

    let address = await platform.getTournaments();
    console.log("tournament address: " + address);
    address = address[0];

    let tournament = Contract(address[0], MatryxTournament, accountNumber)
    console.log('Tournament: ' + address)

    return tournament;
  }


    console.log("we made it inside the test yo");

    await init()
    console.log("after init");
    let scOne_RoundData = {
          start: Math.floor(Date.now()/1000) + 1e9,
          end: Math.floor(Date.now()/1000) + 1e9 + 10,
          reviewPeriodDuration: 1,
          bounty: web3.toWei(5)
      }
    let balance = +await token.balanceOf(accounts[0])
    let allowance = +await token.allowance(accounts[0], platform.address)
    console.log("balance: " + balance)
    console.log("allowance: " + allowance)
    console.log("making call to const createTournament...")
    const tournamentOne = await createTournament(web3.toWei(10), scOne_RoundData, 0)
    console.log("tournamentOne: " + tournamentOne);
    assert.ok(tournamentOne);

  });

});