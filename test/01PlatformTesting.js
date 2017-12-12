var MatryxPlatform = artifacts.require("MatryxPlatform");
var Tournament = artifacts.require("Tournament");
var Submission = artifacts.require("Submission");

contract('MatryxPlatform', function(accounts)
{
  it("The owner of the platform should be the creator of the platform", async function() {
      let platform = await MatryxPlatform.deployed();
      // create a tournament
      createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
      // get the tournament address
      tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
      // create tournament from address
      let tournament = await Tournament.at(tournamentAddress);

      let creatorIsOwner = await tournament.isOwner.call(accounts[0]);
      assert(creatorIsOwner.valueOf(), true, "The owner and creator of the tournament should be the same"); 
  });
});

contract('MatryxPlatform', function(accounts)
{
	it("The number of tournaments should be 0.", function() {
    return MatryxPlatform.deployed().then(function(instance) {
      return instance.tournamentCount();
    }).then(function(count) {
    	assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
    });
  });
});

contract('MatryxPlatform', function(accounts) {
	let platform;
	var createTournamentTransaction;
	let tournamentAddress;
  it("The number of tournaments should be 1", async function() {
    platform = await MatryxPlatform.new();
    createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
    let tournamentCount = await platform.tournamentCount();
    tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
    // assert there should be one tournament
    assert.equal(tournamentCount.valueOf(), 1, "The number of tournaments should be 1.");
  })
});

contract('MatryxPlatform', function(accounts)
{
	var tournamentAddress;
	it("The created tournament should be addressable", function() {
		return MatryxPlatform.deployed().then(function(instance) {
        return instance.createTournament("tournament", "external address", 100, 2);
    }).then(function(result)
    {
      return result.logs[0].args._externalAddress;
    }).then(function(externalAddress){
      return assert.equal(web3.toAscii(externalAddress).replace(/\u0000/g, ""), "external address");
    });
		// createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
		// tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
		// //assert.equal(tournamentAddress, "0x123", "The address of the tournament is not 0x123");
		// let externalAddress = await platform.tournamentByAddress.call(tournamentAddress);
		// assert.equal(externalAddress, "external address", "The external address was not 'external address'");
	})
});

contract('MatryxPlatform', function(accounts)
{
  it("First submission owner is tournament owner", async function() {
    // get the platform
    let platform = await MatryxPlatform.deployed();
    // create a tournament
    createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
    // get the tournament address
    tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

    // create tournament from address
    let tournament = await Tournament.at(tournamentAddress);
    
    // become entrant to tournament
    await platform.enterTournament(tournamentAddress);
    await tournament.createSubmission("submission1", "external address", ["0x0"], ["0x0"]);

    let mySubmissions = await tournament.mySubmissions.call();
    // create the submission in tournament
    let submissionOne = await Submission.at(mySubmissions[0]);
    let submissionOwner = await submissionOne.getSubmissionOwner.call();

    // check that we're both the tournament and submission owner
    assert.equal(submissionOwner, accounts[0], "The owner of the submission should be the owner of the tournament");
  });
});