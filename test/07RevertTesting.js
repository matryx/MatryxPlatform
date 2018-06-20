var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxToken = artifacts.require("MatryxToken");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxSubmission = artifacts.require("MatryxSubmission");
let MatryxPeer = artifacts.require("MatryxPeer");

//Testing all possible reverts for MatryxPlatform
contract('RevertsMatryxPlatform', function(accounts){

  let platform;
  let token;
  //for code coverage
  let gasEstimate = 30000000;
  //for testrpc
  //let gasEstimate = 3000000;

	it("Able to catch reverts", async function() {
    	web3.eth.defaultAccount = web3.eth.accounts[0];
      	//deploy platform
      	platform = await MatryxPlatform.deployed();
      	token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      	platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address); 
  			try {
    			await platform.forceRevert();
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	//Testing platform require statements
	it("Unable to prepare balance twice", async function() {
  			try {
    			await platform.prepareBalance(5);
    			await platform.prepareBalance(5);
   				assert.fail('Expected revert not received');
  			} catch (error) {
  				console.log(error);
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to get tournament at index < 0", async function() {
  			try {
    			await platform.getTournamentAtIndex(-1);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to get tournament at index > number of existing tournaments", async function() {
  			try {
    			await platform.getTournamentAtIndex(10);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to say whether tournament is mine for nonexisting tournament", async function() {
  			try {
    			await platform.getTournament_IsMine(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to enter nonexisting tournament", async function() {
  			try {
    			await platform.enterTournament(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to remove submission in nonexisting tournament", async function() {
  			try {
    			await platform.removeSubmission(0x0, 0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to create tournament from non-peer-linked account", async function() {
  			try {
    			await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {gas: gasEstimate});
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to create tournament with insufficient allowance", async function() {
      		await platform.createPeer.sendTransaction({gas: gasEstimate});
  			try {
    			await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {gas: gasEstimate});
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to handle reference request for submission", async function() {
  			try {
    			await platform.handleReferenceRequestForSubmission(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to handle cancelled reference request for nonexisting submission", async function() {
  			try {
    			await platform.handleCancelledReferenceRequestForSubmission(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	//Testing platform modifiers
	it("Unable to handle reference requests for submisison from platform (only tournament)", async function() {
  			try {
    			await platform.handleReferenceRequestsForSubmission(0x0, [0x0]);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to update submisisons from platform (only tournament)", async function() {
  			try {
    			await platform.updateSubmissions(accounts[0], 0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to invoke tournament opened event from platform (only tournament)", async function() {
  			try {
    			await platform.invokeTournamentOpenedEvent(accounts[0], 0x0, "tournamentName", 0x0, 1, 1);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to invoke tournament closed event from platform (only tournament)", async function() {
  			try {
    			await platform.invokeTournamentClosedEvent(0x0, 1, 0x0, 1);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});
});

//Testing all possible reverts for MatryxTournament
contract('RevertsMatryxTournament', function(accounts){
	let platform;
	let token;
	let tournament;
	//for code coverage
	let gasEstimate = 30000000;
	//for testrpc
	//let gasEstimate = 3000000;

	//Testing tournament require statements
	it("Unable to set max number of rounds < current number of rounds", async function() {
		web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();

      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);

      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address); 
      let owner = await platform.owner();
      let getOwner = await platform.getOwner();
      let tournamentCount = await platform.tournamentCount();

      let peerAddress = await platform.peerAddress(accounts[0]);

      await platform.createPeer.sendTransaction({from:accounts[1], gas: gasEstimate});
      peerAddress = await platform.peerAddress(accounts[0]);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction();
      await token.mint(web3.eth.accounts[0], 10000*10**18)
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
  		try {
    		await tournament.setNumberOfRounds(0);
   			assert.fail('Expected revert not received');
  		} catch (error) {
    		const revertFound = error.message.search('revert') >= 0;
    		assert(revertFound, 'Unable to catch revert');
  		}
	});

	it("Unable to create submission without being an entrant", async function() {
  			try {
    			let submisison = await tournament.createSubmission("title", accounts[0], 0x0, ["0x0"], ["0x0"], ["0x0"]);
    			console.log("submisison: " + submisison);
   				assert.fail('Expected revert not received');
  			} catch (error) {
  				console.log("error: " + error);
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to create submission from an account without a peer", async function() {
  			try {
    			let submisison = await tournament.createSubmission("title", accounts[1], 0x0, ["0x0"], ["0x0"], ["0x0"], {from: accounts[1]});
   				console.log("submisison: " + submisison);
   				assert.fail('Expected revert not received');
  			} catch (error) {
  				console.log("error: " + error);
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to remove submission that doesn't exist under author's address", async function() {
  			try {
    			await tournament.removeSubmission(0x0, accounts[0]);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to choose nonexisting submisison as winner", async function() {
  			try {
    			await tournament.chooseWinner(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = (error.message.search('revert') >= 0) || (error.message.search('opcode') >= 0);
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to create tournament from null account", async function() {
  			try {
    			await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {from: 0x0, gas: gasEstimate});
   				assert.fail('Expected revert not received');
  			} catch (error) {
  				console.log(error);
    			const revertFound = (error.message.search('revert') >= 0);
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

  it("Unable to create tournament with 0 bounty", async function() {
        try {
          await platform.createTournament("category", "tournament", "external address", 0, 2*10**18, {from: accounts[1], gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          console.log(error);
          const revertFound = (error.message.search('revert') >= 0);
          assert(revertFound, 'Unable to catch revert');
        }
  });

	//Testing modifiers
	it("Unable to invoke submission created event from tournament (only round)", async function() {
  			try {
    			await tournament.invokeSubmissionCreatedEvent(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = (error.message.search('revert') >= 0);
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to set title from non-owner account", async function() {
  			try {
    			await tournament.setTitle("nope", {from: accounts[1]});
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = (error.message.search('revert') >= 0);
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to set number of rounds from non-owner account", async function() {
  			try {
    			await tournament.setNumberOfRounds(10, {from: accounts[1]});
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = (error.message.search('revert') >= 0);
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to enter user in tournament from tournament (only platform)", async function() {
  			try {
    			await tournament.enterUserInTournament(accounts[1]);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = (error.message.search('revert') >= 0);
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

});

//Testing all possible reverts for MatryxRound
contract('RevertsMatryxRound', function(accounts){
	let platform;
	let token;
	let tournament;
	//for code coverage
	let gasEstimate = 30000000;
	//for testrpc
	//let gasEstimate = 3000000;

	it("Unable to look up submission at index > number of submisisons", async function() {
		web3.eth.defaultAccount = web3.eth.accounts[0];
		  //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
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
      let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

    	//create and start round
    	let roundAddress = await tournament.createRound(5);
    	round = await tournament.currentRound();
    	roundAddress = round[1];

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
    	round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

    	try {
    			await round.submissionIsAccessible(10);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}

    	//open round
    	//let roundOpen = await round.isOpen();
	});

	it("Unable to get address of submisison at nonexisting index", async function() {
  			try {
    			await round.getSubmissionAddress(10);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to choose nonexisting submisison as winner", async function() {
  			try {
    			await round.chooseWinningSubmission(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to create submisison with a null author address", async function() {
  			try {
    			await round.createSubmission("title", accounts[0], 0x0, 0x0, ["0x0"], ["0x0"], ["0x0"]);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

});


//Testing all possible reverts for MatryxSubmisison
contract('RevertsMatryxSubmission', function(accounts){
	let platform;
	let token;
	let tournament;
	let submissionOne;
	//for code coverage
	let gasEstimate = 30000000;
	//for testrpc
	//let gasEstimate = 3000000;

	it("Unable to add nonexisting reference to submisison", async function() {
	  web3.eth.defaultAccount = web3.eth.accounts[0];
	  //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
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
      let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

      //create round
      roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];
      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);
      let roundOpen = await round.isOpen();

      //create submission
      let submissionOneTx = await tournament.createSubmission("submission1", accounts[0], "external address 1", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});

	  let blocknumber = await web3.eth.getTransaction(submissionOneTx.tx).blockNumber;
	  submissionOneBlocktime = await web3.eth.getBlock(blocknumber).timestamp;

	  //get my submissions
	  let mySubmissions = await tournament.mySubmissions.call();
	  //get submission one
	  submissionOne = await MatryxSubmission.at(mySubmissions[0]);

  			try {
    			await submissionOne.addReference(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to remove nonexisting reference to submission", async function() {
  			try {
    			await submissionOne.removeReference(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to approve nonexisting reference to submission", async function() {
  			try {
    			await submissionOne.approveReference(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to remove nonexisting reference approval to submission", async function() {
  			try {
    			await submissionOne.removeReferenceApproval(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to flag nonexisting missing reference", async function() {
  			try {
    			await submissionOne.flagMissingReference(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

	it("Unable to remove nonexisting missing reference flag", async function() {
  			try {
    			await submissionOne.removeMissingReferenceFlag(0x0);
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

});

//Testing all possible reverts for MatryxPeer
contract('RevertsMatryxPeer', function(accounts){
	let platform;
	let token;
	let tournament;
	let submissionOneAddress;
	let peerOne;
	let peerTwo;
	//for code coverage
	let gasEstimate = 30000000;
	//for testrpc
	//let gasEstimate = 3000000;

	it("Unable to flag a submission with a nonexisting reference", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address);
      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});

      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)

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

      //enter tournament
      await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});

      //make a sumbission from account1
      submissionOne = await tournament.createSubmission("submission1", accounts[1], "external address 1", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});
      submissionOneAddress = submissionOne.logs[0].args._submissionAddress;

      //get peers
      peerOneAddress = await platform.peerAddress(accounts[1]);
      peerTwoAddress = await platform.peerAddress(accounts[2]);
      peerOne = web3.eth.contract(MatryxPeer.abi).at(peerOneAddress);
      peerTwo = web3.eth.contract(MatryxPeer.abi).at(peerTwoAddress);

      try {
    			await peerOne.flagMissingReference(0x0, submissionOneAddress, {from: accounts[1], gas: gasEstimate});
   				assert.fail('Expected revert not received');
  		} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}

  		});

	it("Unable to flag a nonexisting sumbission", async function() {
  			try {
    			await peerTwo.flagMissingReference(submissionOneAddress, 0x1234, {from: accounts[2], gas: gasEstimate});
   				assert.fail('Expected revert not received');
  			} catch (error) {
  				console.log(error);
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
	});

});