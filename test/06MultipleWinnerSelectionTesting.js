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

  tAccount = tournament.accountNumber
  pAccount = platform.accountNumber

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

  const contribsAndRefs = {
    contributors: new Array(10).fill(0).map(r => genAddress()),
    contributorRewardDistribution: new Array(10).fill(1),
    references: new Array(10).fill(0).map(r => genAddress())
  }

  if (contribs) {
    let tx = await tournament.createSubmission(submissionData, contribsAndRefs, { gasLimit: 8e6 })
    await getMinedTx('Tournament.createSubmission', tx.hash)
  }
  else {
    let tx = await tournament.createSubmission(submissionData, noContribsAndRefs, { gasLimit: 8e6 })
    await getMinedTx('Tournament.createSubmission', tx.hash)
  }

  const [_, roundAddress] = await tournament.currentRound()
  const round = Contract(roundAddress, MatryxRound)
  const submissions = await round.getSubmissions()
  const submissionAddress = submissions[submissions.length-1]
  const submission = Contract(submissionAddress, MatryxSubmission, accountNumber)

  tournament.accountNumber = tAccount
  platform.accountNumber = pAccount


  return submission
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

/*
 * Case 1
 */
contract('Multiple Winning Submissions with No Contribs or Refs and Close Tournament', function(accounts) {
    let t; //tournament
    let r; //round
    let s1; //submission 1
    let s2; //submission 2
    let s3; //submission 3
    let s4; //submission 4

  it("Able to create Multiple Submissions with no Contributors and References", async function () {
      await init();
      roundData = {
          start: Math.floor(Date.now() / 1000),
          end: Math.floor(Date.now() / 1000) + 30,
          reviewPeriodDuration: 60,
          bounty: web3.toWei(5),
          closed: false
        }

      t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
      let [_, roundAddress] = await t.currentRound()
      r = Contract(roundAddress, MatryxRound, 0)

      //Create submissions with no contributors
      s1 = await createSubmission(t, false, 1)
      s2 = await createSubmission(t, false, 2)
      s3 = await createSubmission(t, false, 3)
      s4 = await createSubmission(t, false, 4)

      assert.ok(s1.address, "Submission 1 is not valid.");
      assert.ok(s2.address, "Submission 2 is not valid.");
      assert.ok(s3.address, "Submission 3 is not valid.");
      assert.ok(s4.address, "Submission 4 is not valid.");
  });

  it("Able to choose multiple winners and close tournament", async function () {
      let submissions = await r.getSubmissions()
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 2)

      let r1 = await s1.myReward();
      let r2 = await s2.myReward();
      let r3 = await s3.myReward();
      let r4 = await s4.myReward();

      let allEqual = [fromWei(r1), fromWei(r2), fromWei(r3), fromWei(r4)].every(x => x === (10/4))
      assert.isTrue(allEqual, "Bounty not distributed correctly among all winning submissions.")
  });

  it("Tournament should be closed", async function () {
      let state = await t.getState();
      assert.equal(state, 3, "Tournament is not Closed")
  });

  it("Round should be closed", async function () {
      let state = await r.getState();
      assert.equal(state, 5, "Round is not Closed")
  });

  it("Tournament and Round balance should now be 0", async function () {
      let tB = await t.getBalance()
      let rB = await r.getRoundBalance()
      assert.isTrue(fromWei(tB) == 0 && fromWei(rB) == 0, "Tournament and round balance should both be 0")
  });

});

/*
 * Case 2
 */
