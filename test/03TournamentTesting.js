var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxSubmission = artifacts.require("MatryxSubmission");
var Ownable = artifacts.require("Ownable");
var MatryxToken = artifacts.require("MatryxToken");

var walletAddress = "0xb83a1070d0c5e458580fee82d919e89af84f03a2372cbb239b86d1e22f4b8409";

contract('MatryxTournament', function(accounts) {
    let platform;
    let tournament;
    let round;
    let token;
    //for code coverage
    let gasEstimate = 30000000;

    //for regular testing
    //let gasEstimate = 3000000;

    it("Created tournament should exist", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/marinatorras/Projects/Matryx/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet(walletAddress)
        console.log("wallet: " + JSON.stringify(wallet));
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
        // the tournament should be open 
        let tournamentOpen = await tournament.getState();
        // assert that the tournament is open
        assert.equal(tournamentOpen, 1, "The tournament should be open.");
    });

    it("Able to get platform from tournament", async function() {
        let platformFromTournament = await tournament.getPlatform();
        assert.equal(web3.toChecksumAddress(platformFromTournament), web3.toChecksumAddress(platform.address), "Unable to get platform from tournament.");
    });

    it("Able to get tournament category", async function() {
        let category = await tournament.getCategory();
        assert.equal(category, "math", "Unable to get tournament category.");
    });

    it("A user cannot enter a tournament twice", async function() {
        //get gas estimate for entering tournament
        // gasEstimate = await platform.enterTournament.estimateGas(tournamentAddress);
        // enter the tournament
        let enteredTournament = await platform.enterTournament(tournamentAddress);

        let successInEnteringTournamentTwice = await platform.enterTournament.call(tournamentAddress);
        assert.isFalse(successInEnteringTournamentTwice, "Able to enter a tournament twice");
    });

    it("Able to get total number of entrants.", async function() {
        let allEntrants = await tournament.entrantCount();
        assert.equal(allEntrants, 1, "Total number of entrants should be 1.");
    })

    it("Entrant shuould exist.", async function() {
        let isEntrant = await tournament.isEntrant(wallet.address);
        assert.isTrue(isEntrant, "Accounts[0] should be an entrant.");
    })

    it("A round is open", async function() {
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

        //open the round
        let roundOpen = await r.getState();
        assert.isTrue(roundOpen == 1, "No round is open");
    })

    it("The current round is accurate", async function() {
        let currentRound = await tournament.currentRound();
        assert.ok(currentRound, "Current round is incorrect");
    })

    // Create a Submission
    it("A submission was created", async function() {
        submissionData = {title: "A submission", owner: web3.eth.accounts[0], contentHash: "0xabcdef1124124124124", isPublic: false}
        await tournament.createSubmission([],[],[], submissionData, {gasLimit: 6500000});
        console.log("Submission created");
        let mySubmissions = await tournament.mySubmissions();
        submissionAddress = mySubmissions[0];
        let isSubmission = await platform.isSubmission(submissionAddress);
        assert.isTrue(isSubmission, "Submission should exist.");
    });

    it("I can retrieve my personal submissions", async function() {
        let mySubmissions = await tournament.mySubmissions.call();
        //get my submission
        mySubmission = await MatryxSubmission.at(mySubmissions[0]);
        let submissionOwner = await mySubmission.owner.call();
        console.log("submissionOwner: " + submissionOwner);
        assert.equal(web3.toChecksumAddress(submissionOwner), web3.toChecksumAddress(wallet.address), "A submission given in mySubmissions is not one of my submissions.");
    });

    it("There is 1 Submission", async function() {
        numberOfSubmissions = await tournament.submissionCount()
        assert.equal(numberOfSubmissions.valueOf(), 1)
    });

    it("This is the owner", async function() {
        ownerBool = await tournament.isOwner(wallet.address)
        assert.equal(ownerBool, true)
    });

    it("This is NOT the owner", async function() {
        ownerBool = await tournament.isOwner("0x0")
        assert.equal(ownerBool, false)
    });

    it("Return the external address", async function() {
        gotExternalAddress = await tournament.getExternalAddress()
        return assert.equal(web3.toAscii(gotExternalAddress).replace(/\u0000/g, ""), "external address");
    });

    it("Return entry fees", async function() {
        getEntryFees = await tournament.getEntryFee();
        assert.equal(getEntryFees.toNumber(), 2*10**18);
    });

    it("Able to set tournament title", async function() {
        await tournament.setTitle("bienvenida-a-matryx");
        let title = await tournament.getTitle();
        assert.equal(title, "bienvenida-a-matryx", "The tournament title was not updated correctly.");
    });

    it("Able to set tournament external address", async function() {
        await tournament.setExternalAddress("new address");
        let externalAddress = await tournament.getExternalAddress()
        assert.equal(web3.toAscii(externalAddress).replace(/\u0000/g, ""), "new address", "The tournament external address was not updated correctly.");
    });

    it("Able to set entry fee", async function() {
        await tournament.setEntryFee(10);
        let entryFee = await tournament.getEntryFee();
        assert.equal(entryFee.toNumber(), 10, "The tournament entry fee was not updated correctly.");
    });

    it("The tournament is closed", async function() {
        //get gas estimate for creating submission
        // gasEstimate = await tournament.createSubmission.estimateGas("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"]);
        //since createSubmission has so many parameters we need to multiply the gas estimate by some constant ~ 1.3
        // gasEstimate = Math.ceil(gasEstimate * 1.3);
        //create submission
        let submissionCreated = await tournament.createSubmission("submission1", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
        let submissionAddress = submissionCreated.logs[0].args._submissionAddress;

        let closeTournamentTx = await tournament.chooseWinner(submissionAddress);
        // the tournament should be closed 
        let roundOpen = await round.isOpen();
        // assert that the tournament is closed
        assert.equal(roundOpen.valueOf(), false, "The round should be closed.");
    });

    it("Unable to enter user in tournament after the tournament is closed", async function() {
        try {
          await platform.enterTournament(tournamentAddress, {from: accounts[1], gas: gasEstimate});;
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Unable to catch revert');
        }
    });

    it("Unable to create submission after the tournament is closed", async function() {
        try {
          await tournament.createSubmission("submissionTry", accounts[0], "external address T", ["0x0"], ["0x0"], ["0x0"], {gas: gasEstimate});
          assert.fail('Expected revert not received');
        } catch (error) {
          const revertFound = error.message.search('revert') >= 0;
          assert(revertFound, 'Unable to catch revert');
        }
    });
});

