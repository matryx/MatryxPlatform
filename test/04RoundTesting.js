let MatryxPlatform = artifacts.require("MatryxPlatform");
let MatryxTournament = artifacts.require("MatryxTournament");
let MatryxRound = artifacts.require("MatryxRound");
let MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxPlatform', function(accounts)
{
	let platform;
	let tournament;
	let round;
	let token;

	it("Submission is accessible to creator", async function() {
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
      // create a tournament.
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

    	//create submission
    	let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: 3000000});
    	let submissionAddress = submissionCreated.logs[0].args._submissionAddress;

	    let submissionIsAccessible = await round.submissionIsAccessible.call(0);

	    assert.isTrue(submissionIsAccessible, "Submission is not accessible to its creator");
	});

	it("Submission is not accessible to another entrant", async function() {
		let submissionAccessibleToOther = await round.submissionIsAccessible.call(0, {from: accounts[1]});
		assert.isFalse(submissionAccessibleToOther, "Submission is accessible to peer during round. Bad");
	});

	it("Submission is accessible to tournament owner", async function() {
		let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: 3000000});
		let submission2 = await tournament.createSubmission("submission2", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1]});
		let submissionAccessibleToTournamentOwner = await round.submissionIsAccessible.call(1);
		
		assert.isTrue(submissionAccessibleToTournamentOwner, "Submission is not accessible to tournament owner");
	});

	it("Submission is not externally accessible", async function() {
		// Theo enters the tournament and makes a submission
		let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[3], gas: 3000000});
		let submissionTheo = await tournament.createSubmission("submission3", accounts[3], "external address", ["0x0"], ["0x0"], ["0x0"], {from: accounts[3], gas: 3000000});
		console.log(submissionTheo.logs[0].args);

		let accessible = await round.submissionIsAccessible.call(0, {from: accounts[3]});
		console.log(accessible);

		// Can Timmy access it?
		let submissionAccessibleToTimmy = await round.submissionIsAccessible.call(2, {from: accounts[2]});

		assert.isFalse(submissionAccessibleToTimmy, "Submission is accessible to Timmy");
	});

  it("Submission is requested by Fred (non-entrant) during tournament", async function() {
    let firstSubmissionAccessibleToFred = await round.submissionIsAccessible.call(0, {from: accounts[4]});

    assert.isFalse(firstSubmissionAccessibleToFred, "Submission is not accessible to Fred during tournament");
  });

	it("Submission is requested by peer after round has ended", async function() {
    let mySubmissions = await tournament.mySubmissions.call();
    let mySubmissionAddress = await round.getSubmissionAddress.call(0);

    //close tournament
    let closeTournamentTx = await tournament.chooseWinner(mySubmissionAddress);

    let isTournamentOpen = await tournament.isOpen();
    console.log(isTournamentOpen);

		let firstSubmissionAccessibleToPeer = await round.submissionIsAccessible.call(0, {from: accounts[3]});

		assert.isTrue(firstSubmissionAccessibleToPeer, "Submission is not accessible to peer in tournament");
	});

	it("Submission is requested by Fred (non-entrant) after tournament has ended", async function() {
    let isTournamentOpen = await tournament.isOpen();
    console.log(isTournamentOpen);

		let firstSubmissionAccessibleToFred = await round.submissionIsAccessible.call(0, {from: accounts[4]});

		assert.isTrue(firstSubmissionAccessibleToFred, "Submission is not accessible to Fred after tournament close");
	});
});

contract('MatryxPlatform', function(accounts)
{
	let platform;
	let tournament;
	let round;
	let token;

	it("The number of submissions is 0.", async function() {
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

    	//get number of submissions
	    let numberOfSubmissions = await round.numberOfSubmissions.call();

	    assert.equal(numberOfSubmissions, 0, "There were submissions before we created any");
	});

	it("Particular submissions are gettable.", async function() {
		let firstSubmission = await tournament.createSubmission("submission1", accounts[0], "external address 1", ["0x0"], ["0x0"], ["0x0"]);
		let firstSubmissionAddress = await round.getSubmissionAddress.call(0);
		assert.isNotNull(firstSubmissionAddress, "Nothing was returned when looking up the submission address.");
	});

	it("All submissions are gettable.", async function() {
		let secondSubmission = await tournament.createSubmission("submission2", accounts[0], "external address 2", ["0x0"], ["0x0"], ["0x0"]);
		let submissionAddresses = await round.getSubmissions.call();
		assert.isNotNull(submissionAddresses[1], "There were no submissions in the round after calling tournament.createSubmission");
	});

	it("Author of submission is gettable.", async function() {
		let submissionAuthor = await round.getSubmissionAuthor.call(0);
    peerAddress = await platform.peerAddress(accounts[0]);
		assert.equal(submissionAuthor, peerAddress, "The author of submission 1 is not accounts[0]'s peer.");
	});

	it("Balance of a submission is gettable.", async function() {
		let winningSubmissionAddress = await round.getSubmissionAddress.call(1);
    //close tournament
		await tournament.chooseWinner(winningSubmissionAddress);
		let submissionBalance = await round.getBalance.call(winningSubmissionAddress);
		assert.equal(submissionBalance, 5, "Balance of winning submission was not equal to round bounty");
	});

	it("Address of winning submission is gettable.", async function() {
    let chosenWinner = round.getSubmissionAddress.call(1);
		let winningSubmissionAddress = await round.getWinningSubmissionAddress.call();
		assert.equal(winningSubmissionAddress, chosenWinner, "Index of winning submission was not 1");
	});
});