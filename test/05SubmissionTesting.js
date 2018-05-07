let MatryxPlatform = artifacts.require("MatryxPlatform");
let MatryxTournament = artifacts.require("MatryxTournament");
let MatryxRound = artifacts.require("MatryxRound");
let MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxPlatform', function(accounts)
{
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let submissionOne;
    let submissionTwo;
    let submissionOneBlocktime;
    let token;

    it("Submission one owner is submission creator", async function() {
		platform = await MatryxPlatform.deployed();
      	token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      	platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
      	web3.eth.defaultAccount = web3.eth.accounts[0]
      	await platform.createPeer.sendTransaction({gas: 3000000});
      	await platform.createPeer.sendTransaction({gas: 3000000, from: web3.eth.accounts[1]});
      	await platform.createPeer.sendTransaction({gas: 3000000, from: web3.eth.accounts[2]});
      	await platform.createPeer.sendTransaction({gas: 3000000, from: web3.eth.accounts[3]});
      	await token.setReleaseAgent(web3.eth.accounts[0])
      	await token.releaseTokenTransfer.sendTransaction({gas: 1000000})
      	await token.mint(web3.eth.accounts[0], 10000*10**18)
      	await token.mint(web3.eth.accounts[1], 2*10**18)
      	await token.mint(web3.eth.accounts[2], 2*10**18)
      	await token.mint(web3.eth.accounts[3], 2*10**18)
      	await token.approve(MatryxPlatform.address, 100*10**18)
      	// create a tournament
        createTournamentTransaction = await platform.createTournament("category", "tournament", "external address", 100*10**18, 2, {gas: 3000000});
        // get the tournament address
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

      	tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
      	tournament = await MatryxTournament.at(tournamentAddress);

      	//open tournament
    	let tournamentOpen = await tournament.openTournament();

    	//enter tournament
    	let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: 3000000});

    	//create and start round
    	let roundAddress = await tournament.createRound(5);

    	round = await tournament.currentRound();
    	roundAddress = round[1];

    	await tournament.startRound(10, 10, {gas: 3000000});
    	round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

    	//open round
    	let roundOpen = await round.isOpen();

		// become entrant in tournament
		let submissionOneTx = await tournament.createSubmission("submission1", accounts[0], "external address 1", ["0x0"], ["0x0"], ["0x0"]);

		let blocknumber = await web3.eth.getTransaction(submissionOneTx.tx).blockNumber;
		submissionOneBlocktime = await web3.eth.getBlock(blocknumber).timestamp

		let mySubmissions = await tournament.mySubmissions.call();
		// create the submission in tournament
		submissionOne = await MatryxSubmission.at(mySubmissions[0]);
		let submissionOwner = await submissionOne.owner.call();

		//check that we're both the tournament and submission owner
		assert.equal(submissionOwner, accounts[0], "The owner of the submission should be the owner of the tournament");
	});

    it("Submission two owner is submission creator", async function() {
    	let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: 3000000});
		await tournament.createSubmission("submission2", accounts[1], "external address 2", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1]});

		let mySubmissions = await tournament.mySubmissions.call({from: accounts[1]});
		// create the submission in tournament
		submissionTwo = await MatryxSubmission.at(mySubmissions[0]);
		let submissionOwnerTwo = await submissionTwo.owner.call();

		assert.equal(submissionOwnerTwo, accounts[1], "The owner of the submission should be the owner of the tournament");
	});

	it("Submission one has correct title", async function() {
		let submissionTitle = await submissionOne.getTitle.call();
		assert.equal(submissionTitle, "submission1", "Submission one title was not 'submission1'");
	});

	it("Submission one has correct author", async function() {
		let submissionAuthor = await submissionOne.getAuthor.call();
		let submissionOnePeerAddress = await platform.peerAddress(accounts[0]);
		assert.equal(submissionAuthor, submissionOnePeerAddress, "Submission author was not accounts[0]'s peer");
	})

	it("Submission one has correct time", async function() {
		let submissionOneTimeSubmitted = await submissionOne.getTimeSubmitted.call();
		assert.equal(submissionOneTimeSubmitted, submissionOneBlocktime, "Submission one time submitted not equal to time block was mined.");
	});

	it("Able to make submission externally accessible", async function() {
		await submissionOne.makeExternallyAccessibleDuringTournament();
		let accessible = await submissionOne.publicallyAccessibleDuringTournament.call();
		assert.isTrue(accessible, "The submission was not accessible after being made accessible");
	})

	it("Able to update submission's title", async function() {
		await submissionOne.updateTitle("1noissimbus");
		let title = await submissionOne.getTitle.call();
		assert.equal(title, "1noissimbus", "Submission one title not equal to '1noissimbus'");
	})

	it("Able to update submission's external address", async function() {
		await submissionOne.updateExternalAddress("hashbrowns");
		let externalAddress = await submissionOne.getExternalAddress.call();
		assert.equal(web3.toAscii(externalAddress).replace(/\u0000/g, ""), "hashbrowns", "External address not updated correctly");
	})

	it("Able to make a submission externally accessible", async function() {
		await submissionOne.makeExternallyAccessibleDuringTournament();
		let accessible = await round.submissionIsAccessible.call(0, {from: accounts[3]});
		assert.isTrue(accessible, "Submission is not externally accessible");
	})

	it("Able to read a submission's balance", async function() {
		let balance = await submissionOne.getBalance.call();
		assert.equal(balance, 0, "Submission's balance was not zero.");
	})

	//Testing methods from Submission Trust
	it("Able to add to a submission's references", async function() {
		await submissionOne.addReference(submissionTwo.address, {gas: 3000000});
		let references = await submissionOne.getReferences.call();
		assert.equal(references[1], submissionTwo.address, "References on submission not updated correctly");
	})

	it("Able to delete a submission's references", async function() {
		await submissionOne.removeReference(submissionTwo.address);
		let references = await submissionOne.getReferences.call();
		assert.equal(references[1], 0, "Removed reference was not null");
	})

	it("Able to add to a submission's contributors", async function() {
		await submissionOne.addContributor(accounts[6], 100);
		let contributors = await submissionOne.getContributors.call();
		assert.equal(contributors[1], accounts[6], "References on submission not updated correctly");
	})

	it("Able to delete a submission's contributors", async function() {
		await submissionOne.removeContributor(1);
		let contributors = await submissionOne.getContributors.call();
		assert.equal(contributors[1], 0, "Removed reference was not null");
	})

});


