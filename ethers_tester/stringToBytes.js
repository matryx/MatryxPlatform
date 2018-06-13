let utils = require('ethers').utils

web3.eth.defaultAccount = web3.eth.accounts[0]
let ethers = require('/Users/kenmiyachi/crypto/ethers.js/index.js');
wallet = ethers.Wallet.createRandom()
wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
web3.eth.sendTransaction({from: web3.eth.accounts[0], to: wallet.address, value: 30*10**18})
//module.exports = {stringToBytes32: stringToBytes32};

function stringToBytes32(text) {
    var data = utils.toUtf8Bytes(text);
    //TODO data.length round up to the closest multiple of 32
    var l = data.length;
    if (l > 128) {
    	//TODO revert and tell user that there title is too long // 
    }
    var pad_length = Math.ceil(l/32.0) * 32;
    data = utils.padZeros(data, pad_length);
    data = utils.hexlify(data);
    //regex = /^([a-zA-Z0-9]){32}$/
    data = data.substring(2);
    data = data.match(/.{1,64}/g);
    // 
    return data;
    //return utils.hexlify(data);
}

//encoded = stringToBytes32("THIS IS A STUPID LONG TITLE: I am very bad at making titles and I acknowledge that fact because I am not concise with my words")
encoded = stringToBytes32("title");
//encoded = stringToBytes32("PLEASE WORK PLEASE WORK: I am extremely bad at making titles but I make ex");
console.log(encoded);
//print(encoded);


platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);

platform.createPeer({gasLimit: 4000000, from: web3.eth.accounts[1]})
token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address)
token.setReleaseAgent(web3.eth.accounts[0])
token.releaseTokenTransfer.sendTransaction({gas: 1000000})
token.mint(web3.eth.accounts[0], 10000*10**18)
token.mint(web3.eth.accounts[1], 5000*10**18)
token.mint(web3.eth.accounts[2], 5000*10**18)
token.mint(web3.eth.accounts[3], 5000*10**18)
token.approve(MatryxPlatform.address, 100*10**18)