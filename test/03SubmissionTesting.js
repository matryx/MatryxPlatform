let MatryxPlatform = artifacts.require("MatryxPlatform");
let Tournament = artifacts.require("Tournament");
let Submission = artifacts.require("Submission");

contract('MatryxPlatform', function(accounts)
{
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;

    it("Submission one owner is submission creator", async function() {
		// get the platform
		platform = await MatryxPlatform.deployed();
		// create a tournament
		createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
		// get the tournament address
		tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

		// create tournament from address
		tournament = await Tournament.at(tournamentAddress);

		// become entrant in tournament
		await platform.enterTournament(tournamentAddress);
		await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);

		let mySubmissions = await tournament.mySubmissions.call();
		// create the submission in tournament
		let submissionOne = await Submission.at(mySubmissions[0]);
		let submissionOwner = await submissionOne.getSubmissionOwner.call();

		// check that we're both the tournament and submission owner
		assert.equal(submissionOwner, accounts[0], "The owner of the submission should be the owner of the tournament");
	});

    it("Submission two owner is submission creator", async function() {
		await platform.enterTournament(tournamentAddress, {from: accounts[1]});
		await tournament.createSubmission("submission2", "external address", ["0x0"], ["0x0"], {from: accounts[1]});

		let mySubmissions = await tournament.mySubmissions.call({from: accounts[1]});
		// create the submission in tournament
		let submissionTwo = await Submission.at(mySubmissions[0]);
		let submissionOwnerTwo = await submissionTwo.getSubmissionOwner.call();

		assert.equal(submissionOwnerTwo, accounts[1], "The owner of the submission should be the owner of the tournament");
	});
});


contract('MatryxPlatform', function(accounts) {
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;

    let submissionOne;

    it("Tournament is open, submission is not public, creator tries to access it", async function() {
		// get the platform
		platform = await MatryxPlatform.deployed();
		// create a tournament
		createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
		// get the tournament address
		tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

		// create tournament from address
		tournament = await Tournament.at(tournamentAddress);

		// become entrant in tournament
		await platform.enterTournament(tournamentAddress);
		await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);

		let mySubmissions = await tournament.mySubmissions.call();
		// create the submission in tournament
		submissionOne = await Submission.at(mySubmissions[0]);

		// check accessibility on this submission for accounts[0]
		let isAccessible = await submissionOne.isAccessible.call(accounts[0]);
		assert.equal(isAccessible, true, "The submission should be accessible to its creator.");
	});

    it("Tournament is open, submission is not public, outside user tries to access it", async function() {
		// check accessibility on this submission for accounts[1]
		let isAccessible = await submissionOne.isAccessible.call(accounts[1]);
		assert.equal(isAccessible, false, "The submission should be inaccessible to outside users.");
	});

    it("Tournament is open, submission was made public, outside user tries to access it", async function() {
		await submissionOne.makeExternallyAccessibleDuringTournament();
		let isAccessible = await submissionOne.isAccessible.call(accounts[1]);
		assert.equal(isAccessible, true, "The submission should be accessible now.");
	})

});