// contract('MatryxPlatform', function(accounts) {
//     let platform;
//     let createTournamentTransaction;
//     let tournamentAddress;
//     let tournament;

//     let submissionOne;

//     it("Tournament is open, submission is not public, creator tries to access it", async function() {
// 		// get the platform
// 		platform = await MatryxPlatform.deployed();
// 		// create a tournament
// 		createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
// 		// get the tournament address
// 		tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

// 		// create tournament from address
// 		tournament = await Tournament.at(tournamentAddress);

// 		// become entrant in tournament
// 		await platform.enterTournament(tournamentAddress);
// 		await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);

// 		let mySubmissions = await tournament.mySubmissions.call();
// 		// create the submission in tournament
// 		submissionOne = await Submission.at(mySubmissions[0]);

// 		// check accessibility on this submission for accounts[0]
// 		let isAccessible = await submissionOne.isAccessible.call(accounts[0]);
// 		assert.equal(isAccessible, true, "The submission should be accessible to its creator.");
// 	});

//     it("Tournament is open, submission is not public, outside user tries to access it", async function() {
// 		// check accessibility on this submission for accounts[1]
// 		let isAccessible = await submissionOne.isAccessible.call(accounts[1]);
// 		assert.equal(isAccessible, false, "The submission should be inaccessible to outside users.");
// 	});

//     it("Tournament is open, submission was made public, outside user tries to access it", async function() {
// 		await submissionOne.makeExternallyAccessibleDuringTournament();
// 		let isAccessible = await submissionOne.isAccessible.call(accounts[1]);
// 		assert.equal(isAccessible, true, "The submission should be accessible now.");
// 	})

// });

// contract('Submission', function(accounts) {
//     let platform;
//     let createTournamentTransaction;
//     let tournamentAddress;
//     let tournament;
//     let submissionOne;

//     it("Submission retained references", async function() {
// 		// get the platform
// 		platform = await MatryxPlatform.deployed();
// 		// create a tournament
// 		createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
// 		// get the tournament address
// 		tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

// 		// create tournament from address
// 		tournament = await Tournament.at(tournamentAddress);

// 		// become entrant in tournament
// 		await platform.enterTournament(tournamentAddress);
// 		await tournament.createSubmission("submission1", "external address", ["0x123"], ["0x456"]);

// 		let mySubmissions = await tournament.mySubmissions.call();
// 		// create the submission in tournament
// 		submissionOne = await Submission.at(mySubmissions[0]);
// 		let submissionReferences = await submissionOne.getReferences.call();

// 		// check that we're both the tournament and submission owner
// 		assert.equal(submissionReferences.valueOf()[0], '0x0000000000000000000000000000000000000123', "The references for this submission were retained");
// 	});

// 	it("Submission retained contributors", async function() {
// 		let submissionContributors = await submissionOne.getContributors.call();
// 		assert.equal(submissionContributors.valueOf()[0], '0x0000000000000000000000000000000000000456', "The contributors of this submission were retained");
// 	});

// 	it("Submission retained external address", async function() {
// 		let externalAddressBytes32 = await submissionOne.getExternalAddress.call();
// 		let externalAddressString = web3.toAscii(externalAddressBytes32.valueOf());
// 		let externalAddressStringNoZeros = externalAddressString.replace(/\u0000+/g, "");
// 		assert.equal(externalAddressStringNoZeros, "external address", "The submission retained its external address");
// 	});
// });

// contract('Submission', function() {
// 	let platform;
//     let createTournamentTransaction;
//     let tournamentAddress;
//     let tournament;
//     let submissionViewerAddress;
//     let submissionOne;

// 	it("Submission retained the time it was submitted", async function() {
// 		// get the platform
// 		platform = await MatryxPlatform.deployed();
// 		// create a tournament
// 		createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
// 		// get the tournament address
// 		tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

// 		// create tournament from address
// 		tournament = await Tournament.at(tournamentAddress);

// 		// become entrant in tournament
// 		await platform.enterTournament(tournamentAddress);
		
// 		// create a submission
// 		let createSubmissionTx = await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);
// 		// get the transaction's block
// 		let nowBlock = await web3.eth.getBlock(createSubmissionTx.receipt.blockNumber);
// 		// get the timestamp of that block
// 		let nowBlockTimestamp = await nowBlock.timestamp;
// 		// get the submission
// 		let mySubmissions = await tournament.mySubmissions.call();
// 		let submissionOne = await Submission.at(mySubmissions[0]);
// 		// get the timestamp on the submission
// 		let timeSubmitted = await submissionOne.getTimeSubmitted.call();
		
// 		assert.equal(timeSubmitted.valueOf(), nowBlockTimestamp, "The submission retained the time it was submitted");
// 	});
// })