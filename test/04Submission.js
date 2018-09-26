let fs = require('fs')
const MatryxSystem = artifacts.require("MatryxSystem")
const MatryxPlatform = artifacts.require("MatryxPlatform")
const IMatryxPlatform = artifacts.require("IMatryxPlatform")
const IMatryxTournament = artifacts.require("IMatryxTournament")
const IMatryxRound = artifacts.require("IMatryxRound")
const IMatryxSubmission = artifacts.require("IMatryxSubmission")
const MatryxToken = artifacts.require("MatryxToken")
const LibUtils = artifacts.require('LibUtils')
const LibPlatform = artifacts.require('LibPlatform')
const LibTournament = artifacts.require('LibTournament')
const LibRound = artifacts.require('LibRound')
const LibSubmission = artifacts.require('LibSubmission')

const { setup, getMinedTx, sleep, stringToBytes32, stringToBytes, bytesToString, Contract } = require('../truffle/utils')
let platform

const init = async () => {
    const contract = Contract
    let commands = fs.readFileSync('./setup', 'utf8').split('\n')
    for (let command of commands) {
        await eval(command)
    }

    const data = await setup(artifacts, web3, 0, true)
    wallet = data.wallet
    platform = data.platform
    token = data.token
}

const createTournament = async (_title, _category, bounty, roundData, accountNumber) => {
    const { platform } = await setup(artifacts, web3, accountNumber, true)

    const category = stringToBytes(_category)
    const title = stringToBytes32(_title, 3)
    const descHash = stringToBytes32('QmWmuZsJUdRdoFJYLsDBYUzm12edfW7NTv2CzAgaboj6ke', 2)
    const fileHash = stringToBytes32('QmeNv8oumYobEWKQsu4pQJfPfdKq9fexP2nh12quGjThRT', 2)
    const tournamentData = {
      category,
      title,
      descHash,
      fileHash,
      bounty,
      entryFee: web3.toWei(2)
    }

    let tx = await platform.createTournament(tournamentData, roundData, { gasLimit: 8e6, gasPrice: 25 })
    await getMinedTx('Platform.createTournament', tx.hash)

    const address = (await platform.getTournaments(0,0)).pop()
    const tournament = Contract(address, IMatryxTournament, accountNumber)

    return tournament
}

