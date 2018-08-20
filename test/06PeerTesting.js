var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxToken = artifacts.require("MatryxToken");
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
    //for code coverage
    let gasEstimate = 30000000;
    //for regular testing
    //let gasEstimate = 3000000;

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
    let submissionBAddress;
    let token;
    let peerOne;
    let peerTwo;
    let peerOneAddress;
    let peerTwoAddress;

    //for code coverage
    let gasEstimate = 30000000;
    //for regular testing
    //let gasEstimate = 3000000;

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
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});

      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      // gasEstimate = await token.releaseTokenTransfer.estimateGas();

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)

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
      //get my submissions
      let mySubmissions = await tournament.mySubmissions.call({from: accounts[2]});
      //get submission two
      submissionTwo = await MatryxSubmission.at(mySubmissions[0]);

      //get peers
      peerOneAddress = await platform.peerAddress(accounts[1]);
      peerTwoAddress = await platform.peerAddress(accounts[2]);
      peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);

      let peerOneReputationBefore = await peerOne.getReputation();
      console.log("peerOneReputationBefore " + peerOneReputationBefore);
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //add reference
      await submissionTwo.addReference(submissionOneAddress, {from: accounts[2], gas: gasEstimate});

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
      let approvedAndTotalReferenceCounts = peerOne.getApprovedAndTotalReferenceCounts(submissionTwoAddress, {from: accounts[1]});
      console.log("approvedAndTotalReferenceCounts: " + approvedAndTotalReferenceCounts);
      assert.equal(approvedAndTotalReferenceCounts[0], 1, "Approved reference count should be 1.")
    });

    it("Able to get approved reference proportion", async function(){
      let approvedReferenceProportion = peerTwo.getApprovedReferenceProportion(submissionOneAddress, {from: accounts[2]});
      console.log("approvedReferenceProportion: " + approvedReferenceProportion);
      assert.isTrue(approvedReferenceProportion.valueOf() == 0, "Approved reference proportion should be equal to 0.")
    });

    it("Able to get peer's influence on my reputation", async function(){
      let peersInfluenceOnMyReputation = peerTwo.getPeersInfluenceOnMyReputation(peerOneAddress, {from: accounts[2]});
      console.log("peersInfluenceOnMyReputation: " + peersInfluenceOnMyReputation);
      assert.isTrue(peersInfluenceOnMyReputation.valueOf() > 0, "Peer's influence on my reputation should be greater than zero.");
    });

    it("Able to get transfer amount after adding a reference", async function(){
      let transferAmount = await submissionOne.getTransferAmount.call();
      console.log("transferAmount 1: " + transferAmount);
      transferAmount = await submissionTwo.getTransferAmount.call({from: acconuts[2]});
      console.log("transferAmount 2: " + transferAmount);
      assert.isTrue(transferAmount > 0, "Submission's transfer amount should be greater than 0.");
    })

    it("Unable to flag a missing reference of someone with not enough reputation", async function() {
      try {
          await peerTwo.flagMissingReference(submissionOneAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Able to flag a missing reference", async function() {
      submissionA = await tournament.createSubmission("submissionA", accounts[1], "external address A", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionAAddress = submissionA.logs[0].args._submissionAddress;
      submissionB = await tournament.createSubmission("submissionB", accounts[1], "external address B", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionBAddress = submissionB.logs[0].args._submissionAddress;

      await submissionTwo.addReference(submissionAAddress, {from: accounts[2]});
      await submissionTwo.addReference(submissionBAddress, {from: accounts[2]});
      console.log("submissionTwo added all references");

      //approve 2 more references so that the unnormalized trust in peer2 from judging peer1 is significantly more than 10**18
      await peerOne.approveReference(submissionTwoAddress, submissionAAddress, {from: accounts[1], gas: gasEstimate});
      await peerOne.approveReference(submissionTwoAddress, submissionBAddress, {from: accounts[1], gas: gasEstimate});
      console.log("peer one approved all references");

      //get my submissions
      mySubmissions = await tournament.mySubmissions.call({from: accounts[1]});
      //get submission two
      submissionOne = await MatryxSubmission.at(mySubmissions[0]);

      await submissionOne.addReference(submissionTwoAddress, {from: accounts[1], gas: gasEstimate});
      console.log("submisison one added all references");

      //peer1 needs some trust before having a submisison flagged - otherwise the flagging reverts
      await peerTwo.approveReference(submissionOneAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
      console.log("peer 2 approved reference");

      let peerOneReputationBefore = await peerOne.getReputation();
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerOneReputationBefore " + peerOneReputationBefore);
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //unnormalizedTrust in peer2 from judging peer1
      let unnormalizedTrust = await peerTwo.getJudgingPeerToUnnormalizedTrust(peerOneAddress);
      console.log("unnormalizedTrust in peer2 from judging peer1: " + unnormalizedTrust.toNumber());

      unnormalizedTrust = await peerOne.getJudgingPeerToUnnormalizedTrust(peerTwoAddress);
      console.log("unnormalizedTrust in peer1 from judging peer2: " + unnormalizedTrust.toNumber());

      //submission 2 is missing as a reference in submission 1, so peer 2 flags submission 1
      //peer 1's reputation decreases
      console.log("flagging missing reference... ");
      let flag = await peerTwo.flagMissingReference(submissionAAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
      console.log("flag: " + flag);

      let peerOneReputationAfter = await peerOne.getReputation();
      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerOneReputationAfter " + peerOneReputationAfter);
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      unnormalizedTrust = await peerTwo.getJudgingPeerToUnnormalizedTrust(peerOneAddress);
      console.log("unnormalizedTrust in peer2 from judging peer1: " + unnormalizedTrust.toNumber());

      unnormalizedTrust = await peerOne.getJudgingPeerToUnnormalizedTrust(peerTwoAddress);
      console.log("unnormalizedTrust in peer1 from judging peer2: " + unnormalizedTrust.toNumber());

      assert.isTrue(peerOneReputationAfter < peerOneReputationBefore, "Missing flag was not successfully added.");
    })

    it("Able to get missing reference count", async function() {
      let missingReferenceCount = await peerTwo.getMissingReferenceCount(submissionAAddress);
      console.log("missingReferenceCount: " + missingReferenceCount[0]);

      assert.equal(missingReferenceCount[0], 1, "There should be 1 missing reference.");
    })

    it("Able to get total number of peers judged", async function() {
      let peersJudged = await peerOne.peersJudged();
      console.log("peersJudged: " + peersJudged);

      assert.equal(peersJudged, 1, "The total number of peers judged should be 1.");
    })

    it("Able to remove missing reference flag", async function() {
      let peerOneReputationBefore = await peerOne.getReputation();
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerOneReputationBefore " + peerOneReputationBefore);
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //submission 2 was missing as a reference in submission 1, so peer 2 flagged submission 1 earlier
      //now peer 2 removes the missing reference flag in submission 1
      //peer 1's reputation increases again after removing the missing reference flag
      let flag = await peerTwo.removeMissingReferenceFlag(submissionAAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
      console.log("flag: " + flag);

      let peerOneReputationAfter = await peerOne.getReputation();
      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerOneReputationAfter " + peerOneReputationAfter);
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      assert.isTrue(peerOneReputationAfter > peerOneReputationBefore, "Failed to remove missing reference flag.");
    })

    it("Able to remove reference approval", async function() {
      let peerOneReputationBefore = await peerOne.getReputation();
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerOneReputationBefore " + peerOneReputationBefore);
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      unnormalizedTrust = await peerTwo.getJudgingPeerToUnnormalizedTrust(peerOneAddress);
      console.log("unnormalizedTrust in peer2 from judging peer1: " + unnormalizedTrust.toNumber());

      unnormalizedTrust = await peerOne.getJudgingPeerToUnnormalizedTrust(peerTwoAddress);
      console.log("unnormalizedTrust in peer1 from judging peer2: " + unnormalizedTrust.toNumber());

      //peer 1 no longer approves of having submission 2 as a reference
      let flag = await peerOne.removeReferenceApproval(submissionTwoAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
      console.log("flag: " + flag);

      //peer2's reputation should decrease
      let peerOneReputationAfter = await peerOne.getReputation();
      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerOneReputationAfter " + peerOneReputationAfter);
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      unnormalizedTrust = await peerTwo.getJudgingPeerToUnnormalizedTrust(peerOneAddress);
      console.log("unnormalizedTrust in peer2 from judging peer1: " + unnormalizedTrust.toNumber());

      unnormalizedTrust = await peerOne.getJudgingPeerToUnnormalizedTrust(peerTwoAddress);
      console.log("unnormalizedTrust in peer1 from judging peer2: " + unnormalizedTrust.toNumber());

      assert.isTrue(peerTwoReputationAfter < peerTwoReputationBefore, "Failed to remove reference approval.");
    })

});

contract('ReputationTesting', function(accounts)
{
    let platform;
    let token;

    let tournamentAddress;
    let tournament;

    let submissionOne;
    let submissionOneAddress;
    let submissionTwo;
    let submissionTwoAddress;
    let submissionThree;
    let submissionThreeAddress;

    let peerOne;
    let peerTwo;
    let peerThree;
    let peerOneAddress;
    let peerTwoAddress;
    let peerThreeAddress;

    //for code coverage
    let gasEstimate = 30000000;
    //for regular testing
    //let gasEstimate = 3000000;

    it("Able to get flagged by peer who has never judged me before", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});

      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)

      await token.approve(MatryxPlatform.address, 100*10**18)

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

      //open tournament
      let tournamentOpen = await tournament.openTournament({gas: gasEstimate});

      //enter tournament
      let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      //create and start round
      let roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

      //open round
      let roundOpen = await round.isOpen();

      //accounts[1] enters tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      //make a sumbission from account1
      submissionOne = await tournament.createSubmission("submission1", accounts[1], "external address 1", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionOneAddress = submissionOne.logs[0].args._submissionAddress;

      //accounts[2] enters tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[2], gas: gasEstimate});

      //make a sumbission from account2
      submissionTwo = await tournament.createSubmission("submission2", accounts[2], "external address 2", ["0x0"], ["0x0"], ["0x0"], {from: accounts[2], gas: gasEstimate});
      submissionTwoAddress = submissionTwo.logs[0].args._submissionAddress;
      //get my submissions
      let mySubmissions = await tournament.mySubmissions.call({from: accounts[2]});
      //get submission two
      submissionTwo = await MatryxSubmission.at(mySubmissions[0]);

      //accounts[3] enters tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[3], gas: gasEstimate});

      //make a sumbission from account3
      submissionThree = await tournament.createSubmission("submission3", accounts[3], "external address 3", ["0x0"], ["0x0"], ["0x0"], {from: accounts[3], gas: gasEstimate});
      submissionThreeAddress = submissionThree.logs[0].args._submissionAddress;

      //get peers
      peerOneAddress = await platform.peerAddress(accounts[1]);
      peerTwoAddress = await platform.peerAddress(accounts[2]);
      peerThreeAddress = await platform.peerAddress(accounts[3]);
      peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);
      peerThree = web3.eth.contract(MatryxPeer.abi).at(peerThreeAddress);

      await submissionTwo.addReference(submissionOneAddress, {from: accounts[2]});

      //peer 1 approves a reference to submission1 within submission2
      //peer 2's reputation increases
      await peerOne.approveReference(submissionTwoAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
      console.log("1st approval");

      //make another submission from accounts[1]
      submissionOneB = await tournament.createSubmission("submission1B", accounts[1], "external address 1B", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionOneBAddress = submissionOneB.logs[0].args._submissionAddress;

      await submissionTwo.addReference(submissionOneBAddress, {from: accounts[2]});
      //give some more trust to peer2
      await peerOne.approveReference(submissionTwoAddress, submissionOneBAddress, {from: accounts[1], gas: gasEstimate});
      console.log("2nd approval");

      //get my submissions
      mySubmissions = await tournament.mySubmissions.call({from: accounts[3]});
      //get submission two
      submissionThree = await MatryxSubmission.at(mySubmissions[0]);

      await submissionThree.addReference(submissionOneAddress, {from: accounts[3]});
      //peer 1 approves a reference to submission1 within submission3
      //peer 3's reputation increases
      await peerOne.approveReference(submissionThreeAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
      console.log("3rd approval");

      //peer3 flags submission2 as missing a reference to submission3
      //peer2's reputation decreases
      let judgingPeerToUnnormalizedTrust = await peerTwo.getJudgingPeerToUnnormalizedTrust(peerThreeAddress);
      console.log("judgingPeerToUnnormalizedTrust: " + judgingPeerToUnnormalizedTrust);
      await peerThree.flagMissingReference(submissionTwoAddress, submissionThreeAddress, {from: accounts[3], gas: gasEstimate});
      console.log("flag added");

      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      assert.isTrue(peerTwoReputationAfter > 0, "Submission was not successfully flagged.");
    });

    it("Unable to approve same reference twice", async function() {
      //peer1 tries to approve reference to submission1 within submission2 again
      try {
          await peerOne.approveReference(submissionTwoAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Unable to approve reference that wasn't added by submission first.", async function() {
      //peer1 tries to approve reference to submission1 within submission2 again
      try {
          await peerTwo.approveReference(submissionOneAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Missing reference flag disappears automatically after submisison is added as a reference", async function() {
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //get my submissions
      mySubmissions = await tournament.mySubmissions.call({from: accounts[2]});
      //get submission two
      submissionTwo = await MatryxSubmission.at(mySubmissions[0]);

      //submission2 adds submission3 as a reference and peer3 approves the reference
      //missing reference flag should be automatically removed
      await submissionTwo.addReference(submissionThreeAddress, {from: accounts[2], gas: gasEstimate});
      await peerThree.approveReference(submissionTwoAddress, submissionThreeAddress, {from: accounts[3], gas: gasEstimate});

      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      let missingReferenceCount = await peerThree.getMissingReferenceCount(submissionTwoAddress);
      console.log("missingReferenceCount: " + missingReferenceCount[0]);

      assert.isTrue(missingReferenceCount[0] == 0, "Missing flag reference did not disappear after adding reference");
    });

    it("Unable to flag someone who doesn't have any reputation yet", async function() {
      //peer3 tries to flag submission1 as missing a reference to submission3
      try {
          await peerThree.flagMissingReference(submissionOneAddress, submissionThreeAddress, {from: accounts[3], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Unable to add same missing reference flag twice", async function() {
      //peer1 flags submission3 as missing a reference to submission1
      await peerOne.flagMissingReference(submissionThreeAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
      //peer1 tries to add the same missing flag reference again
      try {
          await peerOne.flagMissingReference(submissionThreeAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = (error.message.search('revert') >= 0) || (error.message.search('invalid opcode') >= 0);
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Unable to remove nonexistent missing reference flag", async function() {
      //peer2 tries to remove nonexistent missing reference flag in submission1
      try {
          await peerTwo.removeMissingReferenceFlag(submissionOneAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = (error.message.search('revert') >= 0) || (error.message.search('invalid opcode') >= 0);
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Unable to remove nonexistent reference approval", async function() {
      //peer2 tries to remove nonexistent reference approval in submission1
      try {
          await peerTwo.removeReferenceApproval(submissionOneAddress, submissionTwoAddress, {from: accounts[2], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = (error.message.search('revert') >= 0) || (error.message.search('invalid opcode') >= 0);
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Able to remove reference after it has been approved", async function() {
      console.log("submissionThreeAddress: " + submissionThreeAddress);
      let references = await submissionTwo.getReferences.call();
      console.log("references before: " + references);
      await submissionTwo.removeReference(submissionThreeAddress, {from: accounts[2], gas: gasEstimate});
      references = await submissionTwo.getReferences.call();
      console.log("references after: " + references);
      assert.equal(references[3], 0, "Reference was not successfully removed.");
    });

});


contract('ReputationTesting', function(accounts)
{
    let platform;
    let token;

    let tournamentAddress;
    let tournament;

    let submissionOne;
    let submissionOneAddress;
    let submissionTwo;
    let submissionTwoAddress;
    let submissionThree;
    let submissionThreeAddress;

    let peerOne;
    let peerTwo;
    let peerThree;
    let peerOneAddress;
    let peerTwoAddress;
    let peerThreeAddress;

    //for code coverage
    let gasEstimate = 30000000;
    //for regular testing
    //let gasEstimate = 3000000;

    it("Able approve a reference in my submission after I have been flagged for missing the reference", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});

      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)

      await token.approve(MatryxPlatform.address, 100*10**18)

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

      //open tournament
      let tournamentOpen = await tournament.openTournament({gas: gasEstimate});

      //enter tournament
      let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      //create and start round
      let roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

      //open round
      let roundOpen = await round.isOpen();

      //accounts[1] enters tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      //make a sumbission from account1
      submissionOne = await tournament.createSubmission("submission1", accounts[1], "external address 1", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionOneAddress = submissionOne.logs[0].args._submissionAddress;

      //accounts[2] enters tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[2], gas: gasEstimate});

      //make a sumbission from account2
      submissionTwo = await tournament.createSubmission("submission2", accounts[2], "external address 2", ["0x0"], ["0x0"], ["0x0"], {from: accounts[2], gas: gasEstimate});
      submissionTwoAddress = submissionTwo.logs[0].args._submissionAddress;
      //get my submissions
      let mySubmissions = await tournament.mySubmissions.call({from: accounts[2]});
      //get submission two
      submissionTwo = await MatryxSubmission.at(mySubmissions[0]);

      //accounts[3] enters tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[3], gas: gasEstimate});

      //make a sumbission from account3
      submissionThree = await tournament.createSubmission("submission3", accounts[3], "external address 3", ["0x0"], ["0x0"], ["0x0"], {from: accounts[3], gas: gasEstimate});
      submissionThreeAddress = submissionThree.logs[0].args._submissionAddress;

      //get peers
      peerOneAddress = await platform.peerAddress(accounts[1]);
      peerTwoAddress = await platform.peerAddress(accounts[2]);
      peerThreeAddress = await platform.peerAddress(accounts[3]);
      peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);
      peerThree = web3.eth.contract(MatryxPeer.abi).at(peerThreeAddress);

      await submissionTwo.addReference(submissionOneAddress, {from: accounts[2]});

      //peer 1 approves a reference to submission1 within submission2
      //peer 2's reputation increases
      await peerOne.approveReference(submissionTwoAddress, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
      console.log("1st approval");

      //make another submission from accounts[1]
      submissionOneB = await tournament.createSubmission("submission1B", accounts[1], "external address 1B", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionOneBAddress = submissionOneB.logs[0].args._submissionAddress;

      await submissionTwo.addReference(submissionOneBAddress, {from: accounts[2]});
      //give some more trust to peer2
      await peerOne.approveReference(submissionTwoAddress, submissionOneBAddress, {from: accounts[1], gas: gasEstimate});
      console.log("2nd approval");

      //get my submissions
      mySubmissions = await tournament.mySubmissions.call({from: accounts[3]});
      //get submission two
      submissionThree = await MatryxSubmission.at(mySubmissions[0]);

      //peer3 flags submission2 as missing a reference to submission3
      //peer2's reputation decreases
      await peerThree.flagMissingReference(submissionTwoAddress, submissionThreeAddress, {from: accounts[3], gas: gasEstimate});
      console.log("flag added");

      //now submisison2 adds submission 3 and peer3 approves the submission reference
      await submissionTwo.addReference(submissionThreeAddress, {from: accounts[2]});
      await peerThree.approveReference(submissionTwoAddress, submissionThreeAddress, {from: accounts[3]});
      console.log("submisison2 now cites submisison3 as a reference");

      //get my references
      let references = await submissionTwo.getReferences.call();
      console.log("references: " + references);
      console.log("submissionThreeAddress: " + submissionThreeAddress);

      assert.equal(references[3], submissionThreeAddress, "Reference was not successfully approved.");
    });

    it("Able to remove reference approval if already flagged submission for missing the reference", async function() {
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      let references = await submissionTwo.getReferences.call();
      console.log("references before: " + references);

      await peerThree.removeReferenceApproval(submissionTwoAddress, submissionThreeAddress, {from: accounts[3]});
      //get my references
      references = await submissionTwo.getReferences.call();
      console.log("references after: " + references);
      console.log("submissionThreeAddress: " + submissionThreeAddress);

      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      assert.isTrue(peerTwoReputationAfter < peerTwoReputationBefore, "Reference approval was not successfully removed.");
    });

    it("Able to add multiple missing reference flags to one submisison", async function() {
      let peerTwoReputationBefore = await peerTwo.getReputation();
      console.log("peerTwoReputationBefore " + peerTwoReputationBefore);

      //make another sumbission from account3
      let submissionThreeB = await tournament.createSubmission("submission3B", accounts[3], "external address 3B", ["0x0"], ["0x0"], ["0x0"], {from: accounts[3], gas: gasEstimate});
      let submissionThreeBAddress = submissionThreeB.logs[0].args._submissionAddress;

      //peer3 adds a second misisng reference flag to submission2
      await peerThree.flagMissingReference(submissionTwoAddress, submissionThreeBAddress, {from: accounts[3], gas: gasEstimate});
      console.log("flag added");

      let peerTwoReputationAfter = await peerTwo.getReputation();
      console.log("peerTwoReputationAfter " + peerTwoReputationAfter);

      assert.equal(peerTwoReputationAfter < peerTwoReputationBefore, "Reference approval was not successfully removed.");
    });

});