contract('Multiple Winning Submissions with Contribs and Refs and Close Tournament', function(accounts) {
  let t; //tournament
  let r; //round
  let s1; //submission 1
  let s2; //submission 2
  let s3; //submission 3
  let s4; //submission 4

  it("Able to create Multiple Submissions with Contributors and References", async function () {
    await init();
    roundData = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 30,
        reviewPeriodDuration: 60,
        bounty: web3.toWei(5),
        closed: false
      }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.currentRound()
    r = Contract(roundAddress, MatryxRound, 0)

    //Create submission with some contributors
    s1 = await createSubmission(t, true, 1)
    s2 = await createSubmission(t, true, 2)
    s3 = await createSubmission(t, true, 3)
    s4 = await createSubmission(t, true, 4)

    //add accounts[3] as a new contributor to the first submission
    let modCon = {
      contributorsToAdd: [accounts[3]],
      contributorRewardDistribution: [1],
      contributorsToRemove: []
    }
    await s1.updateContributors(modCon);

    assert.ok(s1.address, "Submission 1 is not valid.");
    assert.ok(s2.address, "Submission 2 is not valid.");
    assert.ok(s3.address, "Submission 3 is not valid.");
    assert.ok(s4.address, "Submission 4 is not valid.");
  });

  it("Able to choose multiple winners and close tournament, winners get even share of 50% of bounty", async function () {
        let submissions = await r.getSubmissions()
        await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 2)

        let r1 = await s1.myReward();
        let r2 = await s2.myReward();
        let r3 = await s3.myReward();
        let r4 = await s4.myReward();

        let allEqual = [fromWei(r1), fromWei(r2), fromWei(r3), fromWei(r4)].every(x => x === ((10/2)/4))
        assert.isTrue(allEqual, "Bounty not distributed correctly among all winning submissions.")
    });

  it("Remaining 50% of Bounty allocation distributed correctly to contributors", async function () {
      contribs = await s1.getContributors()
      c = contribs[contribs.length]

      //switch to accounts[3]
      s1.accountNumber = 3
      let myReward = await s1.myReward()
      //switch back to accounts[1]
      s1.accountNumber = 1
      assert.isTrue(fromWei(myReward) == (((10/4)/2)/contribs.length), "Contributor bounty allocation incorrect")
  });

  it("Tournament should be closed", async function () {
      let state = await t.getState();
      assert.equal(state, 3, "Tournament is not Closed")
  });

  it("Round should be closed", async function () {
      let state = await r.getState();
      assert.equal(state, 5, "Round is not Closed")
  });

  it("Tournament and Round balance should now be 0", async function () {
        let tB = await t.getBalance()
        let rB = await r.getRoundBalance()
        assert.isTrue(fromWei(tB) == 0 && fromWei(rB) == 0, "Tournament and round balance should both be 0")
    });

});


/*
 * Case 3
 */
contract('Multiple Winning Submissions with no Contribs or Refs and Start Next Round', function(accounts) {
  let t; //tournament
  let r; //round
  let s1; //submission
  let s2;
  let s3;
  let s4;

  it("Able to create Multiple Submissions with no Contributors and References", async function () {
      await init();
      roundData = {
          start: Math.floor(Date.now() / 1000),
          end: Math.floor(Date.now() / 1000) + 30,
          reviewPeriodDuration: 60,
          bounty: web3.toWei(5),
          closed: false
        }

      t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
      let [_, roundAddress] = await t.currentRound()
      r = Contract(roundAddress, MatryxRound, 0)

      //Create submission with no contributors
      s1 = await createSubmission(t, false, 1)
      s2 = await createSubmission(t, false, 2)
      s3 = await createSubmission(t, false, 3)
      s4 = await createSubmission(t, false, 4)

      assert.ok(s1.address, "Submission 1 is not valid.");
      assert.ok(s2.address, "Submission 2 is not valid.");
      assert.ok(s3.address, "Submission 3 is not valid.");
      assert.ok(s4.address, "Submission 4 is not valid.");
  });

  it("Able to choose multiple winners and start next round", async function () {
      let newRound = {
          start: Math.floor(Date.now() / 1000),
          end: Math.floor(Date.now() / 1000) + 50,
          reviewPeriodDuration: 120,
          bounty: web3.toWei(5),
          closed: false
      }

      let submissions = await r.getSubmissions()
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)
      let r1 = await s1.myReward();
      let r2 = await s2.myReward();
      let r3 = await s3.myReward();
      let r4 = await s4.myReward();
      let allEqual = [fromWei(r1), fromWei(r2), fromWei(r3), fromWei(r4)].every(x => x === (5/4))
      assert.isTrue(allEqual, "Bounty not distributed correctly among all winning submissions.")
  });

  it("Tournament should be open", async function () {
      let state = await t.getState();
      assert.equal(state, 2, "Tournament is not Open")
  });

  it("New round should be open", async function () {
      const [_, newRoundAddress] = await t.currentRound()
      nr = Contract(newRoundAddress, MatryxRound)
      let state = await nr.getState();
      assert.equal(state, 2, "Round is not Open")
  });

  it("New round details are correct", async function () {
      let rpd = await nr.getReviewPeriodDuration()
      assert.equal(rpd, 120, "New round details not updated correctly")
  });

  it("New round bounty is correct", async function () {
      let nrb = await nr.getBounty()
      assert.equal(fromWei(nrb), 5, "New round details not updated correctly")
  });

  it("1/4 of round bounty assigned to each winning submission", async function () {
      let myReward = await s1.myReward()
      assert.equal(fromWei(myReward), 5/4, "Each wininng submission should have 1/4 of the bounty")
  });

  it("Tournament balance should now be 5", async function () {
      let tB = await t.getBalance()
      assert.equal(fromWei(tB), 5, "Tournament balance should be 5")
  });

  it("Rew Round balance should be 5", async function () {
      let nrB = await nr.getRoundBalance()
      assert.equal(fromWei(nrB), 5, "New round balance should be 5")
  });

    it("First Round balance should now be 0", async function () {
        r.accountNumber = 0
        let rB = await r.getRoundBalance()
        assert.isTrue(fromWei(rB) == 0, "Round balance should be 0")
    });

    it("Able to make a submission to the new round", async function () {
        let s2 = await createSubmission(t, false, 1)
        s2 = Contract(s2.address, MatryxSubmission, 1)
        assert.ok(s2.address, "Submission is not valid.");
    });

});


