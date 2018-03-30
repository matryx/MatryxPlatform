let MatryxPlatform = artifacts.require("MatryxPlatform");
let MatryxTournament = artifacts.require("MatryxTournament");
let MatryxRound = artifacts.require("MatryxRound");

contract('MatryxPlatform', function(accounts)
{
	let platform;
	let tournament;
	let round;

	it("Submission is accessible to creator", async function() {
		platform = await MatryxPlatform.deployed();
		let tournamentCreationTx = await platform.createTournament("tournament", "external address", 100, 2);
		let tournamentAddress = tournamentCreationTx.logs[0].args._tournamentAddress;
      	tournament = await MatryxTournament.at(tournamentAddress);

      	await tournament.openTournament();
      	platform.enterTournament(tournamentAddress);
      	await tournament.createRound(5);
	    let roundAddress = await tournament.rounds.call(0);
	    round = await MatryxRound.at(roundAddress);
	    await round.Start(0);
	    await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], false);

	    let submissionIsAccessible = await round.submissionIsAccessible.call(0);

	    assert.isTrue(submissionIsAccessible, "Submission is not accessible to its creator");
	});

	it("Submission is not accessible to another entrant", async function() {
		let submissionAccessibleToOther = await round.submissionIsAccessible.call(0, {from: accounts[1]});
		assert.isFalse(submissionAccessibleToOther, "Submission is accessible to peer during round. Bad");
	});

	it("Submission is accessible to tournament owner", async function() {
		platform.enterTournament(tournament.address, {from: accounts[1]});
		await tournament.createSubmission("submission2", accounts[0], "external address", ["0x0"], ["0x0"], false, {from: accounts[1]});
		let submissionAccessibleToTournamentOwner = await round.submissionIsAccessible.call(1);
		
		assert.isTrue(submissionAccessibleToTournamentOwner, "Submission is not accessible to tournament owner");
	});

	it("Submission is externally accessible", async function() {
		// Theo enters the tournament and makes a submission
		platform.enterTournament(tournament.address, {from: accounts[3]});
		await tournament.createSubmission("submission3", accounts[3], "external address", ["0x0"], ["0x0"], true, {from: accounts[3]});

		// Can Timmy access it?
		let submissionAccessibleToTimmy = await round.submissionIsAccessible.call(2, {from: accounts[2]});

		assert.isTrue(submissionAccessibleToTimmy, "Submission is not accessible to Timmy");
	});

	// TODO: Change this so tournament chooses winner.
	it("Submission is requested by peer after round has ended", async function() {
		await tournament.chooseWinner(0);

		let firstSubmissionAccessibleToPeer = await round.submissionIsAccessible.call(0, {from: accounts[3]});

		assert.isTrue(firstSubmissionAccessibleToPeer, "Submission is not accessible to peer in tournament");
	});

	it("Submission is requested by Fred (non-entrant) during tournament", async function() {
		let firstSubmissionAccessibleToFred = await round.submissionIsAccessible.call(0, {from: accounts[4]});

		assert.isFalse(firstSubmissionAccessibleToFred, "Submission is not accessible to Fred after tournament close");
	});

	it("Submission is requested by Fred (non-entrant) after tournament has ended", async function() {
		await tournament.closeTournament(0);

		let firstSubmissionAccessibleToFred = await round.submissionIsAccessible.call(0, {from: accounts[4]});

		assert.isTrue(firstSubmissionAccessibleToFred, "Submission is not accessible to Fred after tournament close");
	});
});

contract('MatryxPlatform', function(accounts)
{
	let platform;
	let tournament;
	let round;
	let winningSubmissionAddress;

	it("The number of submissions is 0.", async function() {
		platform = await MatryxPlatform.deployed();
		let tournamentCreationTx = await platform.createTournament("tournament", "external address", 100, 2);
		let tournamentAddress = tournamentCreationTx.logs[0].args._tournamentAddress;
      	tournament = await MatryxTournament.at(tournamentAddress);

      	await tournament.openTournament();
      	platform.enterTournament(tournamentAddress);
      	await tournament.createRound(5);
	    let roundAddress = await tournament.rounds.call(0);
	    round = await MatryxRound.at(roundAddress);
	    await round.Start(0);

	    let numberOfSubmissions = await round.numberOfSubmissions.call();

	    assert.equal(numberOfSubmissions, 0, "There were submissions before we created any");
	});

	it("Particular submissions are gettable.", async function() {
		await tournament.createSubmission("submission1", accounts[0], "external address 1", ["0x0"], ["0x0"], false);
		let firstSubmissionAddress = await round.getSubmissionAddress.call(0);
		assert.isNotNull(firstSubmissionAddress, "Nothing was returned when looking up the submission address.");
	});

	it("All submissions are gettable.", async function() {
		await tournament.createSubmission("submission2", accounts[0], "external address 2", ["0x0"], ["0x0"], false);
		let submissionAddresses = await round.getSubmissions.call();
		assert.isNotNull(submissionAddresses[1], "There were no submissions in the round after calling tournament.createSubmission");
	});

	it("External address of submission is gettable.", async function() {
		let externalAddress = await round.getSubmissionBody.call(0);
		externalAddress = web3.toAscii(externalAddress).replace(/\u0000/g, "");
		assert.equal(externalAddress, "external address 1", "The fetched external address was not equal to 'external address 1'");
	});

	it("Author of submission is gettable.", async function() {
		let submissionAuthor = await round.getSubmissionAuthor.call(0);
		assert.equal(submissionAuthor, accounts[0], "The author of submission 1 is not accounts[0].");
	});

	// TODO: Change this so that tournament chooses winner.
	it("Balance of a submission is gettable.", async function() {
		await tournament.chooseWinner(1);
		winningSubmissionAddress = await round.getSubmissionAddress.call(1);
		let submissionBalance = await round.getBalance.call(winningSubmissionAddress);
		assert.equal(submissionBalance, 5, "Balance of winning submission was not equal to round bounty");
	});

	it("Index of winning submission is gettable.", async function() {
		let indexOfWinningSubmission = await round.getWinningSubmissionIndex.call();
		assert.equal(indexOfWinningSubmission.valueOf(), 1, "Index of winning submission was not 1");
	});
});