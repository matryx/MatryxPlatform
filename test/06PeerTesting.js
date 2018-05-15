var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxToken = artifacts.require("MatryxToken");
let SubmissionTrust = artifacts.require("SubmissionTrust");
let MatryxPeer = artifacts.require("MatryxPeer");
let MatryxSubmission = artifacts.require("MatryxSubmission");

contract('ReputationTesting', function(accounts)
{
	  let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let submissionZero;
    let submissionOne;
    let submissionZeroAddress;
    let submissionZeroBlocktime;
    let token;
    let peerZero;
    let peerZeroAddress;
    let gasEstimate = 30000000;

	it("Submission is owned by peer.", async function() {
    web3.eth.defaultAccount = web3.eth.accounts[0];
		  //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

      //get gas estimate for creating peers
      // gasEstimate = await platform.createPeer.estimateGas();

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[4]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[5]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[6]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[7]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[8]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[9]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      // gasEstimate = await token.releaseTokenTransfer.estimateGas();

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.mint(web3.eth.accounts[4], 2*10**18)
      await token.mint(web3.eth.accounts[5], 2*10**18)
      await token.mint(web3.eth.accounts[6], 2*10**18)
      await token.mint(web3.eth.accounts[7], 2*10**18)
      await token.mint(web3.eth.accounts[8], 2*10**18)
      await token.mint(web3.eth.accounts[9], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      // gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

      // create a tournament
      createTournamentTransaction = await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {gas: gasEstimate});
      tournamentCreatedEvent = platform.TournamentCreated();

      tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
        tournamentCreatedEvent.get((err, res) => {
            if (err) {
                reject(err);
            } else {
                resolve(res);
            }
        }))
      var tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

      //get tournament address
      tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
      // create tournament from address
      tournament = await MatryxTournament.at(tournamentAddress);

      //get gas estimate for opening tournament
      // gasEstimate = await tournament.openTournament.estimateGas();
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

      //open tournament
      let tournamentOpen = await tournament.openTournament({gas: gasEstimate});

      //get gas estimate for entering tournament
      // gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);

      //enter tournament
      let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

      //create and start round
      let roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //get gas estimate for starting round
      // gasEstimate = await tournament.startRound.estimateGas(10, 10);

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

      //open round
      let roundOpen = await round.isOpen();

      // //get gas estimate for creating submission
      // gasEstimate = await tournament.createSubmission.estimateGas("submission0", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"]);
      // //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

      //create submission
      submissionZero = await tournament.createSubmission("submission0", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
      submissionZeroAddress = submissionZero.logs[0].args._submissionAddress;

      //get peer address
      peerZeroAddress = await platform.peerAddress(accounts[0]);

		  //peer exists and owns the submission
		  let peerOwnsSubmission = await platform.peerExistsAndOwnsSubmission(peerZeroAddress, submissionZeroAddress);
		  assert.isTrue(peerOwnsSubmission, "The peer does not own this submission");
    });

    //Testing reputation system
    it("First peer's trust is less than 1", async function() {
      var peerZero = web3.eth.contract(MatryxPeer.abi).at(peerZeroAddress);
      let reputationZero = await peerZero.getReputation();
      let isValid = reputationZero < 1*10**18;
      assert.isTrue(isValid, "The first peer's reputation was not less than 1.");
    })

    it("Original trust decreases with each additional peer", async function() {
      //get reputation of all 9 accounts
      var peerZero = web3.eth.contract(MatryxPeer.abi).at(peerZeroAddress);
      let reputationZero = await peerZero.getReputation();

      peerOneAddress = await platform.peerAddress(accounts[1]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      let reputationOne = await peerOne.getReputation();

      peerTwoAddress = await platform.peerAddress(accounts[2]);
      var peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);
      let reputationTwo = await peerTwo.getReputation();

      peerThreeAddress = await platform.peerAddress(accounts[3]);
      var peerThree = web3.eth.contract(MatryxPeer.abi).at(peerThreeAddress);
      let reputationThree = await peerThree.getReputation();

      peerFourAddress = await platform.peerAddress(accounts[4]);
      var peerFour = web3.eth.contract(MatryxPeer.abi).at(peerFourAddress);
      let reputationFour = await peerFour.getReputation();

      peerFiveAddress = await platform.peerAddress(accounts[5]);
      var peerFive = web3.eth.contract(MatryxPeer.abi).at(peerFiveAddress);
      let reputationFive = await peerFive.getReputation();

      peerSixAddress = await platform.peerAddress(accounts[6]);
      var peerSix = web3.eth.contract(MatryxPeer.abi).at(peerSixAddress);
      let reputationSix = await peerSix.getReputation();

      peerSevenAddress = await platform.peerAddress(accounts[7]);
      var peerSeven = web3.eth.contract(MatryxPeer.abi).at(peerSevenAddress);
      let reputationSeven = await peerSeven.getReputation();

      peerEightAddress = await platform.peerAddress(accounts[8]);
      var peerEight = web3.eth.contract(MatryxPeer.abi).at(peerEightAddress);
      let reputationEight = await peerEight.getReputation();

      peerNineAddress = await platform.peerAddress(accounts[9]);
      var peerNine = web3.eth.contract(MatryxPeer.abi).at(peerNineAddress);
      let reputationNine = await peerNine.getReputation();

      let isValid = (reputationZero.toNumber() > reputationOne.toNumber()) && 
                    (reputationOne.toNumber() > reputationTwo.toNumber()) && 
                    (reputationTwo.toNumber() > reputationThree.toNumber()) &&
                    (reputationThree.toNumber() > reputationFour.toNumber()) &&
                    (reputationFour.toNumber() > reputationFive.toNumber()) &&
                    (reputationFive.toNumber() > reputationSix.toNumber()) &&
                    (reputationSix.toNumber() > reputationSeven.toNumber()) &&
                    (reputationSeven.toNumber() > reputationEight.toNumber()) &&
                    (reputationEight.toNumber() > reputationNine.toNumber());

      assert.isTrue(isValid, "Original peer trust does not decrease with each additional peer.");
    })

    it("Total trust converges to 1", async function() {
      //get reputations
      var peerZero = web3.eth.contract(MatryxPeer.abi).at(peerZeroAddress);
      let reputationZero = await peerZero.getReputation();

      peerOneAddress = await platform.peerAddress(accounts[1]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      let reputationOne = await peerOne.getReputation();

      peerTwoAddress = await platform.peerAddress(accounts[2]);
      var peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);
      let reputationTwo = await peerTwo.getReputation();

      peerThreeAddress = await platform.peerAddress(accounts[3]);
      var peerThree = web3.eth.contract(MatryxPeer.abi).at(peerThreeAddress);
      let reputationThree = await peerThree.getReputation();

      peerFourAddress = await platform.peerAddress(accounts[4]);
      var peerFour = web3.eth.contract(MatryxPeer.abi).at(peerFourAddress);
      let reputationFour = await peerFour.getReputation();

      peerFiveAddress = await platform.peerAddress(accounts[5]);
      var peerFive = web3.eth.contract(MatryxPeer.abi).at(peerFiveAddress);
      let reputationFive = await peerFive.getReputation();

      peerSixAddress = await platform.peerAddress(accounts[6]);
      var peerSix = web3.eth.contract(MatryxPeer.abi).at(peerSixAddress);
      let reputationSix = await peerSix.getReputation();

      peerSevenAddress = await platform.peerAddress(accounts[7]);
      var peerSeven = web3.eth.contract(MatryxPeer.abi).at(peerSevenAddress);
      let reputationSeven = await peerSeven.getReputation();

      peerEightAddress = await platform.peerAddress(accounts[8]);
      var peerEight = web3.eth.contract(MatryxPeer.abi).at(peerEightAddress);
      let reputationEight = await peerEight.getReputation();

      peerNineAddress = await platform.peerAddress(accounts[9]);
      var peerNine = web3.eth.contract(MatryxPeer.abi).at(peerNineAddress);
      let reputationNine = await peerNine.getReputation();

      //calculate the global reputation of the platform
      let totalReputation = reputationZero.toNumber() + reputationOne.toNumber() + reputationTwo.toNumber() + reputationThree.toNumber() +
                            reputationFour.toNumber() + reputationFive.toNumber() + reputationSix.toNumber() + reputationSeven.toNumber() +
                            reputationEight.toNumber() + reputationNine.toNumber();

      console.log(totalReputation);
      let isValid = totalReputation < 1*10**18;

      assert.isTrue(isValid, "Total trust exceeds 1.");
    })
});

