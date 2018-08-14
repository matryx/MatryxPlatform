var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

var ethersLocal = '/Users/marinatorras/Projects/Matryx/ethers.js';
var walletAddress = "0xb84d848486c6f58c0dab8fef5350d23cda4066e9a0f776f89d56c44af99e9b0c";

contract('Tournament and Round: Open, No Submisisons', function(accounts) {

    let platform;
    let tournament;
    let r;
    let token;
    let submissionAddress;

    it("Able to create a tournament with a round that's Open", async function () {
        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require(ethersLocal); // local ethers pull
        console.log("set up ethers");
        wallet = new ethers.Wallet(walletAddress)
        console.log("set up wallet0");
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        console.log("set up wallet0 provider");
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})
        console.log("sent transaction");

        function stringToBytes32(text, requiredLength) {var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = 64 - (l*2 % 64); data = ethers.utils.hexlify(data);data = data + "0".repeat(pad_length);data = data.substring(2); data = data.match(/.{1,64}/g);data = data.map(v => "0x" + v); while(data.length < requiredLength) { data.push("0x0"); }return data;}

        platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet0);
        console.log("created platform");
        //create peer and mint tokens
        await platform.createPeer({gasLimit: 4000000})
        console.log("created peer");
        token = new ethers.Contract(MatryxToken.address, MatryxToken.abi, wallet0);
        await token.setReleaseAgent(wallet.address)
        await token.releaseTokenTransfer({gasLimit: 1000000})
        await token.mint(wallet.address, "10000000000000000000000")
        await token.approve(MatryxPlatform.address, "100000000000000000000")

        console.log("Tokens were minted !")
        title = stringToBytes32("the title of the tournament", 3);
        categoryHash = stringToBytes32("descriptionHash", 2);
        fileHash = stringToBytes32("fileHash", 2)

        tournamentData = {
            category: 'math',
            title_1: title[0],
            title_2: title[1],
            title_3: title[2],
            descriptionHash_1: categoryHash[0],
            descriptionHash_2: categoryHash[1],
            fileHash_1: fileHash[0],
            fileHash_2: fileHash[1],
            bounty: "10000",
            entryFee: "20"
        }

        console.log("Tournament Parameters have been created ! ");

        var startTime = Math.floor((new Date() / 1000 + 1));
        var endTime = startTime + 1000000000;

        roundData = {start: startTime, end: endTime, reviewPeriodDuration: 5, bounty: "500"}
        await platform.createTournament(tournamentData, roundData, {gasLimit: 6500000})

        console.log("Tournament was created");

        let tournamentAddress = await platform.allTournaments(0);

        tournament = new ethers.Contract(tournamentAddress, MatryxTournament.abi, wallet0);
        console.log("tournamentAddress: " + tournamentAddress);
        console.log("able to get tournament from platform");

        console.log("Getting current round...");
        round_info = await tournament.currentRound();
        console.log("round_info: " + round_info);
        round_address = round_info[1]
        console.log(round_address)

        r = new ethers.Contract(round_address, MatryxRound.abi, wallet0);
        console.log("round: " + r);

        let tournamentState = await tournament.getState();
        console.log("tournamentState: " + tournamentState);

        let roundState = await r.getState();
        console.log("round state: " + roundState);

        assert.isTrue(tournamentState == 2 && roundState == 2, "Tournament and round were not NotYetOpen");
    });

    it ("Tournament owner able to edit tournament details while the tournament is Open", async function() {
    	function stringToBytes32(text, requiredLength) {var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = 64 - (l*2 % 64); data = ethers.utils.hexlify(data);data = data + "0".repeat(pad_length);data = data.substring(2); data = data.match(/.{1,64}/g);data = data.map(v => "0x" + v); while(data.length < requiredLength) { data.push("0x0"); }return data;}

    	title = stringToBytes32("the title of the tournament", 3);
        categoryHash = stringToBytes32("descriptionHash", 2);
        fileHash = stringToBytes32("fileHash", 2);

    	newTournamentData = {
    		title_1: title[0],
            title_2: title[1],
            title_3: title[2],
            descriptionHash_1: categoryHash[0],
            descriptionHash_2: categoryHash[1],
            fileHash_1: fileHash[0],
            fileHash_2: fileHash[1],
            entryFee: "5", 
            entryFeeChanged: true
        }

        await tournament.update(newTournamentData, "space");
        let newTournamentCategory = await tournament.getCategory();
        let newEntryFee = await tournament.getEntryFee();
        assert.isTrue(newTournamentCategory == "space" && newEntryFee == 5, "Tournament data was not updated correctly");
    });

    it("Unable to enter my own tournament", async function () {
    	await token.approve(MatryxPlatform.address, 0);
        await token.approve(MatryxPlatform.address, tournamentData.entryFee);

        console.log("New Token Allowance Approved");

        try {
    			await platform.enterTournament(tournamentAddress, {gasLimit: 6500000});
   				assert.fail('Expected revert not received');
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0;
    			assert(revertFound, 'Unable to catch revert');
  			}
    });
});