/*
 * Case 4
 */
contract('Multiple Winning Submissions with Contribs and Refs and Start Next Round', function(accounts) {
  let t; //tournament
  let r; //round
  let s1; //submission
  let s2;
  let s3;
  let s4;

  it("Able to create Multiple Submissions with Contributors and References", async function () {
    await init();
    roundData = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 30,
        reviewPeriodDuration: 60,
        bounty: web3.toWei(5),
        closed: false
      }

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.currentRound()
    r = Contract(roundAddress, MatryxRound, 0)

    //Create submission with some contributors
    s1 = await createSubmission(t, true, 1)
    s2 = await createSubmission(t, true, 2)
    s3 = await createSubmission(t, true, 3)
    s4 = await createSubmission(t, true, 4)

    //add accounts[3] as a new contributor to the first submission
    let modCon = {
      contributorsToAdd: [accounts[3]],
      contributorRewardDistribution: [1],
      contributorsToRemove: []
    }
    await s1.updateContributors(modCon);

    assert.ok(s1.address, "Submission 1 is not valid.");
    assert.ok(s2.address, "Submission 2 is not valid.");
    assert.ok(s3.address, "Submission 3 is not valid.");
    assert.ok(s4.address, "Submission 4 is not valid.");
  });

  it("Able to choose multiple winners and start next round, winners get correct bounty allocation", async function () {
    let newRound = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 50,
        reviewPeriodDuration: 120,
        bounty: web3.toWei(5),
        closed: false
    }

    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), newRound, 1)

    let r1 = await s1.myReward();
    let r2 = await s2.myReward();
    let r3 = await s3.myReward();
    let r4 = await s4.myReward();

    let allEqual = [fromWei(r1), fromWei(r2), fromWei(r3), fromWei(r4)].every(x => x === ((5/2)/4))
    assert.isTrue(allEqual, "Bounty not distributed correctly among all winning submissions.")
  });

  it("Remaining 50% of Bounty allocation distributed correctly to contributors", async function () {
      contribs = await s1.getContributors()
      c = contribs[contribs.length]

      //switch to accounts[3]
      s1.accountNumber = 3
      let myReward = await s1.myReward()
      //switch back to accounts[1]
      s1.accountNumber = 1
      assert.isTrue(fromWei(myReward) == (((5/2)/4)/contribs.length), "Winnings should equal initial round bounty")
  });

  it("Tournament should be open", async function () {
      let state = await t.getState();
      assert.equal(state, 2, "Tournament is not Open")
  });

  it("New round should be open", async function () {
      const [_, newRoundAddress] = await t.currentRound()
      nr = Contract(newRoundAddress, MatryxRound)
      let state = await nr.getState();
      assert.equal(state, 2, "Round is not Open")
  });

  it("New round details are correct", async function () {
      let rpd = await nr.getReviewPeriodDuration()
      assert.equal(rpd, 120, "New round details not updated correctly")
  });

  it("New round bounty is correct", async function () {
      let nrb = await nr.getBounty()
      assert.equal(fromWei(nrb), 5, "New round details not updated correctly")
  });

  it("Tournament balance should now be 5", async function () {
      let tB = await t.getBalance()
      assert.equal(fromWei(tB), 5, "Tournament and round balance should both be 0")
  });

  it("Rew Round balance should be 5", async function () {
      let nrB = await nr.getRoundBalance()
      assert.equal(fromWei(nrB), 5, "Tournament and round balance should both be 0")
  });

  it("First Round balance should now be 0", async function () {
        r.accountNumber = 0
        let rB = await r.getRoundBalance()
        assert.isTrue(fromWei(rB) == 0, "Round balance should be 0")
    });

  it("Able to make a submission to the new round", async function () {
      let s2 = await createSubmission(t, false, 1)
      s2 = Contract(s2.address, MatryxSubmission, 1)
      assert.ok(s2.address, "Submission is not valid.");
  });

});


