var MatryxPlatform = artifacts.require("MatryxPlatform");
var Tournament = artifacts.require("Tournament");

contract('MatryxPlatform', function(accounts){
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

contract('MatryxPlatform', async function(accounts) {

  let platform = await MatryxPlatform.new();
  createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
  tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
  let tournament = await Tournament.at(tournamentAddress);

  it("Tournament.openTournament should invoke a TournamentOpened event.", async function() {

    // Start watching the platform events before we induce the one we're looking for.
    platform.TournamentOpened().watch((error, result) => {
                if (!error) {
                        assert.equal(result.args._tournamentName, "tournament", "The name of the tournament should be 'justOpenedTournament'");
                } else {
                        assert.false();
                }
    });

    let openTournamentTx = await tournament.openTournament();
  });

  it("Tournament.chooseWinner should invoke a TournmamentClosed event.", async function() {
    platform.TournamentClosed().watch((error, result) => {
      if(!error) {
        assert.equal(result.args._submissionIndex_winner, 123, "The winning submission index should be 123");
      } else {
        assert.false();
      }
    });

    let closeTournamentTx = await tournament.chooseWinner(1, 1);
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

  it("The number of tournaments should be 1", async function() {
    platform = await MatryxPlatform.deployed();
    createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
    let tournamentCount = await platform.tournamentCount();
    // assert there should be one tournament
    assert.equal(tournamentCount.valueOf(), 1, "The number of tournaments should be 1.");
  })

  it("The created tournament should be addressable from the platform", async function() {
    
      createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
      var storedExternalAddress = await platform.getTournament_ExternalAddress.call(createTournamentTransaction.logs[0].args._tournamentAddress);
      storedExternalAddress = web3.toAscii(storedExternalAddress).replace(/\u0000/g, "");
      let externalAddressFromEvent = web3.toAscii(createTournamentTransaction.logs[0].args._externalAddress).replace(/\u0000/g, "")
      return assert.equal(externalAddressFromEvent, storedExternalAddress);
    });

  it("The number of tournaments should be 3", async function() {
    createTournamentTransaction = await platform.createTournament("tournament 3", "external address", 100, 2);
    let tournamentCount = await platform.tournamentCount.call();

    assert.equal(tournamentCount.valueOf(), 3, "The number of tournaments should be 3.");
  })
});

contract('MatryxPlatform', async function(accounts)
{
  let platform;
  let createTournamentTransaction;
  let tournamentAddress;
  let tournament;

  var queryID;

  // get the platform
  platform = await MatryxPlatform.deployed();

  it("The balance of the first account is non-zero", async function() {
    let prepareBalanceTx = await platform.prepareBalance(0x0);
    queryID = prepareBalanceTx.logs[0].args.id;
    await platform.storeQueryResponse(queryID, 1);

    let balanceIsNonZero = await platform.balanceIsNonZero.call();
    assert.isTrue(balanceIsNonZero.valueOf(), "Balance should be non-zero");
  });

  it("The balance of the first account has already been set. Re-storing is unsuccessful.", async function() {
    
    let queryResponseStoreSuccessTx = await platform.storeQueryResponse(queryID, 5000);
    assert.isNotNull(queryResponseStoreSuccessTx.logs['FailedToStore'], "The balance of the first account was reset");
  })
});

contract('MatryxPlatform', async function(accounts)
{
  let platform;
  let createTournamentTransaction;
  let tournamentAddress;
  let tournament;

  it("One person becomes an entrant in a tournament", async function()
  {
    // get the platform
    platform = await MatryxPlatform.deployed();
    // create a tournament.
    createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
    // get the tournament address
    tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
    // create tournament from address
    tournament = await Tournament.at(tournamentAddress);

    // become entrant in tournament
    await platform.enterTournament(tournamentAddress);
    let isEntrant = await tournament.isEntrant.call(accounts[0]);
    assert.equal(isEntrant.valueOf(), true, "The first account should be entered into the tournament.")
  })

  it("Another person becomes an entrant in the tournament", async function()
  {
    // become entrant in tournament
    await platform.enterTournament(tournamentAddress, {from: accounts[1]});
    let isEntrant = await tournament.isEntrant.call(accounts[1]);
    assert.equal(isEntrant.valueOf(), true, "The second account should be entered into the tournament.")
  })

  it("The third account was not entered into the tournament", async function()
  {
    let isEntrant = await tournament.isEntrant.call(accounts[2]);
    assert.equal(isEntrant.valueOf(), false, "The third account should not be entered into the tournament");
  })
});