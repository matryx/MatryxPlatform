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

    // let [_, roundAddress] = await tournament.currentRound()
    // let round = Contract(roundAddress, MatryxRound, accountNumber)

    return tournament

  }

const waitUntilClose = async (round) => {
  let roundEndTime = +await round.getEndTime()
  let reviewPeriodDuration = +await round.getReviewPeriodDuration()
  let timeTilClose = Math.max(0, roundEndTime + reviewPeriodDuration - Date.now() / 1000)
  timeTilClose = timeTilClose > 0 ? timeTilClose : 0

  await sleep(timeTilClose * 1000)
}

const waitUntilOpen = async (round) => {
  let roundStartTime = +await round.getStartTime()
  let timeTilOpen = Math.max(0, roundStartTime - Date.now() / 1000)
  timeTilOpen = timeTilOpen > 0 ? timeTilOpen : 0

  await sleep(timeTilOpen * 1000)
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


  });



contract('On Hold Tournament Testing', function(accounts) {
  let t; //tournament
  let r; //round
  let gr; //new round
  let s; //submission

  it("Able to create the tournament", async function () {
      await init();
      roundData = {
          start: Math.floor(Date.now() / 1000),
          end: Math.floor(Date.now() / 1000) + 10,
          reviewPeriodDuration: 20,
          bounty: web3.toWei(5),
          closed: false
      }

      t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
      let [_, roundAddress] = await t.currentRound()
      r = Contract(roundAddress, MatryxRound, 0)

      // Wait until open
      await waitUntilOpen(r)

      // Create submissions
      s = await createSubmission(t, false, 1)
      let submissions = await r.getSubmissions()

      // Select winners
      await selectWinnersWhenInReview(t, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)

      let rounds = await t.getRounds()
      grAddress = rounds[rounds.length-1]
      gr = Contract(grAddress, MatryxRound, 0)

      roundData = {
          start: Math.floor(Date.now() / 1000) + 60,
          end: Math.floor(Date.now() / 1000) + 80,
          reviewPeriodDuration: 40,
          bounty: web3.toWei(5),
          closed: false
      }

      await t.editGhostRound(roundData)

      await waitUntilClose(r)
      assert.ok(gr, "Unable to create tournament")
  });

  it("Tournament should be On Hold", async function () {
      let state = await t.getState();
      assert.equal(state, 1, "Tournament is not On Hold")
  });

  it("First round should be Closed", async function () {
      let state = await r.getState();
      assert.equal(state, 5, "Round is not Closed")
  });

  it("New Round should be Not Yet Open", async function () {
      let state = await gr.getState();
      assert.equal(state, 0, "Round should be Not Yet Open")
  });

  it("New should not have any submissions", async function () {
      let sub = await gr.getSubmissions();
      assert.equal(sub.length, 0, "Round should not have submissions");
  });

  it("Unable to make a submission while On Hold", async function () {
      try {
        await createSubmission(t, false, 1)
        assert.fail('Expected revert not received');
      } catch (error) {
        let revertFound = error.message.search('revert') >= 0;
        assert(revertFound, 'Should not have been able to add bounty to Abandoned round');
      }
  });

  it("Unable to enter tournament while On Hold", async function () {
      try {
        t.accountNumber = 2
        await platform.enterTournament(t.address)
        assert.fail('Expected revert not received');
      } catch (error) {
        t.accountNumber = 0
        let revertFound = error.message.search('revert') >= 0;
        assert(revertFound, 'Should not have been able to add bounty to Abandoned round');
      }
  });

  it("Tournament becomes open again after the next round starts", async function () {
      await sleep(40 * 1000)
      let state = await t.getState();
      assert.equal(state, 2, "Tournament should be open");
  });

  it("Round should be open", async function () {
      let state = await gr.getState();
      assert.equal(state, 2, "Round should be open");
  });

});