/*
 * Case 5
 */
contract('Multiple Winning Submissions with no Contribs or Refs and Do Nothing', function(accounts) {
  let t; //tournament
  let r; //round
  let s1; //submission
  let s2;
  let s3;
  let s4;

  it("Able to create Multiple Submissions with no Contributors and References", async function () {
      await init();
      roundData = {
          start: Math.floor(Date.now() / 1000),
          end: Math.floor(Date.now() / 1000) + 30,
          reviewPeriodDuration: 60,
          bounty: web3.toWei(5),
          closed: false
        }

      t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
      let [_, roundAddress] = await t.currentRound()
      r = Contract(roundAddress, MatryxRound, 0)

      //Create submission with no contributors
      s1 = await createSubmission(t, false, 1)
      s2 = await createSubmission(t, false, 2)
      s3 = await createSubmission(t, false, 3)
      s4 = await createSubmission(t, false, 4)

      assert.ok(s1.address, "Submission 1 is not valid.");
      assert.ok(s2.address, "Submission 2 is not valid.");
      assert.ok(s3.address, "Submission 3 is not valid.");
      assert.ok(s4.address, "Submission 4 is not valid.");
  });

  it("Able to choose multiple winners and do nothing", async function () {
      let submissions = await r.getSubmissions()
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)

      let r1 = await s1.myReward();
      let r2 = await s2.myReward();
      let r3 = await s3.myReward();
      let r4 = await s4.myReward();
      let allEqual = [fromWei(r1), fromWei(r2), fromWei(r3), fromWei(r4)].every(x => x === (5/4))

      assert.isTrue(allEqual, "Bounty not distributed correctly among all winning submissions.")
  });

  it("Tournament should be Open", async function () {
      let state = await t.getState();
      assert.equal(state, 2, "Tournament is not Open")
  });

  it("Round should be in State HasWinners", async function () {
      let state = await r.getState();
      assert.equal(state, 4, "Round is not in state HasWinners")
  });

  it("Each winning submission gets 1/4 of 50% of round bounty", async function () {
      let winnings = await s1.getTotalWinnings();
      assert.equal(fromWei(winnings), (5/4), "Each winning submission should get 1/4 of the round bounty")
  });

  it("Ghost round address exists", async function () {
      let rounds = await t.getRounds();
      gr = rounds[rounds.length-1]
      assert.ok(gr, "Ghost round address does not exit")
  });

  it("Ghost round Review Period Duration is correct", async function () {
      gr = Contract(gr, MatryxRound, 0)
      let grrpd = await gr.getReviewPeriodDuration()
      assert.equal((grrpd), 60, "New round details not updated correctly")
  });

  it("First Round balance should now be 0", async function () {
        r.accountNumber = 0
        let rB = await r.getRoundBalance()
        assert.isTrue(fromWei(rB) == 0, "Round balance should be 0")
    });

  it("Ghost round bounty is correct", async function () {
      let grb = await gr.getBounty()
      assert.equal(fromWei(grb), 5, "New round details not updated correctly")
  });

  it("Tournament balance should now be 5", async function () {
      let tB = await t.getBalance()
      assert.equal(fromWei(tB), 5, "Tournament and round balance should both be 0")
  });

  it("Ghost Round balance should be 5", async function () {
      let grB = await gr.getRoundBalance()
      assert.equal(fromWei(grB), 5, "Tournament and round balance should both be 0")
  });

});


