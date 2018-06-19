let MatryxPlatform = artifacts.require("MatryxPlatform");
let MatryxPeer = artifacts.require("MatryxPeer");
let MatryxTournament = artifacts.require("MatryxTournament");
let MatryxRound = artifacts.require("MatryxRound");
let MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxSubmission', function(accounts)
{
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let round;
   	let roundAddress;
    let submissionOne;
    let submissionTwo;
    let submissionOneBlocktime;
    let token;
    //for code coverage
    let gasEstimate = 30000000;

    //for regular testing
    //let gasEstimate = 3000000;

    it("Submission one owner is submission creator", async function() {
    	web3.eth.defaultAccount = web3.eth.accounts[0];
	  //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

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
      let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

      //create and start round
      roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

      //open round
      let roundOpen = await round.isOpen();

      //create submission
      let submissionOneTx = await tournament.createSubmission("submission1", accounts[0], "external address 1", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});

	  let blocknumber = await web3.eth.getTransaction(submissionOneTx.tx).blockNumber;
	  submissionOneBlocktime = await web3.eth.getBlock(blocknumber).timestamp;

	  //get my submissions
	  let mySubmissions = await tournament.mySubmissions.call();
	  //get submission one
	  submissionOne = await MatryxSubmission.at(mySubmissions[0]);
	  let submissionOwner = await submissionOne.owner.call();

	  //check that we're both the tournament and submission owner
	  assert.equal(submissionOwner, accounts[0], "The owner of the submission should be the owner of the tournament");
	});

  it("Submission two owner is submission creator", async function() {
    let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});
    	//create submission
		await tournament.createSubmission("submission2", accounts[1], "external address 2", ["0x0"], ["0x0"], ["0x0"], {from: accounts[1], gas: gasEstimate});

		let mySubmissions = await tournament.mySubmissions.call({from: accounts[1]});
		//get submission
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

	it("Able to get tournament address.", async function() {
    	let tournammentAddressFromSubmission = await submissionOne.getTournament();
    	assert.equal(tournammentAddressFromSubmission, tournamentAddress, "Did not get the tournamment address correctly.");
  	});

	it("Able to get round address.", async function() {
    	let roundAddressFromSubmisison = await submissionOne.getRound();
    	assert.equal(roundAddressFromSubmisison, roundAddress, "Did not get the tournamment address correctly.");
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

	/** Testing methods from Submission Trust **/
	it("Able create a submission with a reference to an existing submission", async function() {
		let referencesArray = [submissionTwo.address];
		//create submission with references
		await tournament.createSubmission("submission3", accounts[0], "external address 3", ["0x0"], ["0x0"], referencesArray, {gas: gasEstimate});
		
		let mySubmissions = await tournament.mySubmissions.call();
		//get submission
		submissionThree = await MatryxSubmission.at(mySubmissions[1]);
		//get the references
		let references = await submissionThree.getReferences.call();
		console.log("references: " + references);
		assert.equal(references[0], submissionTwo.address, "Submission did not have the correct references after being created.");
	})

	it("Able to add to a submission's references", async function() {
		let addReference = await submissionOne.addReference(submissionTwo.address, {gas: gasEstimate});
		console.log("addReference: " + addReference.logs);
		let references = await submissionOne.getReferences.call();
		console.log("references: " + references);
		assert.equal(references[1], submissionTwo.address, "References on submission not updated correctly");
	})

	it("Able to withdraw reward", async function() {
		let reward = await submissionOne.withdrawReward.call(accounts[0]);
		console.log("reward: " + reward);
		assert.equal(reward, 0, "Was not able to withdraw reward.");
	})

	it("Able to delete a submission's references", async function() {
		let removeReference = await submissionOne.removeReference(submissionTwo.address, {gas: gasEstimate});
		console.log("removeReference: " + removeReference.logs[0]);
		let references = await submissionOne.getReferences.call();
		console.log("references: " + references);
		assert.equal(references[1], 0, "Removed reference was not null");
	})

	it("Able to add to a submission's contributors", async function() {
		await submissionOne.addContributor(accounts[6], 100, {gas: gasEstimate});
		let contributors = await submissionOne.getContributors.call();
		assert.equal(contributors[1], accounts[6], "References on submission not updated correctly");
	})

	it("Able to delete a submission's contributors", async function() {
		await submissionOne.removeContributor(1, {gas: gasEstimate});
		let contributors = await submissionOne.getContributors.call();
		assert.equal(contributors[1], 0, "Removed reference was not null");
	})

	it("Able to read a submission's balance", async function() {
		let balance = await submissionOne.getBalance.call();
		assert.equal(balance, 0, "Submission's balance was not zero.");
	})

	it("Able to get transfer amount", async function() {
		let transferAmount = await submissionOne.getTransferAmount.call();
		console.log("transferAmount: " + transferAmount);
		assert.equal(transferAmount, 0, "Submission's transfer amount was not zero.");
	})
	
});

