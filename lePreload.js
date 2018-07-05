// Ganache call
// ganache-cli -u 0,1,2,3 -i 3 -m "fix tired congress gold type flight access jeans payment echo chef host"


/* 
SETUP 
*/
var fs = require('fs')
const osHomedir = require('os-homedir');
function getFileContents(path) {return fs.readFileSync(path).toString();}
function stringToBytes32(text, requiredLength) {var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = 64 - (l*2 % 64); data = ethers.utils.hexlify(data);data = data + "0".repeat(pad_length);data = data.substring(2); data = data.match(/.{1,64}/g);data = data.map(v => "0x" + v); while(data.length < requiredLength) { data.push("0x0"); }return data;}
function getFunction(functionName, abi){for(var i = 0; i < abi.length; i++){if(abi[i].name == functionName){return abi[i];}}return null;}

web3.eth.defaultAccount = web3.eth.accounts[0]
tokenAddress = "0x703ceecce32444a64ec860aa60359d4d22c4a8d9" //This will change everytime I deploy
web3Utils = require('/Users/samhessenauer/Documents/Software/git.nosync/web3.js/packages/web3-eth-abi/src/index.js');
ethers = require('/Users/samhessenauer/Documents/Software/git.nosync/ethers.js');
mnemonic = 'fix tired congress gold type flight access jeans payment echo chef host' //this is set for the ganache 
wallet = new ethers.Wallet.fromMnemonic(mnemonic);
wallet.provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')

platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);
platform.createPeer({gasLimit: 4500000})

tokenAddress = MatryxToken.address
tokenABI = MatryxToken.abi
token = web3.eth.contract(tokenABI).at(tokenAddress)
token.setReleaseAgent(web3.eth.accounts[0])
token.releaseTokenTransfer({gasLimit: 1000000})
token.mint(web3.eth.accounts[0], "100000000000000000000000")
token.approve(MatryxPlatform.address, "100000000000000000000")


/* 
Start of Preload Sequence. See the Engineering guide for details: https://docs.google.com/document/d/139owX8aHyaWLdme-xaujEwHMcuUsbXK_1irWU1TP4_8/edit#heading=h.g5ke2xg059jc 
*/

// Scenario 1: Tournament Created, round 1 not yet open ( STATE: Tournament: NotYetOpen, Round: NotYetOpen)

var title = stringToBytes32("Scenario 1", 3);
var descriptionHash = stringToBytes32("QmewXg6HCJ8kVcCKSrBXk8fawLru5Po3XaNgd4aGRrNa1N", 2);
var fileHash = stringToBytes32("QmewXg6HCJ8kVcCKSrBXk8fawLru5Po3XaNgd4aGRrNa1N", 2);
var tournamentData = { category: "math", title_1: title[0], title_2: title[1], title_3: title[2], descriptionHash_1: descriptionHash[0], descriptionHash_2: descriptionHash[1], fileHash_1: fileHash[0], fileHash_2: fileHash[1], bounty: "10000000000000000000", entryFee: "2000000000000000000"}
var startTime = Math.floor((new Date() / 1000 + 10));
var endTime = startTime + 10;
var roundData = { start: startTime + 86000 , end: endTime, reviewPeriodDuration: 300, bounty: "5000000000000000000"}

platform.createTournament(tournamentData, roundData, {gasLimit: 8000000, gasPrice: 21e9})
platform.allTournaments(0).then((address) => { t = new ethers.Contract(address, MatryxTournament.abi, wallet); t.getRounds().then((addresses) => { r = web3.eth.contract(MatryxRound.abi).at(addresses[0]);}) })


// Scenario 2: Tournament Created, round 1 open with 0 submissions and winner not chosen (STATE: Tournament: Open, Round: Open)






/* 
Template Calls  (Save these)
*/
var title = stringToBytes32("Design A Silly Mug", 3);
var categoryHash = stringToBytes32("QmewXg6HCJ8kVcCKSrBXk8fawLru5Po3XaNgd4aGRrNa1N", 2);
var tournamentData = { categoryHash: web3.sha3("math"), title_1: title[0], title_2: title[1], title_3: title[2], contentHash_1: categoryHash[0], contentHash_2: categoryHash[1], Bounty: "10000000000000000000", entryFee: "2000000000000000000"}
var startTime = Math.floor((new Date() / 1000 + 15));
var endTime = startTime + 120;
var roundData = { start: startTime, end: endTime, reviewDuration: 300, bounty: "5000000000000000000"}

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
var roundEnd = roundStart + 180
var roundData = {start: roundStart, end: roundEnd, reviewPeriodDuration: 300, bounty: "10"}

platform.setContractAddress(web3.sha3("hello"), web3.eth.accounts[0])

t.selectWinners(winners, distribution, roundData, "1", {gasLimit: 5000000});

