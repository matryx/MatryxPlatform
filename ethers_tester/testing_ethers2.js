web3.eth.defaultAccount = web3.eth.accounts[0]
ethers = require('/Users/kenmiyachi/crypto/ethers.js/index.js');
wallet = ethers.Wallet.createRandom()
wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30*10**18})
function stringToBytes32(text, requiredLength) {var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = 64 - (l*2 % 64); data = ethers.utils.hexlify(data);data = data + "0".repeat(pad_length);data = data.substring(2); data = data.match(/.{1,64}/g);data = data.map(v => "0x" + v); while(data.length < requiredLength) { data.push("0x0000000000000000000000000000000000000000000000000000000000000000"); }return data;}

platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);
//p = new web3.eth.contract(MatryxPlatform.abi).at(MatryxPlatform.address);

//platform.createPeer({gasLimit: 4000000, from: web3.eth.accounts[1]});
token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address)
token.setReleaseAgent(web3.eth.accounts[0])
token.releaseTokenTransfer.sendTransaction({gas: 1000000})
token.mint(web3.eth.accounts[0], 10000*10**18)
token.mint(web3.eth.accounts[1], 5000*10**18)
token.mint(web3.eth.accounts[2], 5000*10**18)
token.mint(web3.eth.accounts[3], 5000*10**18)
token.approve(MatryxPlatform.address, 100*10**18)
//token.mint(MatryxPlatform.address, 100*10*18)
platform.createPeer({gasLimit: 4000000})

title = stringToBytes32("the title of the tournament", 3);
categoryHash = stringToBytes32("category hash", 2);
contentHash = stringToBytes32("contentHash", 2);

tournamentData = { categoryHash: categoryHash[0], title_1: title[0], title_2: title[1], title_3: title[2], descriptionHash_1: contentHash[0], descriptionHash_2: contentHash[1], Bounty: 5, entryFee: 2}

roundData = { start: 5, end: 5, reviewDuration: 5, bounty: 5}
platform.createTournament("math", tournamentData, roundData, {gasLimit: 4000000})

platform.allTournaments(0).then((address) => { return t = web3.eth.contract(MatryxTournament.abi).at(address);})