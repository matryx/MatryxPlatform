// TODO - test EVERYTHING

const chalk = require('chalk')
const ethers = require('ethers')
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
  const submissionAddress = submissions[0]
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

contract('Single Winning Submisison with No Contribs or Refs and Close Tournament', function(accounts) {
    let t; //tournament
    let r; //round
    let s; //submission
    let tBounty; //Initial Tournament Bounty
    let rBounty;

    it("Able to create a Submission without Contributors and References", async function () {
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

        //Create submission with no contributors
        s = await createSubmission(t, false, 1)
        stime = Math.floor(Date.now() / 1000);
        utime = Math.floor(Date.now() / 1000);
        s = Contract(s.address, MatryxSubmission, 1)

        assert.ok(s.address, "Submission is not valid.");
    });

    it("Only the tournament owner can choose winning submissions", async function () {
        let submissions = await r.getSubmissions()
        const roundEndTime = await r.getEndTime()
        let timeTilRoundInReview = roundEndTime - Date.now() / 1000
        timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

        await sleep(timeTilRoundInReview * 1000)

        try {
          //make the call from accounts[1]
          t.accountNumber = 1
          await t.selectWinners([submissions, [1], 2, 0], [0, 0, 0, 0, 0], { gasLimit: 5000000 })
            assert.fail('Expected revert not received');
        } catch (error) {
            let revertFound = error.message.search('revert') >= 0;
            //set account back to tournament owner
            t.accountNumber = 0
            assert(revertFound, 'This account should not have been able to choose winners');
        }
      });


      it("Able to choose a winner without Contributors and Refs", async function () {
        tBounty = await t.getBounty()
        rBounty = await r.getBounty()
        let submissions = await r.getSubmissions()
        await selectWinnersWhenInReview(t,submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 2)
        let winnings = await s.getTotalWinnings();
        assert(winnings, "Winner was not chosen")
    });

    it("Tournament should be closed", async function () {
      let state = await t.getState();
      assert.equal(state, 3, "Tournament is not Closed")
    });

    it("Round should be closed", async function () {
      let state = await r.getState();
      assert.equal(state, 5, "Round is not Closed")
    });

    it("Total tournament + round bounty assigned to the winning submission", async function () {
        let winnings = await s.getTotalWinnings();
        assert.equal(fromWei(winnings), fromWei(tBounty), "Winnings should equal initial tournament bounty")
    });

    it("Tournament and Round balance should now be 0", async function () {
        let tB = await t.getBalance()
        let rB = await r.getRoundBalance()
        assert.isTrue(fromWei(tB) == 0 && fromWei(rB) == 0, "Tournament and round balance should both be 0")
    });
});

contract('Single Winning Submission with Contribs and Refs and Close Tournament', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

  it("Able to create a Submission with Contributors and References", async function () {
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
    s = await createSubmission(t, true, 1)
    stime = Math.floor(Date.now() / 1000);
    s = Contract(s.address, MatryxSubmission, 1)
    assert.ok(s.address, "Submission is not valid.");
  });

  it("Able to choose a winning submission with Contribs and Refs", async function () {
    let submissions = await r.getSubmissions()
    console.log(submissions)
    await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 2)
    let winnings = await s.getTotalWinnings();
    console.log(fromWei(winnings))
    assert(winnings, "Winner was not chosen")
  });

  it("bounty allocation distributed correctly to winning contributors", async function () {
      let winnings = await s.getTotalWinnings();
      submissions = await r.getSubmissions()
      contribs = await s.getContributors()
      console.log(contribs)
      c = contribs[0]
      //tokenAddress = await t.getTokenAddress();
      check = await token.balanceOf(c)
      console.log(fromWei(check))
      assert.equal(fromWei(check), 1, "Winnings should equal initial tournament bounty")
  });

  it("Tournament and Round balance should now be 0", async function () {
      let tB = await t.getBalance()
      let rB = await r.getRoundBalance()
      assert.isTrue(fromWei(tB) == 0 && fromWei(rB) == 0, "Tournament and round balance should both be 0")
  });

  it("WHY", async function () {
    assert.isTrue(true)
  });
});

contract('Single Winning Submisison with no Contribs or Refs and Start Next Round', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Single Winning Submisison with Contribs and Refs and Start Next Round', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Single Winning Submisison with no Contribs or Refs and Do Nothing', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Single Winning Submisison with Contribs and Refs and Do Nothing', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Multiple Winning Submisisons with No Contribs or Refs and Close Tournament', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

  it("Able to create a Submission with Contributors and References", async function () {
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
    s = await createSubmission(t, true, 1)
    stime = Math.floor(Date.now() / 1000);
    s = Contract(s.address, MatryxSubmission, 1)
    assert.ok(s.address, "Submission is not valid.");
  });

});

contract('Multiple Winning Submisisons with Contribs and Refs and Close Tournament', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Multiple Winning Submisisons with no Contribs or Refs and Start Next Round', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Multiple Winning Submisisons with Contribs and Refs and Start Next Round', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Multiple Winning Submisisons with no Contribs or Refs and Do Nothing', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});

contract('Multiple Winning Submisisons with Contribs and Refs and Do Nothing', function(accounts) {
  let t; //tournament
  let r; //round
  let s; //submission

});