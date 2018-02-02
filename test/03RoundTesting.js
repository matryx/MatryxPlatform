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
	})

	it("Submission is accessible to tournament owner", async function() {
		platform.enterTournament(tournament.address, {from: accounts[1]});
		await tournament.createSubmission("submission2", accounts[0], "external address", ["0x0"], ["0x0"], false, {from: accounts[1]});
		let submissionAccessibleToTournamentOwner = await round.submissionIsAccessible.call(1);
		
		assert.isTrue(submissionAccessibleToTournamentOwner, "submission is not accessible to tournament owner");
	})

	it("Submission is externally accessible", async function() {
		// Theo enters the tournament and makes a submission
		platform.enterTournament(tournament.address, {from: accounts[3]});
		await tournament.createSubmission("submission3", accounts[3], "external address", ["0x0"], ["0x0"], true, {from: accounts[3]});

		// Can Timmy access it?
		let submissionAccessibleToTimmy = await round.submissionIsAccessible.call(2, {from: accounts[2]});

		assert.isTrue(submissionAccessibleToTimmy, "Submission is not accessible to Timmy");
	})

	it("Submission is requested by peer after round has ended", async function() {
		await round.chooseWinningSubmission(0);

		let firstSubmissionAccessibleToPeer = await round.submissionIsAccessible.call(0, {from: accounts[3]});

		assert.isTrue(firstSubmissionAccessibleToPeer, "Submission is not accessible to peer in tournament");
	})
});