contract('MatryxTournament', function(accounts) {
    let platform;
    let tournament;
    let round;
    let token;
    //for code coverage
    let gasEstimate = 30000000;
    //for regular testing
    //let gasEstimate = 3000000;

    it("Starting a new round opens the tournament", async function() {
      web3.eth.defaultAccount = web3.eth.accounts[0];
      //deploy platform
      platform = await MatryxPlatform.deployed();
      token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)

      //create peers
      await platform.createPeer.sendTransaction({gas: gasEstimate});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[1]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[2]});
      await platform.createPeer.sendTransaction({gas: gasEstimate, from: web3.eth.accounts[3]});
      await token.setReleaseAgent(web3.eth.accounts[0]);

      //release token transfer and mint tokens for the accounts
      await token.releaseTokenTransfer.sendTransaction({gas: gasEstimate});
      await token.mint(web3.eth.accounts[0], 10000*10**18)
      await token.mint(web3.eth.accounts[1], 2*10**18)
      await token.mint(web3.eth.accounts[2], 2*10**18)
      await token.mint(web3.eth.accounts[3], 2*10**18)
      await token.approve(MatryxPlatform.address, 100*10**18)

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

      //create and start round
      let roundAddress = await tournament.createRound(5);
      round = await tournament.currentRound();
      roundAddress = round[1];

      //start round
      await tournament.startRound(10, 10, {gas: gasEstimate});

      let isOpen = await tournament.isOpen();
      assert.isTrue(isOpen, "The tournament should be open.");
    });

});