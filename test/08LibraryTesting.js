//Loading all Matryx Contracts
var MatryxPlatform = artifacts.require("MatryxPlatform");
//var MatryxTournament = artifacts.require("MatryxTournament");
//var MatryxRound = artifacts.require("MatryxRound");
var MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

//Loading Ethers and Utilities
const ethers = require('ethers')
const { setup, stringToBytes32, stringToBytes, Contract } = require('../truffle/utils')
const sleep = ms => new Promise(done => setTimeout(done, ms))

let MatryxTournament, MatryxRound, platform, token, wallet

const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')

//Initializing All Platform Components
const init = async () => {
    const data = await setup(artifacts, web3, 0)
    MatryxTournament = data.MatryxTournament
    MatryxRound = data.MatryxRound
    wallet = data.wallet
    platform = data.platform
    token = data.token
}

//Creates Tournament
const createTournament = async (bounty, roundData, accountNumber) => {
    const { platform } = await setup(artifacts, web3, accountNumber)
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

    await platform.createTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 25 })

    const address = await platform.allTournaments(count)
    const tournament = Contract(address, MatryxTournament, accountNumber)
    console.log('Tournament: ' + address)

    return tournament
}

//Creates Submissions
const createSubmission = async (tournament, accountNumber) => {
    await setup(artifacts, web3, accountNumber)

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    const account = tournament.wallet.address

    const isEntrant = await tournament.isEntrant(account)
    if (!isEntrant) await platform.enterTournament(tournament.address, { gasLimit: 5e6 })

    const descriptionHash = stringToBytes('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK')
    const fileHash = stringToBytes('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g')

    const submissionData = {
        title: 'A submission ' + genId(6),
        owner: account,
        descriptionHash,
        fileHash,
        isPublic: false
    }
    await tournament.createSubmission([], [], [], submissionData, { gasLimit: 6.5e6 })

    console.log('Submission created')
}

//Gets Submissions
const getSubmissions = async tournament => {
    const currentRoundResults = await tournament.currentRound();
    const currentRoundAddress = currentRoundResults[1];
    console.log('Current round: ' + currentRoundAddress)
    const round = Contract(currentRoundAddress, MatryxRound)
    const submissions = await round.getSubmissions()
    console.log(submissions)
    return submissions;
}

//Select Winners
const selectWinnersWhenInReview = async (tournament, accountNumber, winners, rewardDistribution, roundData, selectWinnerAction) => {
    tournament.accountNumber = accountNumber

    const currentRoundResults = await tournament.currentRound();
    const roundAddress = currentRoundResults[1];
    const round = Contract(roundAddress, MatryxRound, accountNumber)
    const roundEndTime = await round.getEndTime()

    var timeTilRoundInReview = roundEndTime - Date.now() / 1000
    timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview + 1 : 0
    await sleep(timeTilRoundInReview * 1000)

    const params = [winners, rewardDistribution, Object.values(roundData), selectWinnerAction]
    console.log(params)

    const res = await tournament.selectWinners(...params, {gasLimit: 5000000})
    return res;
}


contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;

    it("Platform Preloading", async function () {

        const data = await setup(artifacts, web3, 0)
        MatryxTournament = data.MatryxTournament
        MatryxRound = data.MatryxRound
        wallet = data.wallet
        platform = data.platform
        assert.ok(data);
        assert.ok(MatryxTournament);
        console.log("Matryx Tournament Works");
        assert.ok(MatryxRound);
        console.log("Matryx Round Works");
    });
});

/*
contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;

    it("Token Minting", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require(ethersLocal); // local ethers pull
        wallet = new ethers.Wallet(walletAddress)
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

        function stringToBytes32(text, requiredLength) {
            var data = ethers.utils.toUtf8Bytes(text);
            var l = data.length;
            var pad_length = 64 - (l * 2 % 64);
            data = ethers.utils.hexlify(data);
            data = data + "0".repeat(pad_length);
            data = data.substring(2);
            data = data.match(/.{1,64}/g);
            data = data.map(v => "0x" + v);
            while (data.length < requiredLength) {
                data.push("0x0");
            }
            return data;
        }

        platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);
        console.log("Platform Created");
        await platform.createPeer({gasLimit: 4000000})

        token = await new ethers.Contract(MatryxToken.address, MatryxToken.abi, wallet);

        await token.setReleaseAgent(wallet.address)

        console.log("SET RELEASE AGENT")
        await token.releaseTokenTransfer({gasLimit: 1000000})

        console.log("Release Token Transfer");
        await token.mint(wallet.address, "10000000000000000000000")
        await token.approve(MatryxPlatform.address, "100000000000000000000")

        console.log("Tokens released, minted and approved to platform");

        assert.ok(token);
    });
});
*/