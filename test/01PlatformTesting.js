var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");

contract('MatryxPlatform', function(accounts){

  let platform;
  let tournament;

  it("The owner of the platform should be the creator of the platform", async function() {
      platform = await MatryxPlatform.deployed();
      // create a tournament
      createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
      // get the tournament address
      tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;
      // create tournament from address
      tournament = await MatryxTournament.at(tournamentAddress);

      let creatorIsOwner = await tournament.isOwner.call(accounts[0]);
      assert(creatorIsOwner.valueOf(), true, "The owner and creator of the tournament should be the same"); 
  });

  it("Tournament.openTournament should invoke a TournamentOpened event.", async function() {

    // Start watching the platform events before we induce the one we're looking for.
    platform.TournamentOpened().watch((error, result) => {
                if (!error) {
                        assert.equal(result.args._tournamentName, "tournament", "The name of the tournament should be 'tournament'");
                } else {
                        assert.false();
                }
    });

    let openTournamentTx = await tournament.openTournament();
  });

  it("Tournament.chooseWinner should invoke a TournmamentClosed event.", async function() {
    platform.TournamentClosed().watch((error, result) => {
      if(!error) {
        assert.equal(result.args._winningSubmissionIndex.valueOf(), 0, "The winning submission index should be 1");
      } else {
        assert.false();
      }
    });

    await platform.enterTournament(tournament.address);
    await tournament.createRound(5);
    let roundAddress = await tournament.rounds.call(0);
    let round = await MatryxRound.at(roundAddress);
    await round.Start(0);
    await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], false);
    let closeTournamentTx = await tournament.chooseWinner(0);
  });
});

contract('MatryxPlatform', function(accounts) {
	let platform;
	var createTournamentTransaction;
  var tournamentAddress;

  it("The number of tournaments should be 0.", function() {
    return MatryxPlatform.deployed().then(function(instance) {
      return instance.tournamentCount();
    }).then(function(count) {
      assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
    });
  });

  it("The number of tournaments should be 1", async function() {
    platform = await MatryxPlatform.deployed();
    createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
    tournamentAddress = createTournamentTransaction.logs[0].args._tournamentAddress;

    let tournamentCount = await platform.tournamentCount();
    // assert there should be one tournament
    assert.equal(tournamentCount.valueOf(), 1, "The number of tournaments should be 1.");
  })

  // TODO: Discuss getters with Sam. Bring up suggestion: see if we have room for them after reputation system integration.
  // it("The created tournament should be addressable from the platform", async function() {
    
  //     createTournamentTransaction = await platform.createTournament("tournament", "external address", 100, 2);
  //     var storedExternalAddress = await platform.getTournament_ExternalAddress.call(createTournamentTransaction.logs[0].args._tournamentAddress);
  //     storedExternalAddress = web3.toAscii(storedExternalAddress).replace(/\u0000/g, "");
  //     let externalAddressFromEvent = web3.toAscii(createTournamentTransaction.logs[0].args._externalAddress).replace(/\u0000/g, "")
  //     return assert.equal(externalAddressFromEvent, storedExternalAddress);
  //   });

  it("The number of tournaments should be 2", async function() {
    createTournamentTransaction = await platform.createTournament("tournament 2", "external address", 100, 2);
    let tournamentCount = await platform.tournamentCount.call();
    assert.equal(tournamentCount.valueOf(), 2, "The number of tournaments should be 2.");
  })

  it("The first tournament should be mine", async function() {
    let firstTournamentIsMine = await platform.getTournament_IsMine.call(tournamentAddress);
    assert.isTrue(firstTournamentIsMine, "The first tournament does not belong to accounts[0]");
  })

  it("The address of the first tournament should be the TournamentCreated event address", async function() {
    let lookupFirstTournamentAddress = await platform.getTournamentAtIndex.call(0);
    assert.equal(tournamentAddress, lookupFirstTournamentAddress.valueOf(), "Addresses inconsistent for tournament.");
  })
});

contract('MatryxPlatform', async function(accounts)
{
  let platform;
  let createTournamentTransaction;
  let tournamentAddress;
  let tournament;

  var queryID = 0;

  // get the platform
  platform = await MatryxPlatform.deployed();

  it("The balance of the first account is non-zero", async function() {
    let prepareBalanceTx = await platform.prepareBalance(0x0);
    queryID = prepareBalanceTx.logs[0].args.id;
    let storeQueryResponseTx = await platform.storeQueryResponse(queryID, 1);
    //let response = storeQueryResponseTx.logs[0].args.storedResponse;
    let balanceIsNonZero = await platform.balanceIsNonZero();
    console.log("balance not zero?: " + balanceIsNonZero);
    assert.isTrue(balanceIsNonZero.valueOf(), "Balance should be non-zero");
  });

  it("The balance of the first account has already been set. Re-storing is unsuccessful", async function() {
    let queryResponseStoreSuccessTx = await platform.storeQueryResponse(queryID, 5);
    assert.isNotNull(queryResponseStoreSuccessTx.logs['FailedToStore'], "The balance of the first account was reset");
  });
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
    tournament = await MatryxTournament.at(tournamentAddress);

    // become entrant in tournament
    let platformAddress = await tournament.platformAddress.call();
    await platform.enterTournament(tournamentAddress);
    let isEntrant = await tournament.isEntrant.call(accounts[0]);
    assert.equal(isEntrant.valueOf(), true, "The first account should be entered into the tournament.")
  });

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