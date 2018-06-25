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
  let tournamentAddress;
  //for code coverage
  let gasEstimate = 30000000;

  //for regular testing
  //let gasEstimate = 3000000;

  it("The owner of the platform should be the creator of the platform", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/marinatorras/Projects/Matryx/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0xb39d47dbd17325001ea80ae580d879e1e529bc5e2235cff4d1145e974d24a518")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        let sendEtherTxHash = web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

        //minedTx = await getMinedTx(sendEtherTxHash, 1000);
        //console.log("Mined Transaction: ", minedTx);

        function stringToBytes32(text, requiredLength) {
            var data = ethers.utils.toUtf8Bytes(text);
            var l = data.length;
            var pad_length = 64 - (l * 2 % 64);
            data = ethers.utils.hexlify(data);
            data = data + "0".repeat(pad_length);
            data = data.substring(2);
            data = data.match(/.{1,64}/g);
            data = data.map(v => "0x" + v);
            while (data.length < requiredLength) {
                data.push("0x0");
            }
            return data;
        }

        // funtion bytes32ArrayToString(array) {
        //     //TODO -- Function to convert bytes32 array back into string **CHECK FOR TRAILING ZEROS**
        // }

        platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);

        await platform.createPeer({gasLimit: 4000000})
        token = new ethers.Contract(MatryxToken.address, MatryxToken.abi, wallet);
        await token.setReleaseAgent(wallet.address)
        await token.releaseTokenTransfer({gasLimit: 1000000})
        await token.mint(wallet.address, "10000000000000000000000")
        await token.approve(MatryxPlatform.address, "100000000000000000000")

        title = stringToBytes32("the title of the tournament", 3);
        categoryHash = stringToBytes32("contentHash", 2);

        tournamentData = {
            categoryHash: web3.sha3("math"),
            title_1: title[0],
            title_2: title[1],
            title_3: title[2],
            contentHash_1: categoryHash[0],
            contentHash_2: categoryHash[1],
            Bounty: "10000000000000000000",
            entryFee: "2000000000000000000"
        }

        minedTime = await platform.getNow();
        console.log("TIME OF LAST MINED BLOCK: " + minedTime.toNumber());

        var endR = minedTime + 10000000000000;
        var reviewTime = minedTime + 10000000000000;
        console.log("minedTime: " + minedTime);
        console.log("endR: ", endR)
        roundData = {start: minedTime, end: endR, reviewDuration: 1000000, bounty: "5000000000000000000"}
        await platform.createTournament("math", tournamentData, roundData, {gasLimit: 6500000})
        tournamentAddress = await platform.allTournaments(0);

        tournament = await new ethers.Contract(tournamentAddress, MatryxTournament.abi, wallet);

      //check who owns the tournament
      let tournamentOwner = await tournament.getOwner();
      console.log("tournamentOwner: " + tournamentOwner);
      console.log("platform.address: " + platform.address);
      console.log("accounts[0]: " + accounts[0]);
      console.log("wallet.address: " + wallet.address);
      assert.equal(tournamentOwner, wallet.address, "The owner and creator of the tournament should be the same"); 
  });

  // it("Tournament.openTournament should invoke a TournamentOpened event.", async function() {

  //   // Start watching the platform events before we induce the one we're looking for.
  //   platform.TournamentOpened().watch((error, result) => {
  //       if (!error) {
  //         assert.equal(result.args._tournamentName, "tournament", "The name of the tournament should be 'tournament'");
  //       } else {
  //         assert.false();
  //       }
  //   });

  //   // //get gas estimate for opening tournament
  //   // gasEstimate = await tournament.openTournament.estimateGas();
  //   // console.log("gasEstimate: " + gasEstimate);
  //   // //gas estimate underestimates slightly for openTournament, multiply by some constant ~1.3
  //   // gasEstimate = Math.ceil(gasEstimate * 1.3);
  //   // console.log("gasEstimate * constant: " + gasEstimate);

  //   //open the tournament
  //   let openTournamentTx = await tournament.openTournament({gas: gasEstimate});
  // });

  it("Tournament should be mine", async function(){
    let isTournamentMine = platform.getTournament_IsMine(tournamentAddress, {from: wallet});
    assert.isTrue(isTournamentMine, "Tournament shoud be mine.");
  });

  it("Able to recognize a submission", async function(){
        round_info = await tournament.currentRound();
        round_address = round_info[1]
        console.log(round_address)
        //r = web3.eth.contract(MatryxRound.abi).at(tournament.rounds(0))
        r = new ethers.Contract(round_address, MatryxRound.abi, wallet);
        console.log("round: " + r);

        let state = await tournament.getState();
        console.log("state: " + state);

        await token.approve(MatryxPlatform.address, 0);
        await token.approve(MatryxPlatform.address, tournamentData.entryFee);

        console.log("New Token Allowance Approved");

        enter = await platform.enterTournament(tournamentAddress, {gasLimit: 6500000});
        //enteredMinedTx = await getMinedTx(enter, 1000);

        //console.log("Entering Tournament Transaction Hash: ", enteredMinedTx);
        console.log("Entered: ", enter);
        submissionData = {title: "A submission", owner: web3.eth.accounts[0], contentHash: "0xabcdef1124124124124", isPublic: false}
        await tournament.createSubmission([],[],[], submissionData, {gasLimit: 6500000});
        console.log("Submission created");
        let mySubmissions = await tournament.mySubmissions();
        submissionAddress = mySubmissions[0];

    let isSubmission = await platform.isSubmission(submissionAddress);
    assert.isTrue(isSubmission, "Should be a submission.")
  });

    it("Tournament.chooseWinner should invoke a TournmamentClosed event.", async function() {
    //get my submissions
    let mySubmissions = await tournament.mySubmissions.call();
    //choose winner
    let closeTournamentTx = await tournament.chooseWinner(mySubmissions[0]);
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
  //for code coverage
  let gasEstimate = 30000000;

  //for regular testing
  //let gasEstimate = 3000000;

  it("The number of tournaments should be 0.", async function() {
    let count = await platorm.tournamentCount();
    assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
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
      topCategory = await platform.getTopCategory(0);
      assert.equal(topCategory, "category", "Did not get the top category of the platform.");
   });

  it("Able to get category count.", async function() {
      let categoryCount = await platform.getCategoryCount("category");
      assert.equal(categoryCount.valueOf(), 2, "Was not able to get category count.");
   });

  it("Able to get tournaments by category.", async function() {
      let tournamentsbyCategory = await platform.getTournamentsByCategory("category");
      assert.equal(tournamentsbyCategory[0], tournamentAddress, "Could not get tournaments in this category.");
   });

  it("Able to get my tournaments.", async function() {
      let myTournaments = await platform.myTournaments();
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

    //try to get the same submission
    mySubmissions = await tournament.mySubmissions.call();
    let isSubmission = await platform.isSubmission(mySubmissions[0]);

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
  //for code coverage
  let gasEstimate = 30000000;

  //for regular testing
  //let gasEstimate = 3000000;

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

//Testing the category iterator
contract('MatryxPlatform', async function(accounts) {
    let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let token;
    //for code coverage
    let gasEstimate = 30000000;

    //for regular testing
    //let gasEstimate = 3000000;

    it("Able to get first category by index.", async function () {
        web3.eth.defaultAccount = web3.eth.accounts[0];
        //deploy platform
        platform = await MatryxPlatform.deployed();
        token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
        platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

        //create peers
        await platform.createPeer.sendTransaction({gas: gasEstimate});

        await token.setReleaseAgent(web3.eth.accounts[0]);

        //release token transfer and mint tokens
        await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
        await token.mint(web3.eth.accounts[0], 10000 * 10 ** 18)

        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)

        // create an "art" tournament
        createTournamentTransaction = await platform.createTournament("art", "artTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
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

        //create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let topCategory = await platform.getCategoryByIndex(0);
        assert.equal(topCategory, "art", "The first category should be art.");

    });

    it("Able to get second category by index.", async function () {
        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "science" tournament
        await platform.createTournament("science", "scienceTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let secondCategory = await platform.getCategoryByIndex(1);
        assert.equal(secondCategory, "science", "The second category should be science.");

    });

    it("Top category is the one that has the most tournaments.", async function () {
        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "math" tournament
        await platform.createTournament("math", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "math" tournament
        await platform.createTournament("math", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let topCategory = await platform.getTopCategory(0);
        assert.equal(topCategory, "math", "The top category should be math.");

    });

    it("Last category on the list is medicine.", async function () {
        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "medicine" tournament
        await platform.createTournament("medicine", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let lastCategory = platform.getTopCategory(3);
        assert.equal(lastCategory, "medicine", "Last category on the list sohuld be medicine.");
    });

    it("A 2nd art tournament moves 'art' to 2nd place on the list.", async function () {
        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create an "art" tournament
        await platform.createTournament("art", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let secondTopCategory = await platform.getTopCategory(1);
        assert.equal(secondTopCategory, "art", "The 2nd top category should be art.");

    });

    it("All categories have multiple submissions.", async function () {
        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "science" tournament
        await platform.createTournament("science", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "medicine" tournament
        await platform.createTournament("medicine", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let scienceTournaments = await platform.getTournamentsByCategory("science");
        let medicineTournaments = await platform.getTournamentsByCategory("medicine");

        let allMultipleTournaments = (scienceTournaments.length > 1) && (medicineTournaments.length > 1);

        assert.isTrue(allMultipleTournaments, "The science and medicine categories should both have more than one tournament.");

    });

    it("Last category on the list is chemistry.", async function () {
        await token.mint(web3.eth.accounts[0], 100 * 10 ** 18)
        await token.approve(MatryxPlatform.address, 100 * 10 ** 18)
        // create a "chemistry" tournament
        await platform.createTournament("chemistry", "mathTournament", "external address", 100 * 10 ** 18, 2 * 10 ** 18, {gas: gasEstimate});
        tournamentCreatedEvent = platform.TournamentCreated();

        tournamentCreatedEventsPromise = new Promise((resolve, reject) =>
            tournamentCreatedEvent.get((err, res) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(res);
                }
            }))
        tournamentsCreatedEvents = await tournamentCreatedEventsPromise;

        //get tournament address
        tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
        // create tournament from address
        tournament = await MatryxTournament.at(tournamentAddress);

        let lastCategory = platform.getTopCategory(4);
        assert.equal(lastCategory, "chemistry", "Last category on the list sohuld be medicine.");
    });

    it("Unable to get top 10th category when there are less than 10 categories.", async function () {
        let lastCategory = platform.getTopCategory(10);
        assert.equal(lastCategory, 0x0, "Last category should be null.");
    });
});