var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxPlatform', function(accounts){

  let platform;
  let tournament;
  let token;
  let gasEstimate;

  it("The owner of the platform should be the creator of the platform", async function() {
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
      web3.eth.defaultAccount = web3.eth.accounts[0];

      //get gas estimate for creating peers
      gasEstimate = await platform.createPeer.estimateGas();
      console.log("gasEstimate: " + gasEstimate);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      gasEstimate = await token.releaseTokenTransfer.estimateGas();
      console.log("gasEstimate: " + gasEstimate);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      console.log("gasEstimate: " + gasEstimate);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      gasEstimate = Math.ceil(gasEstimate * 1.3);
      console.log("gasEstimate * constant: " + gasEstimate);

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

      //check who owns the tournament
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

    //get gas estimate for opening tournament
    gasEstimate = await tournament.openTournament.estimateGas();
    console.log("gasEstimate: " + gasEstimate);
    //gas estimate underestimates slightly for openTournament, multiply by some constant ~1.3
    gasEstimate = Math.ceil(gasEstimate * 1.3);
    console.log("gasEstimate * constant: " + gasEstimate);

    //open the tournament
    let openTournamentTx = await tournament.openTournament({gas: gasEstimate});
  });

  it("Tournament.chooseWinner should invoke a TournmamentClosed event.", async function() {
    platform.TournamentClosed().watch((error, result) => {
      if(!error) {
        assert.equal(winningSumbissionAddress, submissionAddress, "The winning submission index should be 1");
      } else {
        assert.false();
      }
    });

    //get gas estimate for opening tournament
    gasEstimate = await tournament.openTournament.estimateGas();
    console.log("gasEstimate: " + gasEstimate);

    //open tournament
    let tournamentOpen = await tournament.openTournament();

    //get gas estimate for entering tournament
    gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);
    console.log("gasEstimate: " + gasEstimate);

    //enter tournament
    let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

    //create and start round
    let roundAddress = await tournament.createRound(5);

    round = await tournament.currentRound();
    roundAddress = round[1];

    //get gas estimate for starting round
    gasEstimate = await tournament.startRound.estimateGas(10, 10);
    console.log("gasEstimate: " + gasEstimate);

    await tournament.startRound(10, 10, {gas: gasEstimate});
    round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

    //open round
    let roundOpen = await round.isOpen();

    //get gas estimate for creating submission
    gasEstimate = await tournament.createSubmission.estimateGas("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"]);
    console.log("gasEstimate: " + gasEstimate);
    //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
    gasEstimate = Math.ceil(gasEstimate * 1.3);
    console.log("gasEstimate * constant: " + gasEstimate);

    //create submission
    let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
    let submissionAddress = submissionCreated.logs[0].args._submissionAddress;

    //choose winner
    let closeTournamentTx = await tournament.chooseWinner(submissionAddress);
    let winningSumbissionAddress = closeTournamentTx.logs[0].args._submissionAddress;
  });
});

contract('MatryxPlatform', function(accounts) {
	let platform;
  let token;
	var createTournamentTransaction;
  var tournamentAddress;
  let gasEstimate;

  it("The number of tournaments should be 0.", function() {
    return MatryxPlatform.deployed().then(function(instance) {
      return instance.tournamentCount();
    }).then(function(count) {
      assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
    });
  });

  it("The number of tournaments should be 1", async function() {
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
      web3.eth.defaultAccount = web3.eth.accounts[0];

      //get gas estimate for creating peers
      gasEstimate = await platform.createPeer.estimateGas();
      console.log("gasEstimate: " + gasEstimate);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      gasEstimate = await token.releaseTokenTransfer.estimateGas();
      console.log("gasEstimate: " + gasEstimate);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      console.log("gasEstimate: " + gasEstimate);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      gasEstimate = Math.ceil(gasEstimate * 1.3);
      console.log("gasEstimate * constant: " + gasEstimate);

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
    await token.mint(web3.eth.accounts[0], 100*10**18)
    await token.approve(MatryxPlatform.address, 100*10**18)

    //get gas estimate for creating tournament
    gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
    console.log("gasEstimate: " + gasEstimate);
    //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
    gasEstimate = Math.ceil(gasEstimate * 1.3);
    console.log("gasEstimate * constant: " + gasEstimate);

    // create a tournament
    createTournamentTransaction = await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {gas: gasEstimate});

    let tournamentCount = await platform.tournamentCount();
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

  it("Able to get top category.", async function() {
      let topCategory = await platform.getTopCategory(0);
      console.log(topCategory);
      assert.equal(topCategory, "category", "Did not get the top category of the platform");
   });

  it("Able to set submission gratitude.", async function() {
      await platform.setSubmissionGratitude(10);
      let gratitude = await platform.getSubmissionGratitude();
      assert.equal(gratitude, 10, "Submission gratitude is not equal to 10");
   });
});

contract('MatryxPlatform', async function(accounts)
{
  let platform;
  let createTournamentTransaction;
  let tournamentAddress;
  let tournament;
  let token;
  let gasEstimate;

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
  let token;

  it("One person becomes an entrant in a tournament", async function()
  {
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
      web3.eth.defaultAccount = web3.eth.accounts[0];

      //get gas estimate for creating peers
      gasEstimate = await platform.createPeer.estimateGas();
      console.log("gasEstimate: " + gasEstimate);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      gasEstimate = await token.releaseTokenTransfer.estimateGas();
      console.log("gasEstimate: " + gasEstimate);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      console.log("gasEstimate: " + gasEstimate);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      gasEstimate = Math.ceil(gasEstimate * 1.3);
      console.log("gasEstimate * constant: " + gasEstimate);

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

      //open the tournament
      let tournamentOpen = await tournament.openTournament();

    //get gas estimate for become entrant in tournament
    gasEstimate = platform.enterTournament.estimateGas(tournamentAddress);
    console.log("gasEstimate: " + gasEstimate);

    // become entrant in tournament
    let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});
    let isEntrant = await tournament.isEntrant.call(accounts[0]);
    assert.equal(isEntrant.valueOf(), true, "The first account should be entered into the tournament.")
  });

  it("Another person becomes an entrant in the tournament", async function()
  {
    // become entrant in tournament
    let enteredTournament = await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});
    let isEntrant = await tournament.isEntrant.call(accounts[1]);
    assert.equal(isEntrant.valueOf(), true, "The second account should be entered into the tournament.")
  })

  it("The third account was not entered into the tournament", async function()
  {
    let isEntrant = await tournament.isEntrant.call(accounts[2]);
    assert.equal(isEntrant.valueOf(), false, "The third account should not be entered into the tournament");
  })

});