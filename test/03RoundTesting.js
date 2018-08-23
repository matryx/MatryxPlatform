const { setup, getMinedTx, sleep, stringToBytes32, stringToBytes, bytesToString, Contract } = require('./utils')
let platform;

const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')
const genAddress = () => '0x' + new Array(40).fill(0).map(() => Math.floor(16 * Math.random()).toString(16)).join('')


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

  const createSubmission = async (tournament, contribs, accountNumber) => {
    await setup(artifacts, web3, accountNumber)

    tournament.accountNumber = accountNumber
    platform.accountNumber = accountNumber
    const account = tournament.wallet.address

    const isEntrant = await tournament.isEntrant(account)
    if (!isEntrant) {
      let { hash } = await platform.enterTournament(tournament.address, { gasLimit: 5e6 })
      await getMinedTx('Platform.enterTournament', hash)
    }

    const title = stringToBytes32('A submission ' + genId(6), 3)
    const descriptionHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
    const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

    const submissionData = {
      title,
      descriptionHash,
      fileHash,
      timeSubmitted: 0,
      timeUpdated: 0
    }

    const noContribsAndRefs = {
      contributors: new Array(0).fill(0).map(r => genAddress()),
      contributorRewardDistribution: new Array(0).fill(1),
      references: new Array(0).fill(0).map(r => genAddress())
    }

    let tx = await tournament.createSubmission(submissionData, noContribsAndRefs, { gasLimit: 8e6 })
    await getMinedTx('Tournament.createSubmission', tx.hash)

    const [_, roundAddress] = await tournament.currentRound()
    const round = Contract(roundAddress, MatryxRound)
    const submissions = await round.getSubmissions()
    const submissionAddress = submissions[submissions.length-1]
    const submission = Contract(submissionAddress, MatryxSubmission, accountNumber)

    tournament.accountNumber = 0
    platform.accountNumber = 0

    return submission
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

const selectWinnersWhenInReview = async (tournament, winners, rewardDistribution, roundData, selectWinnerAction) => {
    const [_, roundAddress] = await tournament.currentRound()
    const round = Contract(roundAddress, MatryxRound, tournament.accountNumber)
    const roundEndTime = await round.getEndTime()

    let timeTilRoundInReview = roundEndTime - Date.now() / 1000
    timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

    await sleep(timeTilRoundInReview * 1000)

    const tx = await tournament.selectWinners([winners, rewardDistribution, selectWinnerAction, 0], roundData, { gasLimit: 5000000 })
    await getMinedTx('Tournament.selectWinners', tx.hash)
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

contract('In Review Round Testing', function(accounts) {
    let t; //tournament
    let r; //round
    let s; //submission

    it("Able to create a round In Review", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000),
            end: Math.floor(Date.now() / 1000) + 10,
            reviewPeriodDuration: 60,
            bounty: web3.toWei(5),
            closed: false
            }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)

        //Create submissions
        s = await createSubmission(t, false, 1)
        s2 = await createSubmission(t, false, 2)
        await waitUntilInReview(r);

        assert.ok(r.address, "Round is not valid.");
    });

    it("Round state is In Review", async function () {
        let state = await r.getState();
        assert.equal(state, 3, "Round State should be In Review");
    });

    it("Submissions accessible to any tournament entrants when round is In Review", async function () {
        let isAccessible = await s.isAccessible(accounts[2]);
        assert.isTrue(isAccessible, "Submissions should be accessible to entrants while round is in review");
    });

    it("Submissions accessible to tournament owner when round is In Review", async function () {
        let isAccessible = await s.isAccessible(accounts[0]);
        assert.isTrue(isAccessible, "Submissions should be accessible to entrants while round is in review");
    });

    it("Submission accessible to its owner", async function () {
        let isAccessible = await s.isAccessible(accounts[1]);
        assert.isTrue(isAccessible, "Submission should be accessible to its owner");
    });

    it("Submissions are not accessible to non-entrants", async function () {
        let isAccessible = await s.isAccessible(accounts[3]);
        assert.isFalse(isAccessible, "Submission should not be accessible to non-entrant");

    });

    it("Unable to allocate more tournament bounty to a round in review", async function () {
        try {
            await t.allocateMoreToRound(web3.toWei(1));
               assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to add bounty to Abandoned round');
          }
    });

    it("Round balance should still be 5", async function () {
        let rB = await r.getRoundBalance();
        assert.equal(fromWei(rB), 5, "Incorrect round balance")
    });

    it("Unable to make submissions while the round is in review", async function () {
        const title = stringToBytes32('A submission ' + genId(6), 3)
        const descriptionHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
        const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

        const submissionData = {
        title,
        descriptionHash,
        fileHash,
        timeSubmitted: 0,
        timeUpdated: 0
        }

        //switch to accounts[1]
        t.accountNumber = 1
        try {
            let tx = await t.createSubmission(submissionData, [[],[],[]])
            assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to make a submission while In Review');
          }
    });

});

