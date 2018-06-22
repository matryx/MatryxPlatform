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

        roundData = {start: 5, end: 5, reviewDuration: 5, bounty: "5000000000000000000"}
        t = platform.createTournament("math", tournamentData, roundData, {gasLimit: 6500000})
        console.log(t)
        assert.ok(t);
    });
});