const createSubmission = async (tournament, contribs, accountNumber) => {
  await setup(artifacts, web3, accountNumber, true)
  tAccount = tournament.accountNumber
  pAccount = platform.accountNumber

  tournament.accountNumber = accountNumber
  platform.accountNumber = accountNumber
  const account = tournament.wallet.address

  const isEntrant = await tournament.isEntrant(account)
  if (!isEntrant) {
    let { hash } = await tournament.enter({ gasLimit: 5e6 })
    await getMinedTx('Platform.enterTournament', hash)
  }

  const title = stringToBytes32('A submission ' + genId(6), 3)
  const descriptionHash = stringToBytes32('QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK', 2)
  const fileHash = stringToBytes32('QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g', 2)

  const submissionData = {
    title,
    descHash,
    fileHash
  }

  const noContribsAndRefs = {
    contributors: new Array(0).fill(0).map(r => genAddress()),
    distribution: new Array(1).fill(1),
    references: new Array(0).fill(0).map(r => genAddress())
  }

  const contribsAndRefs = {
    contributors: new Array(10).fill(0).map(r => genAddress()),
    distribution: new Array(11).fill(1),
    references: new Array(10).fill(0).map(r => genAddress())
  }

  if (contribs) {
    let tx = await tournament.createSubmission({...submissionData, ...contribsAndRefs}, { gasLimit: 8e6 })
    await getMinedTx('Tournament.createSubmission', tx.hash)
  }
  else {
    let tx = await tournament.createSubmission({...submissionData, ...noContribsAndRefs}, { gasLimit: 8e6 })
    await getMinedTx('Tournament.createSubmission', tx.hash)
  }

  const [_, roundAddress] = await tournament.getCurrentRound()
  const round = Contract(roundAddress, IMatryxRound)
  const submissions = await round.getSubmissions(0, 0)
  const submissionAddress = submissions[submissions.length-1]
  const submission = Contract(submissionAddress, IMatryxSubmission, accountNumber)

  tournament.accountNumber = tAccount
  platform.accountNumber = pAccount

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

const waitUntilInReview = async (round) => {
  let roundEndTime = await round.getEnd()

  let timeTilRoundInReview = roundEndTime - Date.now() / 1000
  timeTilRoundInReview = timeTilRoundInReview > 0 ? timeTilRoundInReview : 0

  await sleep(timeTilRoundInReview * 1000)
}

contract('Submission Testing with No Contributors and References', function(accounts) {
  let t //tournament
  let r //round
  let s //submission
  let stime //time at submission creation
  let utime //time at submission updating

  it("Able to create a Submission", async function () {
      await init()
      roundData = {
          start: Math.floor(Date.now() / 1000),
          end: Math.floor(Date.now() / 1000) + 10,
          reviewPeriodDuration: 60,
          bounty: web3.toWei(5),
          closed: false
        }

      t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
      let [_, roundAddress] = await t.getCurrentRound()
      r = Contract(roundAddress, IMatryxRound, 0)

      //Create submission with no contributors
      s = await createSubmission(t, false, 1)
      s = await createSubmission(t, false, 2)
      stime = Math.floor(Date.now() / 1000)
      utime = Math.floor(Date.now() / 1000)
      s = Contract(s.address, IatryxSubmission, 1)

      assert.ok(s.address, "Submission is not valid.")
  })

  it("Submission should exist in round", async function () {
    let exists = await r.submissionExists(s.address)
    assert.isTrue(exists, "Submission does not exist in round")
  })

  it("Non-submission address does not exist as a submission in round", async function () {
    let exists = await r.submissionExists(r.address)
    assert.isFalse(exists, "This address should not exist as a submission in round")
  })

  it("Submission is accessible to submission owner", async function () {
    let access = await s.isAccessible(web3.eth.accounts[1])
    assert.isTrue(access, "Submission was not accessible to submission owner")
  })

  it("Only Submission Owner and Tournament Owner have Download Permissions", async function () {
    let permitted = await s.getPermittedDownloaders()
    let tOwner = await t.getOwner()
    let sOwner = await s.getOwner()

    let allTrue = permitted.some(x => x == tOwner) && permitted.some(x => x == sOwner)

    assert.isTrue(allTrue && permitted.length == 2, "Permissions are not correct")
  })

  it("Submission has no References", async function () {
    let ref = await s.getReferences()
    assert.equal(ref.length, 0,"References are not correct")
  })

  it("Submission has no Contributors", async function () {
    let contribs = await s.getContributors()
    assert.equal(contribs.length, 0 ,"References are not correct")
  })

  it("Get Contributor Reward Distribution", async function () {
    let crd = await s.getContributorRewardDistribution()
    assert.equal(crd.length, 0, "Contributor reward distribution incorrect")
  })

  it("Get Submission Tournament", async function () {
    let ts = await s.getTournament()
    assert.equal(ts, t.address, "Tournament Address is incorrect")
  })

  it("Get Submission Round", async function () {
    let tr = await s.getRound()
    assert.equal(tr, r.address, "Round Address is incorrect")
  })

  it("Get Submission Owner", async function () {
    let to = await s.getOwner()
    let actual = web3.eth.accounts[1]
    assert.equal(to.toLowerCase(), actual.toLowerCase(), "Owner Address is incorrect")
  })

  it("Get Time Submitted", async function () {
    let submission_time = await s.getTimeSubmitted().then(Number)
    assert.isTrue(Math.abs(submission_time - stime) < 10, "Submission Time is not correct")
  })

  it("Submission title correctly updated", async function () {
    await updateSubmission(s)
    utime = Math.floor(Date.now() / 1000)
    let title = await s.getTitle()
    assert.equal(bytesToString(title[0]), "AAAAAA" , "Submission Title should be Updated")
  })

  it("Able to update contributors", async function () {
      let con = await s.getContributors()
      assert.equal(con.length, 3, "Contributors not updated correctly.")
  })

  it("Able to update references", async function () {
      let ref = await s.getReferences()
      assert.equal(ref.length, 3, "Refernces not updated correctly.")
  })

  it("Get Time Updated", async function () {
      let update_time = await s.getTimeUpdated().then(Number)
      assert.isTrue(Math.abs(update_time - utime) < 10 ,"Update Time is not correct")
  })

  it("Any Matryx entrant able to request download permissions", async function () {
      //switch to accounts[2]
      s.accountNumber = 2
      await waitUntilInReview(r)

      //unlock the files from accounts[2]
      await s.unlockFile()

      let permitted = await s.getPermittedDownloaders()
      let p2 = permitted.some(x => x.toLowerCase() == accounts[2])

      assert.isTrue(p2, "Permissions are not correct")
  })

  it("Non Matryx entrant unable to request download permissions", async function () {
      //switch to accounts[3]
      s.accountNumber = 3

      //try to unlock the files from accounts[3]
      try {
        await s.unlockFile()
          assert.fail('Expected revert not received')
      } catch (error) {
        let revertFound = error.message.search('revert') >= 0
        assert(revertFound, 'Should not have been able to add bounty to Abandoned round')
      }
  })

})

contract('Submission Testing with Contributors', function(accounts) {

  it("Able to create a Submission with Contributors and References", async function () {
    await init()
    roundData = {
        start: Math.floor(Date.now() / 1000),
        end: Math.floor(Date.now() / 1000) + 30,
        reviewPeriodDuration: 60,
        bounty: web3.toWei(5),
        closed: false
      }

    t = await createTournament('first tournament', 'math', web3.toWei(10), roundData, 0)
    let [_, roundAddress] = await t.getCurrentRound()
    r = Contract(roundAddress, MatryxRound, 0)

    //Create submission with some contributors
    s = await createSubmission(t, true, 1)
    stime = Math.floor(Date.now() / 1000)
    s = Contract(s.address, MatryxSubmission, 1)
    assert.ok(s.address, "Submission is not valid.")
  })

  it("Submission is accessible to contributors", async function () {
    let contribs = await s.getContributors()
    let c
    let accessibleToAll = true

    //Test accessibility for every contributor
    for (var i = 0 i < contribs.length i++) {
      c = contribs[i]
      let accessibleToC = await s.isAccessible(c)
      accessibleToAll = accessibleToAll && accessibleToC
    }

    assert.isTrue(accessibleToAll, "Submission was not accessible to all contributors")
  })

  it("Submission is not accessible to a reference", async function () {
    let refs = await s.getReferences()
    let accessibleToR = await s.isAccessible(refs[0])

    assert.isFalse(accessibleToR, "Submission should not have been accessible to a reference")
  })

  it("Contributors have Download Permissions", async function () {
    let permitted = await s.getPermittedDownloaders()

    //check tournament owner has download permissions
    let tOwner = await t.getOwner()
    let allTrue = permitted.some(x => x == tOwner)

    //check submission owner has download permissions
    let sOwner = await s.getOwner()
    allTrue = permitted.some(x => x == sOwner)

    let contribs = await s.getContributors()

    //check all contributors have download permissions
    for (var i = 0 i < contribs.length i++) {
      allTrue = permitted.some(x => x == contribs[i])
    }

    assert.isTrue(allTrue && (permitted.length == contribs.length + 2), "Download permissions are not correct")
  })

  it("Submission has References", async function () {
    let ref = await s.getReferences()
    assert.equal(ref.length, 10, "References are not correct")
  })

  it("Submission has Contributors", async function () {
    let contribs = await s.getContributors()
    assert.equal(contribs.length, 10, "References are not correct")
  })

  it("Get Contributor Reward Distribution", async function () {
    let crd = await s.getContributorRewardDistribution()
    assert.equal(crd.length, 10, "Contributor reward distribution incorrect")
  })


})
