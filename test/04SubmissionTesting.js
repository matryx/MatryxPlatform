// TODO - test EVERYTHING

var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxToken = artifacts.require("MatryxToken");
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

const createSubmission = async (tournament, accountNumber) => {
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

  const contribsAndRefs = {
    contributors: new Array(10).fill(0).map(r => genAddress()),
    contributorRewardDistribution: new Array(10).fill(1),
    references: new Array(10).fill(0).map(r => genAddress())
  }

  let tx = await tournament.createSubmission(submissionData, contribsAndRefs, { gasLimit: 8e6 })
  await getMinedTx('Tournament.createSubmission', tx.hash)

  const [_, roundAddress] = await tournament.currentRound()
  const round = Contract(roundAddress, MatryxRound)
  const submissions = await round.getSubmissions()
  const submissionAddress = submissions.pop()
  const submission = Contract(submissionAddress, MatryxSubmission, accountNumber)

  //console.log(chalk`Submission created: {green ${submission.address}}\n`)
  return submission
}

const updateSubmission = async submission => {
  const modData = {
    title: stringToBytes32('AAAAAA', 3),
    descriptionHash: stringToBytes32('BBBBBB', 2),
    fileHash: stringToBytes32('CCCCCC', 2)
  }
  let tx

  tx = await submission.updateData(modData)
  await getMinedTx('Submission.updateData', tx.hash)

  const conModData = {
    contributorsToAdd: new Array(3).fill(0).map(() => genAddress()),
    contributorRewardDistribution: new Array(3).fill(1),
    contributorsToRemove: []
  }

  tx = await submission.updateContributors(conModData)
  await getMinedTx('Submission.updateContributors', tx.hash)

  const refModData = {
    referencesToAdd: new Array(3).fill(0).map(() => genAddress()),
    referencesToRemove: []
  }

  tx = await submission.updateReferences(refModData)
  await getMinedTx('Submission.updateReferences', tx.hash)
}

const selectWinnersWhenInReview = async (tournament, accountNumber, winners, rewardDistribution, roundData, selectWinnerAction) => {
  tournament.accountNumber = accountNumber

  const [_, roundAddress] = await tournament.currentRound()
  const round = Contract(roundAddress, MatryxRound, accountNumber)
  const roundEndTime = await round.getEndTime()

  let timeTilRoundInReview = roundEndTime - Date.now() / 1000
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

  console.log(chalk`{grey [Waiting ${~~timeTilRoundInReview}s until review period]}`)
  await sleep(timeTilRoundInReview * 1000)

  const tx = await tournament.selectWinners([winners, rewardDistribution, selectWinnerAction, 0], roundData, { gasLimit: 5000000 })
  await getMinedTx('Tournament.selectWinners', tx.hash)
}

const waitUntilClose = async (tournament) => {
  const [_, roundAddress] = await tournament.currentRound();
  const round = Contract(roundAddress, MatryxRound)
  const roundEndTime = +await round.getEndTime()
  const reviewPeriodDuration = +await round.getReviewPeriodDuration()
  const timeTilClose = Math.max(0, roundEndTime + reviewPeriodDuration - Date.now() / 1000)

  console.log(chalk`{grey [Waiting ${~~timeTilClose}s until current round over]}`)
  await sleep(timeTilClose * 1000)
}

const logSubmissions = async tournament => {
  const [_, roundAddress] = await tournament.currentRound();
  console.log(chalk`Current round: {green ${roundAddress}}`)
  const round = Contract(roundAddress, MatryxRound)
  const submissions = await round.getSubmissions()
  submissions.forEach((s, i) => {
    console.log(chalk`Submission ${i + 1}: {green ${s}}`)
  })
  return submissions
}

contract('Submission Testing', function(accounts) {
  let t; //tournament
  let r; //round
  let s;
  let sub;
  let stime;

  it("Able to create a Submission", async function () {
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

      s = await createSubmission(t, 1)
      stime = Math.floor(Date.now() / 1000);
      console.log(stime)
      //console.log(s.address)
      //s = Contract(submission, MatryxSubmission, 1)
      // await updateSubmission(submission)
      // await createSubmission(tournament, 2)
      // await createSubmission(tournament, 3)  

      assert.ok(s.address, "Submission is not valid.");
  });


  it("Submission is updated", async function () {
   await updateSubmission(s)
   sub = Contract(s.address, MatryxSubmission, 1)
   let title = await sub.getTitle();
    assert.equal(bytesToString(title[0]), "AAAAAA" , "Submission Title should be Updated");
  });

  it("Get Submission Tournament", async function () {
    let ts = await sub.getTournament();
    assert.equal(ts, t.address, "Tournament Address is incorrect")
  });

  it("Get Submission Round", async function () {
    let tr = await sub.getRound();
    assert.equal(tr, r.address, "Round Address is incorrect")
  });

  //How to get the owner address 
  it("Get Submission Owner", async function () {
    let to = await sub.c.getOwner();
    let actual = web3.eth.accounts[1]
    assert.equal(to.toLowerCase(), actual.toLowerCase(), "Owner Address is incorrect")
  });

  it("Owner Submission Accessability", async function () {
    let access = await sub.isAccessible(web3.eth.accounts[1]);
    assert.isTrue(access, "Owner Address has access to submission")
  });

  it("Correct Download Permissions", async function () {
    let permitted = await sub.getPermittedDownloaders();
    assert(permitted, "Permissions are not correct")
  });

  it("Correct References", async function () {
    let ref = await sub.getReferences();
    assert(ref,"References are not correct")
  });

  it("Correct Contributors", async function () {
    let contribs = await sub.getContributors();
    assert(contribs,"References are not correct")
  });

  it("Get Time Submitted", async function () {
    let submission_time = await sub.getTimeSubmitted().then(Number);
    assert.isTrue(Math.abs(submission_time - stime) < 10, "Submission Time is not correct")
  });

  it("Get Time Updated", async function () {
    let update_time = await sub.getTimeSubmitted().then(Number);
    assert(update_time ,"Submission Time is not correct")
  });

  it("Choose Winner", async function () {
    //await waitUntilClose(t);
    let submissions = await logSubmissions(t)
    await selectWinnersWhenInReview(t, 0, submissions, submissions.map(s => 1), [0, 0, 0, 0, 0], 0)
    let winnings = await s.getTotalWinnings();
    //let winnings = await r.getState();
    console.log(winnings);
    assert(winnings, "Winner was not chosen")
  });
});