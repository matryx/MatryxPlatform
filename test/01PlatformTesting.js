var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxToken = artifacts.require("MatryxToken");

const ethers = require('ethers')
const { setup, getMinedTx, sleep, stringToBytes32, stringToBytes, bytesToString, Contract } = require('./utils')
let platform;

const init = async () => {
    const data = await setup(artifacts, web3, 0)
    MatryxTournament = data.MatryxTournament
    MatryxRound = data.MatryxRound
    MatryxSubmission = data.MatryxSubmission
    wallet = data.wallet
    platform = data.platform
    token = data.token
  }

const createTournament = async (_title, _category, bounty, roundData, accountNumber) => {
    const { platform } = await setup(artifacts, web3, accountNumber)

    let count = +await platform.tournamentCount()

    const category = stringToBytes(_category)
    const title = stringToBytes32(_title, 3)
    const descriptionHash = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
    const fileHash = stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
    const tournamentData = {
      category,
      title,
      descriptionHash,
      fileHash,
      initialBounty: bounty,
      entryFee: web3.toWei(2)
    }

    let tx = await platform.createTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 25 })
    await getMinedTx('Platform.createTournament', tx.hash)

    const address = await platform.allTournaments(count)
    const tournament = Contract(address, MatryxTournament, accountNumber)

    return tournament

  }

contract('Platform Testing', function(accounts) {
    let t;

    it("Platform initialized correctly", async function () {
        await init();
        assert.equal(platform.address, MatryxPlatform.address, "Platform address was not set correctly.");
    });

    it("Able to get token address from platform", async function () {
        let tokenAddress = await platform.getTokenAddress()
        assert.equal(tokenAddress.toLowerCase(), network.tokenAddress, "Token address was not set correctly in platform.");
    });

    it("Platform has 0 tournaments", async function () {
        let count = await platform.tournamentCount()
        let tournaments = await platform.getTournaments()
        assert.isTrue(count == 0 && tournaments.length == 0, "Tournament count should be 0 and tournaments array should be empty.");
    });

    it("Platform has 0 categories", async function () {
        let cat = await platform.getAllCategories()
        assert.isTrue(cat.length == 0, "Platform should not contain any categories.");
    });

    it("Able to create a tournament", async function () {
        roundData = {
            start: Math.floor(Date.now() / 1000) + 60,
            end: Math.floor(Date.now() / 1000) + 120,
            reviewPeriodDuration: 60,
            bounty: web3.toWei(5),
            closed: false
          }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
        let count = +await platform.tournamentCount()
        assert.isTrue(count == 1, "Tournament count should be 1.");
    });

    it("Tournament should be mine", async function () {
        let mine = await platform.getTournament_IsMine(t.address)
        assert.isTrue(mine, "This tournament should be mine.");
    });

    it("Able to get all my tournaments", async function () {
        let myTournaments = await platform.myTournaments()
        assert.isTrue(t.address == myTournaments[0] && myTournaments.length == 1, "Unable to get all my tournaments correctly.");
    });

    it("Able to get tournament from its index", async function () {
        let tournament = await platform.getTournamentAtIndex(0)
        assert.equal(t.address, tournament, "Unable to get tournament from index.");
    });

    it("Unable to get tournament from invalid index", async function () {
        try {
            await platform.getTournamentAtIndex(-1);
               assert.fail('Expected revert not received');
          } catch (error) {
            const revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Unable to get tournament from invalid index');
          }
    });

    it("Unable to get nonexistent tournament from index", async function () {
        try {
            await platform.getTournamentAtIndex(10);
               assert.fail('Expected revert not received');
          } catch (error) {
            const revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Unable to get tournament from invalid index');
          }
    });

    it("I cannot enter my own tournament", async function () {
        try {
          await platform.enterTournament(t.address);
             assert.fail('I should not be able to enter my own tournament');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Successfully unable to enter my own tournament');
        }
    });

    it("Able to get tournaments by category", async function () {
        let cat = await t.getCategory();
        let tourCat = await platform.getTournamentsByCategory(cat)
        assert.isTrue(tourCat == t.address, "Unable to get tournaments by category.");
    });

    it("My submisisons should be empty", async function () {
        let mySubmissions = await platform.mySubmissions()
        assert.equal(mySubmissions.length, 0, "Tournament count should be 0 and tournaments array should be empty.");
    });
});
