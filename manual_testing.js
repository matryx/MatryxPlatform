var fs = require('fs')
const osHomedir = require('os-homedir');
function getFileContents(path) {return fs.readFileSync(path).toString();}
function stringToBytes32(text, requiredLength) {var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = 64 - (l*2 % 64); data = ethers.utils.hexlify(data);data = data + "0".repeat(pad_length);data = data.substring(2); data = data.match(/.{1,64}/g);data = data.map(v => "0x" + v); while(data.length < requiredLength) { data.push("0x0"); }return data;}
function getFunction(functionName, abi){for(var i = 0; i < abi.length; i++){if(abi[i].name == functionName){return abi[i];}}return null;}

web3.eth.defaultAccount = web3.eth.accounts[0]
// web3.eth.defaultAccount = web3.eth._requestManager.provider.addresses[0]
tokenAddress = "0xf35a0f92848bdfdb2250b60344e87b176b499a8f"
web3Utils = require(osHomedir() + '/Desktop/Ethereum/Development/web3/web3.js/packages/web3-eth-abi/src/index.js');
ethers = require(osHomedir() + '/Desktop/Ethereum/Development/web3/ethers.js');
mnemonic = "fix tired congress gold type flight access jeans payment echo chef host"
wallet = new ethers.Wallet.fromMnemonic(mnemonic);
wallet.provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')
// wallet.provider = new ethers.providers.InfuraProvider('ropsten')
// wallet = new ethers.Wallet.fromMnemonic(getFileContents("/Users/maxhoward/Desktop/Ethereum/Development/Matryx/Projects/keys/dev_wallet_mnemonic.txt"))
// wallet = new ethers.Wallet.fromMnemonic("candy maple cake sugar pudding cream honey rich smooth crumble sweet treat");
// wallet = new ethers.Wallet('0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3');

// platform = web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address)
platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);
platform.createPeer({gasLimit: 4500000})

// token = web3.eth.contract(tokenABI).at(tokenAddress)
tokenAddress = MatryxToken.address
tokenABI = MatryxToken.abi
token = web3.eth.contract(tokenABI).at(tokenAddress);
token.setReleaseAgent(web3.eth.accounts[0])
token.releaseTokenTransfer({gasLimit: 1000000})
token.mint(web3.eth.accounts[0], "100000000000000000000000")
token.approve(MatryxPlatform.address, "100000000000000000000000", {gasPrice: 21e9})

var title = stringToBytes32("Design A Silly Mug", 3);
var descriptionHash = stringToBytes32("QmewXg6HCJ8kVcCKSrBXk8fawLru5Po3XaNgd4aGRrNa1N", 2);
var fileHash = stringToBytes32("QmewXg6HCJ8kVcCKSrBXk8fawLru5Po3XaNgd4aGRrNa1N", 2);
var tournamentData = { category: "math", title_1: title[0], title_2: title[1], title_3: title[2], descriptionHash_1: descriptionHash[0], descriptionHash_2: descriptionHash[1], fileHash_1: fileHash[0], fileHash_2: fileHash[1], bounty: "10000000000000000000", entryFee: "2000000000000000000"}
var startTime = Math.floor((new Date() / 1000 + 10));
var endTime = startTime + 20;
var roundData = { start: startTime, end: endTime, reviewPeriodDuration: 300, bounty: "5000000000000000000"}

tournamentData = [web3.sha3("math"), title[0], title[1], title[2], descriptionHash[0], descriptionHash[1], "10000000000000000000", "2000000000000000000"]
roundData = [startTime, endTime, 300, "5000000000000000000"]

// ********************************
// |  TODO: RESUME RIGHT HERE     | --------------------------------vvvvv
// ********************************
var create_tournament_index = getFunction("createTournament", MatryxPlatform.abi);
createTournamentData = web3Utils.encodeFunctionCall(MatryxPlatform.abi[create_tournament_index], ["math", tournamentData, roundData])

platform.createTournament(tournamentData, roundData, {gasLimit: 8000000, gasPrice: 21e9})
platform.allTournaments(0).then((address) => { t = new ethers.Contract(address, MatryxTournament.abi, wallet); t.getRounds().then((addresses) => { r = web3.eth.contract(MatryxRound.abi).at(addresses[0]);}) })

// token.approve(MatryxPlatform.address, 0);
// token.approve(MatryxPlatform.address, tournamentData.entryFee);
platform.enterTournament(t.address, {gasLimit: 5000000});

var content = stringToBytes32("QmewXg6HCJ8kVcCKSrBXk8fawLru5Po3XaNgd4aGRrNa1N", 1);
submissionData = {title: "A submission", owner: web3.eth.accounts[0], contentHash: content[0]+content[1].substr(2), isPublic: false}
t.createSubmission([],[],[], submissionData, {gasLimit: 6500000});

s = new ethers.Contract(r.getSubmissions()[0], MatryxSubmission.abi, wallet)

tournamentUpdates = {title_1: "0x6e6577206e616d65000000000000000000000000000000000000000000000000", title_2: "0x0000000000000000000000000000000000000000000000000000000000000000", title_3: "0x0000000000000000000000000000000000000000000000000000000000000000", contentHash_1: "0x0000000000000000000000000000000000000000000000000000000000000000", contentHash_2: "0x0000000000000000000000000000000000000000000000000000000000000000", entryFee: "10000000000000000000", entryFeeChanged: true}
t.update(tournamentUpdates, {gasLimit: 6500000})

submission_data = {title: "this may not work", owner: "0x0000000000000000000000000000000000000000", contentHash: "0xabcdef123456789", isPublic: true}

s.update([web3.eth.accounts[2], web3.eth.accounts[3]], [1,4], [], submission_data, {gasLimit: 5000000})

var winners = [s.address]
var distribution = ['1']//[web3.toWei(1)]
var roundStart = Math.floor((new Date() / 1000 + 30));
var roundData = {start: roundStart, end: roundStart+180, reviewPeriodDuration: 300, bounty: 0}

platform.setContractAddress(web3.sha3("hello"), web3.eth.accounts[0])

t.selectWinners(winners, distribution, roundData, "0", {gasLimit: 3000000});

