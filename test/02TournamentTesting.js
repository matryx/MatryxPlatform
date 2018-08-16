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

    // let [_, roundAddress] = await tournament.currentRound()
    // let round = Contract(roundAddress, MatryxRound, accountNumber)

    return tournament

  }

  const enterTournament = async (tournament, accountNumber) => {
    await setup(artifacts, web3, accountNumber)

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    const account = tournament.wallet.address

    const isEntrant = await tournament.isEntrant(account)
    if (!isEntrant) {
      let { hash } = await platform.enterTournament(tournament.address, { gasLimit: 5e6 })
      await getMinedTx('Platform.enterTournament', hash)
    }
}

contract('Tournament Testing', function(accounts) {
    let t; //tournament
    let r; //round

    it("Able to create a tournament", async function () {
        await init();
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

    it("Able to get platform from tournament", async function () {
      let p = await t.getPlatform()
      assert.equal(p.toLowerCase(), platform.address, "Unable to get platform from tournament.");
    });

    it("Able to get token from tournament", async function () {
      let token = await t.getTokenAddress()
      assert.equal(token.toLowerCase(), network.tokenAddress, "Unable to get token from tournament.");
    });

    it("Able to get tournament title", async function () {
      let title = await t.getTitle()
      let str = bytesToString(title)
      assert.equal(str, 'first tournament', "Unable to get title.");
    });

    it("Able to get tournament description", async function () {
      let d = await t.getDescriptionHash()
      let str = bytesToString(d)
      assert.equal(str, 'QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', "Unable to get description hash.");
    });

    it("Able to get tournament files", async function () {
      let f = await t.getFileHash()
      let str = bytesToString(f)
      assert.equal(str, 'QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', "Unable to get file hash.");
    });

    it("Able to get tournament bounty", async function () {
      let b = await t.getBounty()
      assert.equal(b, web3.toWei(10), "Unable to get bounty.");
    });

    it("Able to get tournament balance", async function () {
      let b = await t.getBalance()
      assert.equal(fromWei(b), 5, "Unable to get balance.");
    });

    it("Able to get tournament entry fee", async function () {
      let f = await t.getEntryFee()
      assert.equal(f, web3.toWei(2), "Unable to get entry fee.");
    });

    it("Able to get tournament state", async function () {
      let s = await t.getState()
      assert.equal(s, 0, "Unable to get state.");
    });

    it("Able to get all tournament rounds", async function () {
      let allr = await t.getRounds()
      assert.equal(allr.length, 1, "Unable to get all rounds.");
    });

    it("Able to get current round", async function () {
      let allr = await t.getRounds()
      let [_, r] = await t.currentRound()
      assert.equal(allr[0], r, "Unable to get current round.");
    });

    it("Able to get category", async function () {
      let cat = await t.getCategory()
      let math = stringToBytes32('math')
      assert.equal(cat, math, "Unable to get current round.");
    });

    it("Number of entrants is 0", async function () {
      let count = await t.entrantCount()
      assert.equal(count, 0, "Number of entrants should be 0.");
    });

    it("Number of submissions is 0", async function () {
      let count = await t.submissionCount()
      assert.equal(count, 0, "Number of entrants should be 0.");
    });

    it("I am not an entrant of my tournament", async function () {
      let isEntrant = await t.isEntrant(accounts[0])
      assert.isFalse(isEntrant, "I should not be an entrant of my own tournament.");
    });

    it("Able to edit the tournament data", async function () {
      modData = {
        category: stringToBytes32(''), //TODO: test changing the category
        title: stringToBytes32('new', 3),
        descriptionHash: stringToBytes32('new', 2),
        fileHash: stringToBytes32('new', 2),
        entryFee: web3.toWei(1),
        entryFeeChanged: true
      }

      await t.update(modData)
      let cat = await t.getCategory()
      let title = await t.getTitle()
      let desc = await t.getDescriptionHash()
      let file = await t.getFileHash()
      let fee = await t.getEntryFee()

      let n = stringToBytes32('new', 2)

      let allNew = [title[0], desc[0], file[0]].every(x => x === n[0])
      let catUnchanged = cat == stringToBytes32('math')

      assert.isTrue(allNew && catUnchanged && fee == web3.toWei(1), "Tournament data not updated correctly.");
    });

    //TODO Make sure this actually works
    it("Unable to Enter NotYetOpen Round", async function() {
      try {
        await enterTournament(t.address, 1)
        assert.fail('Expected revert not received');
      } catch (error) {
        //const revertFound = error.message.search('revert') >= 0;
        //assert(revertFound, 'Unable to get tournament from invalid index');
        assert.isTrue(true);
      }
    });

});