contract('ReputationTesting', function(accounts)
{
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let submissionOne;
    let submissionOneAddress;
    let submissionTwo;
    let submissionTwoAddress;
    let token;
    let gasEstimate = 30000000;

    it("Able to approve a reference", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address);
      //get gas estimate for entering tournament
      // gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);
      // gasEstimate = Math.ceil(gasEstimate * 10);
      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});

      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      // gasEstimate = await token.releaseTokenTransfer.estimateGas();

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)

      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      // gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

      // create a tournament
      createTournamentTransaction = await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {gas: gasEstimate});
      tournamentCreatedEvent = platform.TournamentCreated();

      tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
        tournamentCreatedEvent.get((err, res) => {
            if (err) {
                reject(err);
            } else {
                resolve(res);
            }
        }))
      var tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

      //get tournament address
      tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
      // create tournament from address
      tournament = await MatryxTournament.at(tournamentAddress);

      //get gas estimate for opening tournament
      // gasEstimate = await tournament.openTournament.estimateGas();
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

      //open tournament
      let tournamentOpen = await tournament.openTournament({gas: gasEstimate});

      //get gas estimate for entering tournament
      // gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);

      //enter tournament
      let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      //create and start round
      let roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //get gas estimate for starting round
      // gasEstimate = await tournament.startRound.estimateGas(10, 10);

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

      //open round
      let roundOpen = await round.isOpen();

      //enter tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      // //get gas estimate for creating submission
      // gasEstimate = await tournament.createSubmission.estimateGas("submission1", accounts[1], "external address 1", ["0x0"], ["0x0"], ["0x0"]);
      // //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);

      //make a sumbission from account1
      submissionOne = await tournament.createSubmission("submission1", accounts[1], "external address 1", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionOneAddress = submissionOne.logs[0].args._submissionAddress;

      // //get gas estimate for entering tournament
      // gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);
      // gasEstimate = Math.ceil(gasEstimate * 10);

      //enter tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[2], gas: gasEstimate});

      // //get gas estimate for creating submission
      // gasEstimate = await tournament.createSubmission.estimateGas("submission2", accounts[2], "external address 2", ["0x0"], ["0x0"], ["0x0"]);
      // //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);

      //make a sumbission from account2
      submissionTwo = await tournament.createSubmission("submission2", accounts[2], "external address 2", ["0x0"], ["0x0"], ["0x0"], {from: accounts[2], gas: gasEstimate});
      submissionTwoAddress = submissionTwo.logs[0].args._submissionAddress;

      //get peers
      let peerOneAddress = await platform.peerAddress(accounts[1]);
      let peerTwoAddress = await platform.peerAddress(accounts[2]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      var peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);

      let peerOneReputationBefore = await peerOne.getReputation();
      console.log("peerOneReputationBefore " + peerOneReputationBefore);
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //peer 1 approves a reference to submission1 within submission2
      //peer 2's reputation increases
      await peerOne.approveReference(submissionTwoAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});

      let peerOneReputationAfter = await peerOne.getReputation();
      console.log("peerOneReputationAfter " + peerOneReputationAfter);
      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      assert.isTrue(peerTwoReputationAfter > peerTwoReputationBefore, "Reference was not successfully approved.");
    })

    it("Able to get approved and total reference counts", async function(){
      let peerOneAddress = await platform.peerAddress(accounts[1]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      let approvedAndTotalReferenceCounts = peerOne.getApprovedAndTotalReferenceCounts(submissionTwoAddress);
      console.log("approvedAndTotalReferenceCounts: " + approvedAndTotalReferenceCounts);
      assert.equal(approvedAndTotalReferenceCounts[0], 1, "Approved reference count should be 1.")
    });

    it("Able to get approved reference proportion", async function(){
      let peerOneAddress = await platform.peerAddress(accounts[1]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      let approvedReferenceProportion = peerOne.getApprovedReferenceProportion(submissionTwoAddress);
      console.log("approvedReferenceProportion: " + approvedReferenceProportion);
      assert.equal(approvedReferenceProportion.valueOf(), 1, "Approved reference proportion should be 1.")
    });


    it("Able to flag a missing reference", async function() {
      //get peers
      var peerOneAddress = await platform.peerAddress(accounts[1]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);

      var peerTwoAddress = await platform.peerAddress(accounts[2]);
      var peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);

      //get submissions 1 and 2
      // let mySubmissionsOne = await tournament.mySubmissions.call({from: accounts[1]});
      // let submissionOne = await MatryxSubmission.at(mySubmissionsOne[0]);
      // let submissionOneAddress = submissionOne.address;

      // let mySubmissionsTwo = await tournament.mySubmissions.call({from: accounts[2]});
      // let submissionTwo = await MatryxSubmission.at(mySubmissionsTwo[0]);
      // let submissionTwoAddress = submissionTwo.address;

      let peerOneReputationBefore = await peerOne.getReputation();
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //submission 1 is missing as a reference in submission 2, so peer 1 flags submission 2
      //peer 2's reputation decreases
      let flag = await peerOne.flagMissingReference(submissionTwoAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
      console.log("flag: " + flag);

      let peerOneReputationAfter = await peerOne.getReputation();
      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      assert.isTrue(peerTwoReputationAfter < peerTwoReputationBefore, "Missing flag was not successfully added.");
    })

    it("Able to get normalized trust in peer", async function() {
      var peerOneAddress = await platform.peerAddress(accounts[1]);
      var peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      console.log("peerOne: " + peerOne);
      console.log("peerOneAddress: " + peerOneAddress);
      let peersJudged = await peerOne.peersJudged();
      console.log("peersJudged: " + peersJudged);

      let normalizedTrust = await peerOne.normalizedTrustInPeer(peerOneAddress);
      console.log("normalizedTrust: " + normalizedTrust);
      let validTrust = normalizedTrust > 0;

      assert.isTrue(validTrust, "Could not get normalized trust in peer.");
    })

});