contract('Closed Round Testing', function(accounts) {
    let t; //tournament
    let r; //round
    let s; //submission

    it("Able to create a closed round", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000),
            end: Math.floor(Date.now() / 1000) + 10,
            reviewPeriodDuration: 60,
            bounty: web3.toWei(5),
            closed: false
            }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)

        //Create submissions
        s = await createSubmission(t, false, 1)

        let submissions = await r.getSubmissions()
        await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 2)

        assert.ok(s.address, "Submission is not valid.");
    });

    it("Tournament should be closed", async function () {
        let state = await t.getState();
        assert.equal(state, 3, "Tournament is not Closed")
    });

    it("Round should be closed", async function () {
        let state = await r.getState();
        assert.equal(state, 5, "Round is not Closed")
    });

    it("Submissions accessible to anyone when round is Closed", async function () {
        let isAccessible = await s.isAccessible(accounts[2]);
        assert.isTrue(isAccessible, "Submissions should be accessible to entrants while round is in review");
    });

    it("Unable to allocate more tournament bounty to a closed round", async function () {
        try {
            await t.allocateMoreToRound(web3.toWei(1));
               assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to add bounty to Closed round');
          }
    });

    it("Unable to enter closed tournament", async function () {
        try {
            t.accountNumber = 2
            await platform.enterTournament(t.address)
            assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to add bounty to Closed round');
          }
    });

    it("Unable to make submissions while the round is closed", async function () {
        const title = stringToBytes32('A submission ' + genId(6), 3)
        const descriptionHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
        const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

        const submissionData = {
        title,
        descriptionHash,
        fileHash,
        timeSubmitted: 0,
        timeUpdated: 0
        }

        //switch to accounts[1]
        t.accountNumber = 1
        try {
            let tx = await t.createSubmission(submissionData, [[],[],[]])
            assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to make a submission while In Review');
          }
    });

});


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


contract('Unfunded Round Testing', function(accounts) {
    let t; //tournament
    let r; //round
    let ur; //unfunded round
    let s; //submission

    it("Able to create an Unfunded round", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000),
            end: Math.floor(Date.now() / 1000) + 10,
            reviewPeriodDuration: 60,
            bounty: web3.toWei(10),
            closed: false
            }

        t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)

        //Create submissions
        s = await createSubmission(t, false, 1)

        let submissions = await r.getSubmissions()
        await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)
        await waitUntilClose(r)

        assert.ok(s.address, "Submission is not valid.");
    });

    it("Tournament should be Open", async function () {
        let state = await t.getState();
        assert.equal(state, 2, "Tournament is not Open")
    });

    it("Round should be Unfunded", async function () {
        let [_, roundAddress] = await t.currentRound()
        ur = Contract(roundAddress, MatryxRound, 0)
        let state = await ur.getState();
        assert.equal(state, 1, "Round is not Unfunded")
    });

    it("Balance of unfunded round is 0", async function () {
        let urB = await ur.getRoundBalance()
        assert.equal(urB, 0, "Round has funds in balance")
    });

    it("Balance of tournament is 0", async function () {
        let tB = await t.getBalance()
        assert.equal(tB, 0, "Round has funds in balance")
    });

    it("Round should not have any submissions", async function () {
        let sub = await ur.getSubmissions();
        assert.equal(sub.length, 0, "Round should not have submissions");
    });

    it("Unable to make submissions while the round is Unfunded", async function () {
        const title = stringToBytes32('A submission ' + genId(6), 3)
        const descriptionHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
        const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

        const submissionData = {
        title,
        descriptionHash,
        fileHash,
        timeSubmitted: 0,
        timeUpdated: 0
        }

        //switch to accounts[1]
        t.accountNumber = 1
        try {
            let tx = await t.createSubmission(submissionData, [[],[],[]])
            assert.fail('Expected revert not received');
          } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            assert(revertFound, 'Should not have been able to make a submission while round is Unfunded');
          }
    });

    it("Able to transfer more MTX to the tournament", async function () {
        await token.transfer(t.address, toWei(2));
        let tB = await t.getBalance()
        assert.equal(fromWei(tB), 2, "Funds not transferred");
    });

    it("Able to transfer tournament funds to the Unfunded round", async function () {
        let state = await ur.getState();
        t.accountNumber = 0
        await t.allocateMoreToRound(toWei(2));
        let urB = await ur.getRoundBalance()
        assert.equal(fromWei(urB), 2, "Funds not transferred");
    });

    it("Round should now be Open", async function () {
        let state = await ur.getState();
        assert.equal(state, 2, "Round is not Open")
    });

});


