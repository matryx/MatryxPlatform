// TODO - test EVERYTHING

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

    let address = await platform.allTournaments(count)
    let tournament = Contract(address, MatryxTournament, accountNumber)

    return tournament
  }

const waitUntilInReview = async (round) => {
    let roundEndTime = await round.getEndTime()

    let timeTilRoundInReview = roundEndTime - Date.now() / 1000
    timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

    await sleep(timeTilRoundInReview * 1000)
}

const waitUntilClose = async (round) => {
    let roundEndTime = +await round.getEndTime()
    let reviewPeriodDuration = +await round.getReviewPeriodDuration()
    let timeTilClose = Math.max(0, roundEndTime + reviewPeriodDuration - Date.now() / 1000)
    timeTilClose = timeTilClose > 0 ? timeTilClose : 0

    await sleep(timeTilClose * 1000)
}

contract('NotYetOpen Round Testing', function(accounts) {
    let t; //tournament
    let r; //round

    it("Able to create a tournament with a valid round", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000) + 60,
            end: Math.floor(Date.now() / 1000) + 120,
            reviewPeriodDuration: 60,
            bounty: web3.toWei(5),
            closed: false
          }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)

        assert.ok(r.address, "Round is not valid.");
    });

    it("Able to get platform from round", async function () {
        let p = await r.getPlatform();
        assert.equal(p.toLowerCase(), platform.address, "Unable to get platform from round.");
    });

    it("Able to get token from round", async function () {
        let token = await r.getTokenAddress();
        assert.equal(token.toLowerCase(), network.tokenAddress, "Unable to get platform from round.");
    });

    it("Able to get tournament from round", async function () {
        let tournament = await r.getTournament();
        assert.equal(tournament, t.address, "Unable to get tournament from round.");
    });

    it("Able to get round start time", async function () {
        let time = await r.getStartTime();
        assert.isTrue(time > Math.floor(Date.now() / 1000), "Unable to get start time.");
    });

    it("Able to get round end time", async function () {
        let time = await r.getEndTime();
        assert.isTrue(time > Math.floor(Date.now() / 1000), "Unable to get end time.");
    });

    it("Able to get round review period duration", async function () {
        let review = await r.getReviewPeriodDuration();
        assert.equal(review, 60, "Unable to get review period duration.");
    });

    it("Able to get round bounty", async function () {
        let b = await r.getBounty();
        assert.equal(b, web3.toWei(5), "Unable to get bounty.");
    });

    it("Remaining bounty should be the same as original bounty", async function () {
        let b = await r.getRemainingBounty();
        assert.equal(b, web3.toWei(5), "Unable to get remaining bounty.");
    });

    it("Round balance should be the same as original bounty", async function () {
        let b = await r.getRoundBalance();
        assert.equal(b, web3.toWei(5), "Unable to get remaining bounty.");
    });

    it("Round state is Not Yet Open", async function () {
      let state = await r.getState();
      assert.equal(state, 0, "Round State should be NotYetOpen");
    });

    it("Round should not have any submissions", async function () {
        let sub = await r.getSubmissions();
        assert.equal(sub.length, 0, "Round should not have submissions");
    });

    it("No submissions should have been chosen in this round", async function () {
        let sub = await r.submissionsChosen();
        assert.isFalse(sub, "Round should not have any chosen submissions");
    });

    it("Number of submissions should be zero", async function () {
        let no_sub = await r.numberOfSubmissions();
        assert.equal(no_sub.toNumber(), 0, "Number of Submissions should be Zero")
    });

    it("Add bounty to a round", async function () {
        await t.allocateMoreToRound(web3.toWei(1));
        let b = await r.getBounty();
        assert.equal(fromWei(b), 6, "Bounty was not added")
    });
});

contract('Open Round Testing', function(accounts) {
    let t; //tournament
    let r; //round

    it("Able to create a tournament with a Open round", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000),
            end: Math.floor(Date.now() / 1000) + 120,
            reviewPeriodDuration: 60,
            bounty: web3.toWei(5),
            closed: false
          }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)

        assert.ok(r.address, "Round is not valid.");
    });


    it("Round state is Open", async function () {
      let state = await r.getState();
      console.log(state);
      assert.equal(state, 2, "Round State should be Open");
    });

    it("Round should not have any submissions", async function () {
        let sub = await r.getSubmissions();
        assert.equal(sub.length, 0, "Round should not have submissions");
    });

    it("No submissions should have been chosen in this round", async function () {
        let sub = await r.submissionsChosen();
        assert.isFalse(sub, "Round should not have any chosen submissions");
    });

    it("Number of submissions should be zero", async function () {
        let no_sub = await r.numberOfSubmissions();
        assert.equal(no_sub.toNumber(), 0, "Number of Submissions should be Zero")
    });

    it("Add bounty to a round", async function () {
        await t.allocateMoreToRound(web3.toWei(1));
        let b = await r.getBounty();
        assert.equal(fromWei(b), 6, "Bounty was not added")
    });
});

// TODO - you have to make a submisison in order to go into InReview
// contract('In Review Round Testing', function(accounts) {
//     let t; //tournament
//     let r; //round

//     it("Able to create a round In Review", async function () {
//         await init();
//         roundData = {
//             start: Math.floor(Date.now() / 1000),
//             end: Math.floor(Date.now() / 1000) + 1,
//             reviewPeriodDuration: 500,
//             bounty: web3.toWei(5),
//             closed: false
//           }

//         t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)

//         let [_, roundAddress] = await t.currentRound()
//         r = Contract(roundAddress, MatryxRound, 0)
//         await waitUntilInReview(r);

//         assert.ok(r.address, "Round is not valid.");
//     });

//     it("Round state is In Review", async function () {
//         let state = await r.getState();
//         console.log(state);
//         assert.equal(state, 3, "Round State should be In Review");
//     });

// });

contract('Abandoned Round Testing', function(accounts) {
    let t; //tournament
    let r; //round

    it("Able to create an Abandoned round", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000),
            end: Math.floor(Date.now() / 1000) + 1,
            reviewPeriodDuration: 1,
            bounty: web3.toWei(5),
            closed: false
          }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)

        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)
        await waitUntilClose(r)

        assert.ok(r.address, "Round is not valid.");
    });

    it("Round state is Abandoned", async function () {
        let state = await r.getState();
        console.log(state);
        assert.equal(state, 6, "Round State should be Abandoned");
    });

    it("Unable to add bounty to Abandoned round", async function () {
        try {
            await t.allocateMoreToRound(web3.toWei(1));
               assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to add bounty to Abandoned round');
          }
    });

});
