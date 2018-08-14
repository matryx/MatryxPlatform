const MatryxPlatform = artifacts.require('MatryxPlatform')
const MatryxToken = artifacts.require('MatryxToken')

contract('MatryxPlatform', async function(accounts) {

  it("Platform Preloading", async function () {
  	//var fs = require('fs')
	//const osHomedir = require('os-homedir');
	//function getFileContents(path) {return fs.readFileSync(path).toString();}
	function stringToBytes32(text, requiredLength) {var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = 64 - (l*2 % 64); data = ethers.utils.hexlify(data);data = data + "0".repeat(pad_length);data = data.substring(2); data = data.match(/.{1,64}/g);data = data.map(v => "0x" + v); while(data.length < requiredLength) { data.push("0x0"); }return data;}
	//function getFunction(functionName, abi){for(var i = 0; i < abi.length; i++){if(abi[i].name == functionName){return abi[i];}}return null;}

	web3.eth.defaultAccount = web3.eth.accounts[0]
	tokenAddress = "0x0c484097e2f000aadaef0450ab35aa00652481a1"
	//web3Utils = require('/Desktop/Ethereum/Development/web3/web3.js/packages/web3-eth-abi/src/index.js');
	ethers = require('/Users/marinatorras/Projects/Matryx/ethers.js');
	mnemonic = 'fix tired congress gold type flight access jeans payment echo chef host';
	wallet = new ethers.Wallet.fromMnemonic(mnemonic);
	wallet.provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')

	platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);
	await platform.createPeer({gasLimit: 4500000})

	tokenAddress = MatryxToken.address
	tokenABI = MatryxToken.abi
	token = await web3.eth.contract(tokenABI).at(tokenAddress);
	await token.setReleaseAgent(web3.eth.accounts[0])
	await token.releaseTokenTransfer({gasLimit: 1000000})
	await token.mint(web3.eth.accounts[0], "100000000000000000000000")
	await token.approve(MatryxPlatform.address, "100000000000000000000000", {gasPrice: 21e9})

	var title = stringToBytes32("Scenario 1", 3);
	var descriptionHash = stringToBytes32("QmZVK8L7nFhbL9F1Ayv5NmieWAnHDm9J1AXeHh1A3EBDqK", 2); //real hash
	var fileHash = stringToBytes32("QmfFHfg4NEjhZYg8WWYAzzrPZrCMNDJwtnhh72rfq3ob8g", 2); //real hash
	var tournamentData = { category: "math", title_1: title[0], title_2: title[1], title_3: title[2], descriptionHash_1: descriptionHash[0], descriptionHash_2: descriptionHash[1], fileHash_1: fileHash[0], fileHash_2: fileHash[1], initialBounty: "10000000000000000000", entryFee: "2000000000000000000"}
	var startTime = Math.floor((new Date() / 1000 + 86000)); //these parameters work
	var endTime = startTime + 10;
	var roundData = { start: startTime, end: endTime, reviewPeriodDuration: 300, bounty: "5000000000000000000"}

	console.log("creating tournament...")
	let tournamentTx = await platform.createTournament(tournamentData, roundData, {gasLimit: 8000000, gasPrice: 21e9})
	console.log("tournamentTx: " + tournamentTx);

	assert.ok(tournamentTx);
  });

});



