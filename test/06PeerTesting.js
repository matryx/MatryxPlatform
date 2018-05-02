var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxToken = artifacts.require("MatryxToken");
let SubmissionTrust = artifacts.require("SubmissionTrust");
let MatryxPeer = artifacts.require("MatryxPeer");
let MatryxSubmission = artifacts.require("MatryxSubmission");

contract('MatryxPlatform', function(accounts)
{
	let platform;
    let createTournamentTransaction;
    let tournamentAddress;
    let tournament;
    let submissionOne;
    let submissionAddress;
    let submissionOneBlocktime;
    let token;
    let peer1;
    let peerAddress;

	it("Submission is owned by peer.", async function() {
		platform = await MatryxPlatform.deployed();
      	token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address);
      	platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
      	web3.eth.defaultAccount = web3.eth.accounts[0]
      	peerZero = await platform.createPeer({gas: 3000000});
        console.log(peerZero);
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
      	// create a tournament
        createTournamentTransaction = await platform.createTournament("category", "tournament", "external address", 100*10**18, 2, {gas: 3000000});
        // get the tournament address
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

      	tournamentAddress = tournamentsCreatedEvents[0].args._tournamentAddress;
      	tournament = await MatryxTournament.at(tournamentAddress);

      	//open tournament
    	let tournamentOpen = await tournament.openTournament();

    	//enter tournament
    	let enteredTournament = await platform.enterTournament(tournamentAddress, {gas: 3000000});

    	//create and start round
    	let roundAddress = await tournament.createRound(5);

    	round = await tournament.currentRound();
    	roundAddress = round[1];

    	await tournament.startRound(10, 10, {gas: 3000000});
    	round = web3.eth.contract(MatryxRound.abi).at(roundAddress);

    	//open round
    	let roundOpen = await round.isOpen();

		// become entrant in tournament
		submissionZero = await tournament.createSubmission("submission0", accounts[0], "external address", ["0x0"], ["0x0"], ["0x0"]);
		submissionZeroAddress = submissionZero.logs[0].args._submissionAddress;
		console.log(submissionZeroAddress);

		//get peer address
		peerZeroAddress = await platform.peerAddress(accounts[0]);

		//peer exists and owns the submission
		let peerOwnsSubmission = await platform.peerExistsAndOwnsSubmission(peerZeroAddress, submissionZeroAddress);
		assert.isTrue(peerOwnsSubmission, "The peer does not own this submission");
    });

  //TODO: test that first peer's trust is less than one. check that with each additional peer their original trust decreases
  //TODO: check that by adding more and more peers the total trust of the system converges to 1

    it("First peer's trust is less than 1", async function() {
      let isPeer = platform.isPeer(peerZero);
      console.log(isPeer);
      let isPeer2 = platform.isPeer(peerZeroAddress);
      console.log(isPeer2);
      console.log(peerZero);
      console.log(peerZeroAddress);
      let reputation = await peerZero.getReputation();
      console.log(reputation);
      let isValid = reputation < 1;
      console.log(isValid);
      assert.isTrue(isValid, "The first peer's reputation was not less than 1.");
    })

});