/*
 * Case 6
 */
contract('Multiple Winning Submissions with Contribs and Refs and Do Nothing', function(accounts) {
  let t; //tournament
  let r; //round
  let s1; //submission
  let s2;
  let s3;
  let s4;

  it("Able to create Multiple Submissions with Contributors and References", async function () {
    await init();
    roundData = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 30,
        reviewPeriodDuration: 60,
        bounty: web3.toWei(5),
        closed: false
      }

    t = await createTournament('first tournament', 'math', web3.toWei(15), roundData, 0)
    let [_, roundAddress] = await t.currentRound()
    r = Contract(roundAddress, MatryxRound, 0)

    //Create submission with some contributors
    s1 = await createSubmission(t, true, 1)
    s2 = await createSubmission(t, true, 2)
    s3 = await createSubmission(t, true, 3)
    s4 = await createSubmission(t, true, 4)

    //add accounts[3] as a new contributor to the first submission
    let modCon = {
      contributorsToAdd: [accounts[3]],
      contributorRewardDistribution: [1],
      contributorsToRemove: []
    }
    await s1.updateContributors(modCon);

    assert.ok(s1.address, "Submission 1 is not valid.");
    assert.ok(s2.address, "Submission 2 is not valid.");
    assert.ok(s3.address, "Submission 3 is not valid.");
    assert.ok(s4.address, "Submission 4 is not valid.");
  });

  it("Able to choose multiple winners and start next round, winners get correct bounty allocation", async function () {
    let submissions = await r.getSubmissions()
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)

    let r1 = await s1.myReward();
    let r2 = await s2.myReward();
    let r3 = await s3.myReward();
    let r4 = await s4.myReward();

    let allEqual = [fromWei(r1), fromWei(r2), fromWei(r3), fromWei(r4)].every(x => x === ((5/2)/4))
    assert.isTrue(allEqual, "Bounty not distributed correctly among all winning submissions.")
  });

  it("Remaining 50% of Bounty allocation distributed correctly to contributors", async function () {
      contribs = await s1.getContributors()
      c = contribs[contribs.length]

      //switch to accounts[3]
      s1.accountNumber = 3
      let myReward = await s1.myReward()
      //switch back to accounts[1]
      s1.accountNumber = 1
      assert.isTrue(fromWei(myReward) == (((5/2)/4)/contribs.length), "Winnings should equal initial round bounty")
  });

  it("Tournament should be open", async function () {
      let state = await t.getState();
      assert.equal(state, 2, "Tournament is not Open")
  });

  it("Round state should be Has Winners", async function () {
      let state = await r.getState();
      assert.equal(state, 4, "Round is not in state HasWinners")
  });

  it("Ghost round address exists", async function () {
      let rounds = await t.getRounds();
      gr = rounds[rounds.length-1]
      assert.ok(gr, "Ghost round address does not exit")
  });

  it("Ghost round Review Period Duration is correct", async function () {
      gr = Contract(gr, MatryxRound, 0)
      let grrpd = await gr.getReviewPeriodDuration()
      assert.equal((grrpd), 60, "New round details not updated correctly")
  });

  it("Ghost round bounty is correct", async function () {
      let grb = await gr.getBounty()
      assert.equal(fromWei(grb), 5, "New round details not updated correctly")
  });

  it("Tournament balance should now be 5", async function () {
      let tB = await t.getBalance()
      assert.equal(fromWei(tB), 5, "Tournament and round balance should both be 0")
  });

  it("Ghost Round balance should be 5", async function () {
      let grB = await gr.getRoundBalance()
      assert.equal(fromWei(grB), 5, "Tournament and round balance should both be 0")
  });

  it("First Round balance should now be 0", async function () {
        r.accountNumber = 0
        let rB = await r.getRoundBalance()
        assert.isTrue(fromWei(rB) == 0, "Round balance should be 0")
    });

});