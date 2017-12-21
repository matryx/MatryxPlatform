var MatryxPlatform = artifacts.require("MatryxPlatform");
var TournamentContract = artifacts.require("Tournament");

contract('Tournament', function(accounts) {
    var platform;
    var tournament;

    it("Created tournament should exist", async function() {

        platform = await MatryxPlatform.deployed();
        // create a tournament.
        createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
        // get the tournament address
        tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
        // create tournament from address
        tournament = await TournamentContract.at(tournamentAddress);

        if(tournament){
            tournamentExists = true
        } else{
            tournamentExists = false
        }

        assert.equal(tournamentExists, true)
    })

    // There should be no existing submissions
    it("There are no existing submissions", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 0)
    })

    it("The tournament is open", async function() {
        await tournament.openTournament();
        // the tournament should be open 
        let tournamentOpen = await tournament.tournamentOpen.call();
        // assert that the tournament is open
        assert.equal(tournamentOpen.valueOf(), true, "The tournament should be open.");
    });

    // Create a Submission
    it("A submission was created", async function() {
        // create submission
        await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);
        //Check to make sure the submission count is updated
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 1)
    })

    it("There is 1 Submission", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 1)
    })

    // TODO: Update when logic becomes more fleshed out
    it("Update the public submissions for the previous round", async function() {
        await tournament.updatePublicSubmissions();
        assert.equal(true, true, "always true for now");
    })

    it("This is the owner", async function() {
        ownerBool = await tournament.isOwner(accounts[0])
        assert.equal(ownerBool, true)
    })

    it("This is NOT the owner", async function() {
        ownerBool = await tournament.isOwner("0x0")
        assert.equal(ownerBool, false)
    })

    it("The Tournament is open", async function() {
        isTournamentOpen = await tournament.tournamentOpen()
        assert.equal(isTournamentOpen, true)
    })

    it("Return the external address", async function() {
        gotExternalAddress = await tournament.getExternalAddress()
        return assert.equal(web3.toAscii(gotExternalAddress).replace(/\u0000/g, ""), "external address");
    })

    it("Return entry fees", async function() {
        getEntryFees = await tournament.getEntryFee()
        assert.equal(getEntryFees, 2)
    })

    // TODO: Update when logic is more fleshed out.
    it("The tournament is closed", async function() {
        await tournament.chooseWinner();
        // the tournament should be open 
        let tournamentOpen = await tournament.tournamentOpen.call();
        // assert that the tournament is open
        assert.equal(tournamentOpen.valueOf(), false, "The tournament should be open.");
    });

    it("String is empty", async function() {
        let stringEmptyBool = await tournament.stringIsEmpty("");
        assert.equal(stringEmptyBool, true, "stringIsEmpty function should say string is empty");
    });

    // //TODO Migrate platformCode
    // it("Migrate to the new Platform", async function() {
    //     migratedPlatform = await tournament.upgradePlatform("0x1123456789012345678901234567890123456789")
    //     numberOfSubmissions = await tournament.submissionCount()
    //     assert.equal(numberOfSubmissions, 0)
    // })


})