var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxSubmission = artifacts.require("MatryxSubmission");
var MatryxToken = artifacts.require("MatryxToken");

contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;


    it("Platform Preloading", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/kenmiyachi/crypto/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0x50a0e9ac46ad63da3cca4e40b77ebb5d3260022bc36bc32c6a9aa48e287de22c")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

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

        platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);
        assert.ok(platform);
    });
});

contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;


    it("Token Minting", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/kenmiyachi/crypto/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0x50a0e9ac46ad63da3cca4e40b77ebb5d3260022bc36bc32c6a9aa48e287de22c")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

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

        platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);

        await platform.createPeer({gasLimit: 4000000})
        token = new ethers.Contract(MatryxToken.address, MatryxToken.abi, wallet);
        await token.setReleaseAgent(wallet.address)
        await token.releaseTokenTransfer({gasLimit: 1000000})
        await token.mint(wallet.address, "10000000000000000000000")
        await token.approve(MatryxPlatform.address, "100000000000000000000")

        assert.ok(token);
    });
});

contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;


    it("Tournament Creation", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/kenmiyachi/crypto/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0x50a0e9ac46ad63da3cca4e40b77ebb5d3260022bc36bc32c6a9aa48e287de22c")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

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

        var ts = Math.round((new Date()).getTime() / 1000);
        console.log("DATE: ", ts)
        roundData = {start: 5, end: 5, reviewDuration: 5, bounty: "5000000000000000000"}
        await platform.createTournament("math", tournamentData, roundData, {gasLimit: 6500000})
        let tournamentAddress = await platform.allTournaments(0);

        tournament = await web3.eth.contract(MatryxTournament.abi).at(tournamentAddress);
        console.log("tournamentAddress: " + tournamentAddress);
        console.log("able to get tournament from platform");
        console.log("tournament: " + tournament.tx);
        r = web3.eth.contract(MatryxRound.abi).at(tournament.rounds(0))
        console.log("round: " + r);
        let state = await tournament.getState();
        console.log("state: " + state);
        assert.isTrue(r != 0, "Round does not exist");
    });
});

contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;


    it("Tournament Contract w/ EthersJS", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/kenmiyachi/crypto/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0x50a0e9ac46ad63da3cca4e40b77ebb5d3260022bc36bc32c6a9aa48e287de22c")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

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

        var ts = Math.round((new Date()).getTime() / 1000);
        console.log("DATE: ", ts)
        roundData = {start: 5, end: 5, reviewDuration: 5, bounty: "5000000000000000000"}
        await platform.createTournament("math", tournamentData, roundData, {gasLimit: 6500000})
        let tournamentAddress = await platform.allTournaments(0);

        tournament = new ethers.Contract(tournamentAddress, MatryxTournament.abi, wallet);
        console.log("tournamentAddress: " + tournamentAddress);
        console.log("able to get tournament from platform");
        console.log("tournament: " + tournament.tx);
        r = web3.eth.contract(MatryxRound.abi).at(tournament.rounds(0))
        console.log("round: " + r);
        let state = await tournament.getState();
        console.log("state: " + state);
        assert.isTrue(r != 0, "Round does not exist");
    });
});

contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;


    it("Round Contract w/ EthersJS", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/kenmiyachi/crypto/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0x50a0e9ac46ad63da3cca4e40b77ebb5d3260022bc36bc32c6a9aa48e287de22c")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

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

        var ts = Math.round((new Date()).getTime() / 1000);
        console.log("DATE: ", ts)
        roundData = {start: 5, end: 5, reviewDuration: 5, bounty: "5000000000000000000"}
        await platform.createTournament("math", tournamentData, roundData, {gasLimit: 6500000})
        let tournamentAddress = await platform.allTournaments(0);

        tournament = new ethers.Contract(tournamentAddress, MatryxTournament.abi, wallet);
        console.log("tournamentAddress: " + tournamentAddress);
        console.log("able to get tournament from platform");
        console.log("tournament: " + tournament.tx);


        round_info = await tournament.currentRound();
        round_address = round_info[1]
        console.log(round_address)
        //r = web3.eth.contract(MatryxRound.abi).at(tournament.rounds(0))
        r = new ethers.Contract(round_address, MatryxRound.abi, wallet);
        console.log("round: " + r);
        let state = await tournament.getState();
        console.log("state: " + state);

        //TODO -- Initialize Submission Data then create a submision
        assert.isTrue(r != 0, "Round does not exist");
    });
});

contract('MatryxPlatform', function(accounts) {

    let platform;
    let tournament;
    let token;
    let submissionAddress;
    //for code coverage
    let gasEstimate = 30000000;


    it("Successful Submission", async function () {

        web3.eth.defaultAccount = web3.eth.accounts[0]
        ethers = require('/Users/kenmiyachi/crypto/ethers.js'); // local ethers pull
        wallet = new ethers.Wallet("0x50a0e9ac46ad63da3cca4e40b77ebb5d3260022bc36bc32c6a9aa48e287de22c")
        wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
        web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18})

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

        var ts = Math.round((new Date()).getTime() / 1000);
        console.log("DATE: ", ts)
        roundData = {start: 5, end: 5, reviewDuration: 5, bounty: "5000000000000000000"}
        await platform.createTournament("math", tournamentData, roundData, {gasLimit: 6500000})
        let tournamentAddress = await platform.allTournaments(0);

        tournament = new ethers.Contract(tournamentAddress, MatryxTournament.abi, wallet);
        console.log("tournamentAddress: " + tournamentAddress);
        console.log("able to get tournament from platform");
        console.log("tournament: " + tournament);

        round_info = await tournament.currentRound();
        round_address = round_info[1]
        console.log(round_address)
        //r = web3.eth.contract(MatryxRound.abi).at(tournament.rounds(0))
        r = new ethers.Contract(round_address, MatryxRound.abi, wallet);
        console.log("round: " + r);
        let state = await tournament.getState();
        console.log("state: " + state);

        token.approve(MatryxPlatform.address, 0);
        token.approve(MatryxPlatform.address, tournamentData.entryFee);
        platform.enterTournament(tournamentAddress, {gasLimit: 5000000});

        submissionData = {title: "A submission", owner: web3.eth.accounts[0], contentHash: "0xabcdef1124124124124", isPublic: false}
        sub = tournament.createSubmission([],[],[], submissionData, {gasLimit: 6500000});

        console.log("Submission: ", sub);
        assert.ok(sub, "Submission Failed :(")
    });
});
