
web3.eth.defaultAccount = web3.eth.accounts[0]
ethers = require('ethers');
wallet = ethers.Wallet.createRandom()
wallet.provider = new ethers.providers.JsonRpcProvider('http://localhost:8545')
web3.eth.sendTransaction({ from: web3.eth.accounts[0], to: wallet.address, value: 30 * 10 ** 18 })
function oldStringToBytes32(text) { var data = ethers.utils.toUtf8Bytes(text); var l = data.length; var pad_length = Math.ceil(l / 32.0) * 32; data = ethers.utils.padZeros(data, pad_length); data = ethers.utils.hexlify(data); data = data.substring(2); data = data.match(/.{1,64}/g); return data; }

platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet);

platform.createPeer({ gasLimit: 4000000, from: web3.eth.accounts[1] })
token = web3.eth.contract(MatryxToken.abi).at(MatryxToken.address)
token.setReleaseAgent(web3.eth.accounts[0])
token.releaseTokenTransfer.sendTransaction({ gas: 1000000 })
token.mint(web3.eth.accounts[0], 10000 * 10 ** 18)
token.mint(web3.eth.accounts[1], 5000 * 10 ** 18)
token.mint(web3.eth.accounts[2], 5000 * 10 ** 18)
token.mint(web3.eth.accounts[3], 5000 * 10 ** 18)
token.approve(MatryxPlatform.address, 100 * 10 ** 18)

tournamentData = { categoryHash: web3.sha3("math"), title: "0x" + stringToBytes32("some title"), contentHash: "0x" + stringToBytes32("the content hash"), Bounty: 5, entryFee: 2 }
roundData = { start: 5, end: 5, reviewDuration: 5, bounty: 5 }
platform.createTournament("math", tournamentData, roundData, { gasLimit: 4000000 })

t = new ethers.Contract(platform.allTournaments(0), MatryxTournament.abi, wallet)
