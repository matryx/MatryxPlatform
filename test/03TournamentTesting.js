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

    it("Created tournament should exist", async function() {
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

        //get the tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;

        //create tournament from address
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
        // enter the tournament
        let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: 3000000});
        console.log(enteredTournament);

        let successInEnteringTournamentTwice = await platform.enterTournament.call(tournamentAddress, {gas: 3000000});
        assert.isFalse(successInEnteringTournamentTwice, "Able to enter a tournament twice");
    });

    it("A round is open", async function() {
        // create a round
        let roundAddress = await tournament.createRound(5);

        //get round from address
        round = await tournament.currentRound();
        roundAddress = round[1];

        await tournament.startRound(10, 1, {gas: 3000000});
        round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

        //open the round
        let roundOpen = await round.isOpen();
        console.log(roundOpen);
        assert.isTrue(roundOpen, "No round is open");
    })

    it("The current round is accurate", async function() {
        let currentRound = await tournament.currentRound.call();
        assert.equal(currentRound, "1,"+round.address, "Current round is incorrect");
    })

    // Create a Submission
    it("A submission was created", async function() {
        // create submission
        let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: 5000000});
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
        console.log(numberOfSubmissions);
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
        getEntryFees = await tournament.getEntryFee()
        console.log(getEntryFees);
        assert.equal(getEntryFees, 2)
    });

    it("The tournament is closed", async function() {
        //create submission
        let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: 3000000});
        let submissionAddress = submissionCreated.logs[0].args._submissionAddress;

        let closeTournamentTx = await tournament.chooseWinner(submissionAddress);
        // the tournament should be closed 
        let roundOpen = await round.isOpen();
        console.log(roundOpen);
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