var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxPlatform', function(accounts){

  let platform;
  let tournament;
  let token;
  let submissionAddress;
  let gasEstimate = 30000000;
  let hellaGas;

  it("The owner of the platform should be the creator of the platform", async function() {
    hellaGas = 30000000;
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();

      // console.log("MatryxToken.address: " + MatryxToken.address);
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      // console.log("token: " + token);

      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address); 
      let owner = await platform.owner();
      let getOwner = await platform.getOwner();
      let tournamentCount = await platform.tournamentCount();

      let peerAddress = await platform.peerAddress(accounts[0]);
      // console.log("peer address: " + peerAddress);

      // console.log("platform: " + platform);
      await platform.createPeer.sendTransaction({gas: hellaGas});
      // console.log("created frist peer??");
      peerAddress = await platform.peerAddress(accounts[0]);
      // console.log("peer address: " + peerAddress);

      //get gas estimate for creating peers
      // gasEstimate = await platform.createPeer.estimateGas();
      // console.log("gasEstimate: " + gasEstimate);

      //create peers
      await platform.createPeer.sendTransaction({gas: hellaGas, from: web3.eth.accounts[1]});
      // console.log("sencond peer?");
      peerAddress = await platform.peerAddress(accounts[1]);
      // console.log("peer address accounts[1]: " + peerAddress);
      await platform.createPeer.sendTransaction({gas: hellaGas, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: hellaGas, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);
      // console.log("set release agent");

      //get gas estimate for releasing token transfer
      // gasEstimate = await token.releaseTokenTransfer.estimateGas();
      // console.log("gasEstimate: " + gasEstimate);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction();
      // console.log("release token transfer");
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      // console.log("minted all tokens");
      await token.approve(MatryxPlatform.address, 100*10**18)
      // console.log("approved tokens");

      // //get gas estimate for creating tournament
      // gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      // console.log("gasEstimate: " + gasEstimate);
      // //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

      // create a tournament
      createTournamentTransaction = await platform.createTournament("category", "tournament", "external address", 100*10**18, 2*10**18, {gas: hellaGas});
      // console.log("created tournament??? " + createTournamentTransaction);
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
      // console.log("tournamentAddress: " + tournamentAddress);
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

    // //get gas estimate for opening tournament
    // gasEstimate = await tournament.openTournament.estimateGas();
    // console.log("gasEstimate: " + gasEstimate);
    // //gas estimate underestimates slightly for openTournament, multiply by some constant ~1.3
    // gasEstimate = Math.ceil(gasEstimate * 1.3);
    // console.log("gasEstimate * constant: " + gasEstimate);

    //open the tournament
    let openTournamentTx = await tournament.openTournament({gas: gasEstimate});
  });

  it("Tournament should be mine", async function(){
    let isTournamentMine = platform.getTournament_IsMine(tournamentAddress);
    assert.isTrue(isTournamentMine, "Tournament shoud be mine.");
  });

  it("Able to recognize a submission", async function(){
    //open tournament
    let tournamentOpen = await tournament.openTournament();

    // //get gas estimate for entering tournament
    // gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);
    // console.log("gasEstimate: " + gasEstimate);

    //enter tournament
    let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

    //create and start round
    let roundAddress = await tournament.createRound(5);

    round = await tournament.currentRound();
    roundAddress = round[1];

    await tournament.startRound(10, 10, {gas: gasEstimate});
    round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

    //open round
    let roundOpen = await round.isOpen();
    //create submission
    let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
    let submissionAddress = submissionCreated.logs[0].args._submissionAddress;
    console.log("submissionAddress: " + submissionAddress);

    let isSubmission = await platform.isSubmission(submissionAddress);
    assert.isTrue(isSubmission, "Should be a submission.")
  });

    it("Tournament.chooseWinner should invoke a TournmamentClosed event.", async function() {
    //get my submissions
    let mySubmissions = await tournament.mySubmissions.call();
    //choose winner
    let closeTournamentTx = await tournament.chooseWinner(mySubmissions[0]);
    console.log("closeTournamentTx.logs: " + closeTournamentTx.logs[0]);
    //tournament should be closed
    let isOpen = await tournament.isOpen();
    assert.isFalse(isOpen, "Tournament should be closed.");
  });
 });


