let MatryxPlatform = artifacts.require("MatryxPlatform");
let MatryxTournament = artifacts.require("MatryxTournament");
let MatryxRound = artifacts.require("MatryxRound");
let MatryxSubmission = artifacts.require("MatryxSubmission");

contract('MatryxPlatform', function(accounts)
{
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let submissionOne;
    let submissionOneBlocktime;

    it("Submission one owner is submission creator", async function() {
		// get the platform
		platform = await MatryxPlatform.deployed();
		// create a tournament
		createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
		// get the tournament address
		tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

		// // create tournament from address
		tournament = await MatryxTournament.at(tournamentAddress);
		await tournament.openTournament();
		// //
		await tournament.createRound(4);
		await tournament.startRound(2);

		let currentRound = await tournament.currentRound.call();

		console.log("current round: " + currentRound);

		// become entrant in tournament
		await platform.enterTournament(tournamentAddress);
		let submissionOneTx = await tournament.createSubmission("submission1", accounts[0], "external address", [accounts[3]], [accounts[4]], false);

		let blocknumber = await web3.eth.getTransaction(submissionOneTx.tx).blockNumber;
		submissionOneBlocktime = await web3.eth.getBlock(blocknumber).timestamp

		let mySubmissions = await tournament.mySubmissions.call();
		// create the submission in tournament
		submissionOne = await MatryxSubmission.at(mySubmissions[0]);
		let submissionOwner = await submissionOne.owner.call();

		// // check that we're both the tournament and submission owner
		assert.equal(submissionOwner, accounts[0], "The owner of the submission should be the owner of the tournament");
	});

    it("Submission two owner is submission creator", async function() {
		await platform.enterTournament(tournamentAddress, {from: accounts[1]});
		await tournament.createSubmission("submission2", accounts[1], "external address", ["0x0"], ["0x0"], true, {from: accounts[1]});

		let mySubmissions = await tournament.mySubmissions.call({from: accounts[1]});
		// create the submission in tournament
		let submissionTwo = await MatryxSubmission.at(mySubmissions[0]);
		let submissionOwnerTwo = await submissionTwo.owner.call();

		assert.equal(submissionOwnerTwo, accounts[1], "The owner of the submission should be the owner of the tournament");
	});

	it("Submission one has correct title", async function() {
		let submissionTitle = await submissionOne.getTitle.call();
		assert.equal(submissionTitle, "submission1", "Submission one title was not 'submission1'");
	});

	it("Submission one has correct author", async function() {
		let submissionAuthor = await submissionOne.getAuthor.call();
		assert.equal(submissionAuthor, accounts[0], "Submission author was not accounts[0]");
	})

	it("Submission one has correct references", async function() {
		let submissionReferences = await submissionOne.getReferences.call();
		assert.equal(submissionReferences, accounts[4], "References for submission one were not [accounts[4]]");
	});

	it("Submission one has correct contributors", async function() {
		let submissionContributors = await submissionOne.getContributors.call();
		assert.equal(submissionContributors, accounts[3], "Contributors for submission one were not [accounts[3]]");
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

	it("Able to add to a submission's references", async function() {
		await submissionOne.addReference(accounts[5]);
		let references = await submissionOne.getReferences.call();
		assert.equal(references[1], accounts[5], "References on submission not updated correctly");
	})

	it("Able to delete a submission's references", async function() {
		await submissionOne.removeReference(1);
		let references = await submissionOne.getReferences.call();
		assert.equal(references[1], 0, "Removed reference was not null");
	})

	it("Able to add to a submission's contributors", async function() {
		await submissionOne.addContributor(accounts[6]);
		let contributors = await submissionOne.getContributors.call();
		assert.equal(contributors[1], accounts[6], "References on submission not updated correctly");
	})

	it("Able to delete a submission's contributors", async function() {
		await submissionOne.removeContributor(1);
		let contributors = await submissionOne.getContributors.call();
		assert.equal(contributors[1], 0, "Removed reference was not null");
	})

	it("Able to read a submission's balance", async function() {
		let balance = await submissionOne.getBalance.call();
		assert.equal(balance, 0, "Submission's balance was not zero.");
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