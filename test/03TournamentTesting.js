var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var Ownable = artifacts.require("Ownable");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxTournament', function(accounts) {
    let platform;
    let tournament;
    let round;
    let token;
    let gasEstimate;

    it("Created tournament should exist", async function() {
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
      web3.eth.defaultAccount = web3.eth.accounts[0];

      //get gas estimate for creating peers
      gasEstimate = await platform.createPeer.estimateGas();

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      gasEstimate = await token.releaseTokenTransfer.estimateGas();

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      gasEstimate = Math.ceil(gasEstimate * 1.3);

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
        await tournament.setNumberOfRounds(1);

        if(tournament) {
            tournamentExists = true
        } else{
            tournamentExists = false
        }

        assert.equal(tournamentExists, true)
    });

    // There should be no existing submissions
    it("There are no existing submissions", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 0)
    });

    it("The tournament is open", async function() {
        await tournament.openTournament();
        // the tournament should be open 
        let tournamentOpen = await tournament.tournamentOpen.call();
        // assert that the tournament is open
        assert.equal(tournamentOpen.valueOf(), true, "The tournament should be open.");
    });

    it("A user cannot enter a tournament twice", async function() {
        //get gas estimate for entering tournament
        gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);
        // enter the tournament
        let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

        let successInEnteringTournamentTwice = await platform.enterTournament.call(tournamentAddress, {gas: gasEstimate});
        assert.isFalse(successInEnteringTournamentTwice, "Able to enter a tournament twice");
    });

    it("A round is open", async function() {
        // create a round
        let roundAddress = await tournament.createRound(5);

        //get round from address
        round = await tournament.currentRound();
        roundAddress = round[1];

        //get gas estimate for starting round
        gasEstimate = await tournament.startRound.estimateGas(10, 1);

        //start the round
        await tournament.startRound(10, 1, {gas: gasEstimate});
        round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

        //open the round
        let roundOpen = await round.isOpen();
        assert.isTrue(roundOpen, "No round is open");
    })

    it("The current round is accurate", async function() {
        let currentRound = await tournament.currentRound.call();
        assert.equal(currentRound, "1,"+round.address, "Current round is incorrect");
    })

    // Create a Submission
    it("A submission was created", async function() {
        //get gas estimate for creating submission
        gasEstimate = await tournament.createSubmission.estimateGas("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"]);
        //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
        gasEstimate = Math.ceil(gasEstimate * 1.3);

        // create submission
        let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
        let submissionAddress = submissionCreated.logs[0].args._submissionAddress;

        //Check to make sure the submission count is updated
        numberOfSubmissions = await tournament.submissionCount.call();
        assert.equal(numberOfSubmissions, 1, "The number of submissions should equal one");
    });

    it("I can retrieve my personal submissions", async function() {
        let mySubmissions = await tournament.mySubmissions.call();
        let mySubmissionAddress = await round.getSubmissionAddress.call(0);
        let submissionAsOwnable = Ownable.at(mySubmissionAddress.valueOf());

        let submissionIsMine = await submissionAsOwnable.isOwner.call(accounts[0]);
        assert.isTrue(submissionIsMine, "A submission given in mySubmissions is not one of my submissions.");
    });

    it("There is 1 Submission", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions.valueOf(), 1)
    });

    it("This is the owner", async function() {
        ownerBool = await tournament.isOwner(accounts[0])
        assert.equal(ownerBool, true)
    });

    it("This is NOT the owner", async function() {
        ownerBool = await tournament.isOwner("0x0")
        assert.equal(ownerBool, false)
    });

    it("The Tournament is open", async function() {
        isTournamentOpen = await tournament.tournamentOpen()
        assert.equal(isTournamentOpen, true)
    });

    it("Return the external address", async function() {
        gotExternalAddress = await tournament.getExternalAddress()
        return assert.equal(web3.toAscii(gotExternalAddress).replace(/\u0000/g, ""), "external address");
    });

    it("Return entry fees", async function() {
        getEntryFees = await tournament.getEntryFee();
        assert.equal(getEntryFees.toNumber(), 2*10**18);
    });

    it("The tournament is closed", async function() {
        //get gas estimate for creating submission
        gasEstimate = await tournament.createSubmission.estimateGas("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"]);
        //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
        gasEstimate = Math.ceil(gasEstimate * 1.3);
        //create submission
        let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
        let submissionAddress = submissionCreated.logs[0].args._submissionAddress;

        let closeTournamentTx = await tournament.chooseWinner(submissionAddress);
        // the tournament should be closed 
        let roundOpen = await round.isOpen();
        // assert that the tournament is closed
        assert.equal(roundOpen.valueOf(), false, "The round should be closed.");
    });

    // it("String is empty", async function() {
    //     let stringEmptyBool = await tournament.stringIsEmpty("");
    //     assert.equal(stringEmptyBool, true, "stringIsEmpty function should say string is empty");
    // });

    // //TODO Migrate platformCode
    // it("Migrate to the new Platform", async function() {
    //     migratedPlatform = await tournament.upgradePlatform("0x1123456789012345678901234567890123456789")
    //     numberOfSubmissions = await tournament.submissionCount()
    //     assert.equal(numberOfSubmissions, 0)
    // });

});