contract('MatryxPlatform', function(accounts) {
	let platform;
  let token;
	let createTournamentTransaction;
  let tournamentAddress;
  let gasEstimate = 30000000;

  it("The number of tournaments should be 0.", function() {
    return MatryxPlatform.deployed().then(function(instance) {
      return instance.tournamentCount();
    }).then(function(count) {
      assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
    });
  });

  it("The number of tournaments should be 1", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0];

      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

      //get gas estimate for creating peers
      // gasEstimate = await platform.createPeer.estimateGas();
      // console.log("gasEstimate: " + gasEstimate);

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      // gasEstimate = await token.releaseTokenTransfer.estimateGas();
      // console.log("gasEstimate: " + gasEstimate);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      // gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      // console.log("gasEstimate: " + gasEstimate);
      // //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      // gasEstimate = Math.ceil(gasEstimate * 1.3);
      // console.log("gasEstimate * constant: " + gasEstimate);

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

    // //get gas estimate for creating tournament
    // gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
    // console.log("gasEstimate: " + gasEstimate);
    // //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
    // gasEstimate = Math.ceil(gasEstimate * 1.3);
    // console.log("gasEstimate * constant: " + gasEstimate);

    // create a tournament
    createTournamentTransaction = await platform.createTournament("category", "tournament2", "external address", 100*10**18, 2*10**18, {gas: gasEstimate});

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
      let topCategory = await platform.getTopCategory(2);
      console.log("topCategory: " + topCategory);
      topCategory = await platform.getTopCategory(0);
      console.log("topCategory: " + topCategory);
      assert.equal(topCategory, "category", "Did not get the top category of the platform.");
   });

  it("Able to get category count.", async function() {
      let categoryCount = await platform.getCategoryCount("category");
      console.log(categoryCount);
      assert.equal(categoryCount.valueOf(), 2, "Was not able to get category count.");
   });

  it("Able to get tournaments by category.", async function() {
      let tournamentsbyCategory = await platform.getTournamentsByCategory("category");
      console.log(tournamentsbyCategory);
      assert.equal(tournamentsbyCategory[0], tournamentAddress, "Could not get tournaments in this category.");
   });

  it("Able to get my tournaments.", async function() {
      let myTournaments = await platform.myTournaments();
      console.log("myTournaments: " + myTournaments);
      assert.equal(myTournaments[0], tournamentAddress, "Could not get the address of my tournaments from the platorm.");
   });

  it("Able to get my submisisons.", async function() {
      //open tournament
      let tournamentOpen = await tournament.openTournament({gas: gasEstimate});

      //enter tournament
      let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: gasEstimate});

      //create and start round
      let roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});
      round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

      //open round
      let roundOpen = await round.isOpen();

      //make a submission
      let firstSubmission = await tournament.createSubmission("submission1", accounts[0], "external address 1", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
      let firstSubmissionAddress = await round.getSubmissionAddress.call(0);

      let mySubmissions = await platform.mySubmissions();
      console.log("mySubmissions: " + mySubmissions);
      assert.equal(mySubmissions[0], firstSubmissionAddress, "Could not get the address of my submissions from the platform");
  });


  it("Able to set submission gratitude.", async function() {
      await platform.setSubmissionGratitude(10);
      let gratitude = await platform.getSubmissionGratitude();
      assert.equal(gratitude, 10, "Submission gratitude is not equal to 10");
   });

  it("Able to remove a submission.", async function() {
    //get submissions
    let mySubmissions = await tournament.mySubmissions.call();

    //delete submission
    let removeSubmission = await platform.removeSubmission(mySubmissions[0], tournamentAddress);
    console.log("removeSubmission: " + removeSubmission);

    //try to get the same submission
    mySubmissions = await tournament.mySubmissions.call();
    console.log("mySubmissions: " + mySubmissions);
    //get submission one
    // submissionOne = await MatryxSubmission.at(mySubmissions[0]);
    // console.log("submissionOne: " + submissionOne);

    let isSubmission = await platform.isSubmission(mySubmissions[0]);
    console.log("isSubmission: " + isSubmission);

    assert.isFalse(isSubmission, "The submission was not successfully deleted.");
   });
});

contract('MatryxPlatform', async function(accounts)
{
  let platform;
  let createTournamentTransaction;
  let tournamentAddress;
  let tournament;
  let token;

  var queryID = 0;

  it("The balance of the first account is non-zero", async function() {
    web3.eth.defaultAccount = web3.eth.accounts[0];

    // get the platform
    platform = await MatryxPlatform.deployed();
    let prepareBalanceTx = await platform.prepareBalance(0x0);
    queryID = prepareBalanceTx.logs[0].args.id;
    let storeQueryResponseTx = await platform.storeQueryResponse(queryID, 1);
    //let response = storeQueryResponseTx.logs[0].args.storedResponse;
    let balanceIsNonZero = await platform.balanceIsNonZero();
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
  let gasEstimate = 30000000;

  it("One person becomes an entrant in a tournament", async function()
  {
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

      //get gas estimate for creating peers
      //gasEstimate = await platform.createPeer.estimateGas();

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //get gas estimate for releasing token transfer
      //gasEstimate = await token.releaseTokenTransfer.estimateGas();

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

      //get gas estimate for creating tournament
      //gasEstimate = await platform.createTournament.estimateGas("category", "tournament", "external address", 100*10**18, 2*10**18);
      //since createTournament has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
      //gasEstimate = Math.ceil(gasEstimate * 1.3);

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
    //gasEstimate = platform.enterTournament.estimateGas(tournamentAddress);

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