//TODO: This all works with the normal tournament & round contracts but reverts with the Julia version
contract('Ghost Round Testing', function(accounts) {
    let t; //tournament
    let r; //round
    let gr; //ghost round
    let s; //submission

    it("Able to create a ghost round", async function () {
        await init();
        roundData = {
            start: Math.floor(Date.now() / 1000),
            end: Math.floor(Date.now() / 1000) + 10,
            reviewPeriodDuration: 20,
            bounty: web3.toWei(5),
            closed: false
        }

        t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
        let [_, roundAddress] = await t.currentRound()
        r = Contract(roundAddress, MatryxRound, 0)

        //Create submissions
        s = await createSubmission(t, false, 1)

        let submissions = await r.getSubmissions()
        await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)

        assert.ok(s.address, "Submission is not valid.");
    });

    it("Tournament should be Open", async function () {
        let state = await t.getState();
        assert.equal(state, 2, "Tournament is not Open")
    });

    it("Able to get ghost round", async function () {
        let rounds = await t.getRounds();
        grAddress = rounds[rounds.length-1]
        gr = Contract(grAddress, MatryxRound, 0)
        assert.isTrue(gr.address != r.address, "Unable to get ghost round")
    });

    it("Ghost round Review Period Duration is correct", async function () {
        let rpd = await gr.getReviewPeriodDuration()
        assert.equal(rpd, 20, "New round details not updated correctly")
    });

    it("Ghost round bounty is correct", async function () {
        let grb = await gr.getBounty()
        assert.equal(fromWei(grb), 5, "New round details not updated correctly")
    });

    it("Tournament balance is correct", async function () {
        let tB = await t.getBalance()
        assert.equal(fromWei(tB), 5, "Tournament balance incorrect")
    });

    it("Ghost Round balance should be 5", async function () {
        let grB = await gr.getRoundBalance()
        assert.equal(fromWei(grB), 5, "Tournament and round balance should both be 0")
    });

    it("Able to edit ghost round, review period duration updated correctly", async function () {
        roundData = {
            start: Math.floor(Date.now() / 1000) + 60,
            end: Math.floor(Date.now() / 1000) + 80,
            reviewPeriodDuration: 40,
            bounty: web3.toWei(5),
            closed: false
        }

        await t.editGhostRound(roundData)
        let rpd = await gr.getReviewPeriodDuration()

        assert.equal(rpd.toNumber(), 40, "Review period duration not updated correctly")
    });

    it("Ghost round bounty is correct", async function () {
        let grb = await gr.getBounty()
        assert.equal(fromWei(grb), 5, "New round details not updated correctly")
    });

    it("Ghost Round balance should be 5", async function () {
        let grB = await gr.getRoundBalance()
        assert.equal(fromWei(grB), 5, "Tournament and round balance should both be 0")
    });


    // Tournament can send more funds to ghost round if round is edited
    it("Able to edit ghost round, send more MTX to the round", async function () {
        roundData = {
            start: Math.floor(Date.now() / 1000) + 200,
            end: Math.floor(Date.now() / 1000) + 220,
            reviewPeriodDuration: 40,
            bounty: web3.toWei(8),
            closed: false
        }

        await t.editGhostRound(roundData)
        let rpd = await gr.getReviewPeriodDuration()

        assert.equal(rpd, 40, "Ghost Round not updated correctly")
    });

    it("Ghost round bounty is correct", async function () {
        let grb = await gr.getBounty()
        assert.equal(fromWei(grb), 8, "Ghost round bounty not updated correctly")
    });

    it("Ghost Round balance should be 8", async function () {
        let grB = await gr.getRoundBalance()
        assert.equal(fromWei(grB), 8, "Ghost round balance incorrect")
    });

    it("Tournament balance is correct", async function () {
        let tB = await t.getBalance()
        assert.equal(fromWei(tB), 2, "Tournament balance incorrect")
    });


    // Ghost round can send funds back to tournament upon being edited
    it("Able to edit ghost round, send more MTX to the round", async function () {
        roundData = {
            start: Math.floor(Date.now() / 1000) + 300,
            end: Math.floor(Date.now() / 1000) + 320,
            reviewPeriodDuration: 40,
            bounty: web3.toWei(2),
            closed: false
        }

        await t.editGhostRound(roundData)
        let rpd = await gr.getReviewPeriodDuration()

        assert.equal(rpd, 40, "Ghost Round not updated correctly")
    });

    it("Ghost round bounty is correct", async function () {
        let grb = await gr.getBounty()
        assert.equal(fromWei(grb), 2, "New round details not updated correctly")
    });

    it("Ghost Round balance should be 5", async function () {
        let grB = await gr.getRoundBalance()
        assert.equal(fromWei(grB), 2, "Tournament and round balance should both be 0")
    });

    it("Tournament balance is correct", async function () {
        let tB = await t.getBalance()
        assert.equal(fromWei(tB), 8, "Tournament balance incorrect")
    });


});
