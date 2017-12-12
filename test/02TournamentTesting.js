var MatryxPlatform = artifacts.require("MatryxPlatform");
var TournamentContract = artifacts.require("Tournament");
var Submission = artifacts.require("Submission");


//TEST

//TODO Move this static test information to a different file to be referenced
let _tournamentOwner = "0x1123456789012345678901234567890123456789"
let _tournamentName = "Design a Silly Mug"
let _tournamentDescription = "Infuse creativity and character into making a coffee mug using Calcflow. In VR, there are no limitations... take that, Gravity! Explore the curious flexibility of parametric equations."
let _externalAddress = "0x1123456789012345678901234567890123456789"
let _MTXReward = 1000
let _entryFee = 10

let _name = "Submission 1"
let _references = ["0x1","0x2"]
let _contributors = ["0x1","0x2"]


contract('Tournament', function(accounts) {


    it("Deploy the tournament from the platform", async function() {

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
    it("No existing Submissions", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 0)
    })

    // Create a Submission
    it("Submission created", async function() {

        //Enter the tournament and create a submission
        await platform.enterTournament(tournamentAddress);
        await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);

        //Check to make sure the submission count is updated
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 1)
    })

    it("There is 1 Submissions", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions, 1)
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

    // //TODO Migrate platformCode
    // it("Migrate to the new Platform", async function() {
    //     migratedPlatform = await tournament.upgradePlatform("0x1123456789012345678901234567890123456789")
    //     numberOfSubmissions = await tournament.submissionCount()
    //     assert.equal(numberOfSubmissions, 0)
    // })







    // Get Submission details
    // List of all submissions
    //

})


