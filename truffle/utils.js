const ethers = require('ethers')
const sleep = ms => new Promise(done => setTimeout(done, ms))

const bip39 = require('bip39') // npm i -S bip39
const ethUtil = require('ethereumjs-util')
const hdkey = require('ethereumjs-wallet/hdkey')
var path = require("path");

// key from ganache
const keys = [
  '0xCF244583D47C45F8C8C14D8C7111271C94147B4A513861CD81887B037496AC10',
  '0xCF244583D47C45F8C8C14D8C7111271C94147B4A513861CD81887B037496AC10',
  '0x42811f2725f3c7a7608535fba191ea9a167909883f1e76e038c3168446fbc1bc',
  '0xb1744eb5862a044da11d677a590e236cddb2eda68a9aa4afaeddab797c75ef58',
  '0xcf256f53446df317d94876f8b02b279133ea8c18659635b109cc049f8a59371f',
  '0x30b1dcefe0b8fcd094738c80c0b822eff6a6445ed2cacdcf8a7feebc308aa25a',
  '0x402e268ea63ec03a6a2ee6f3000e78a1a9f82064863b1b2f5f0d289c9f3b3df8',
  '0xa6ff24aba3b39e3e8fbf9eb51e1e449cd43568aa07602b7b1bb3a3f9033b9b8c',
  '0x2c60947d758af4a091f51ae10ef2e101b2aaa80a194a1219c0eb584ce4720064',
  '0xa9a763679fdbe3e245a92dbaaebbb4f1184165de58a13869f8a64e8526c112ef'
]

var content;
//Change to the correct parent folder that holds mnemonic
fs.readFile('../../keys/mnemonic.txt', 'utf8', (err, data) => {
  if (err) throw err;
  //console.log(data)
  content = data;
});
  
const getAccount = (mnemonic, accountNumber) =>
{
    //Converting to Seed
    var seed = bip39.mnemonicToSeed(mnemonic)
    //Creates wallet instance based on the seed
    const root = hdkey.fromMasterSeed(seed)
    //Gets the private key string of the root wallet instance
    const masterPrivateKey = root._hdkey._privateKey.toString('hex')
    //Derives address of the accounts
    const addrNode = root.derivePath("m/44'/60'/0'/0/" + accountNumber.toString())
    //Private key of the account
    const privKey = "0x" + addrNode._hdkey._privateKey.toString('hex')
    //Generates public key from private key
    const pubKey = ethUtil.privateToPublic(addrNode._hdkey._privateKey)
    //public key to address
    const addr = "0x" + ethUtil.publicToAddress(pubKey).toString('hex')
    return {address: addr, privateKey: privKey.toString('hex')}
}

//getAccounts(content,0,9)
const getAccounts = (mnemonic, startIndex, endIndex) =>
{
    var seed = bip39.mnemonicToSeed(mnemonic)
    const root = hdkey.fromMasterSeed(seed)
    const masterPrivateKey = root._hdkey._privateKey.toString('hex')

    var addressPrivateKeyPairs = []
    for(var i = startIndex; i <= endIndex; i++)
    {
        const addrNode = root.derivePath("m/44'/60'/0'/0/" + i.toString())
        const privKey = "0x" + addrNode._hdkey._privateKey.toString('hex')
        const pubKey = ethUtil.privateToPublic(addrNode._hdkey._privateKey)
        const addr = "0x" + ethUtil.publicToAddress(pubKey).toString('hex')

        addressPrivateKeyPairs.push([addr, privKey.toString('hex')])
    }
    console.log("\n")
    console.log("Available Accounts\n==================")
    for(var i = startIndex; i <= endIndex; i++) 
    {
        console.log("("+i+") "+addressPrivateKeyPairs[i][0])
    }

    console.log("Private Keys\n==================")
    for(var i = startIndex; i <= endIndex; i++) 
    {
        console.log("("+i+") "+addressPrivateKeyPairs[i][1].substring(2))
    }
    console.log("\n")
    return addressPrivateKeyPairs;
}

function Contract(address, { abi }, accountNum = 0) {
  let data = {
    accountNumber: accountNum,
    contract: {},
    wallet: {}
  }

  let proxy = new Proxy(data, {
    set(obj, prop, val) {
      if (prop === 'accountNumber') {
        obj.accountNumber = val
        obj.wallet = new ethers.Wallet(keys[obj.accountNumber], new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545'))
        obj.contract = new ethers.Contract(address, abi, obj.wallet)
      }
    },
    get(obj, prop) {
      if (obj.hasOwnProperty(prop))
        return obj[prop]
      else return data.contract[prop]
    }
  })

  proxy.accountNumber = accountNum

  return proxy
}

module.exports = {
  Contract,

  stringToBytes(text) {
    let bytes = ethers.utils.toUtf8Bytes(text)
    return ethers.utils.hexlify(bytes)
  },

  stringToBytes32(text, requiredLength) {
    var data = ethers.utils.toUtf8Bytes(text)
    var l = data.length
    var pad_length = 64 - ((l * 2) % 64)
    data = ethers.utils.hexlify(data)
    data = data + '0'.repeat(pad_length)
    data = data.substring(2)
    data = data.match(/.{1,64}/g)
    data = data.map(v => '0x' + v)
    while (data.length < requiredLength) {
      data.push('0x0')
    }
    return data
  },

  async setup(artifacts, web3, accountNum) {
    const MatryxPlatform = artifacts.require('MatryxPlatform')
    const MatryxToken = artifacts.require('MatryxToken')
    const MatryxTournament = artifacts.require('MatryxTournament')
    const MatryxRound = artifacts.require('MatryxRound')
    const MatryxSubmission = artifacts.require('MatryxSubmission')

    const account = web3.eth.accounts[accountNum]

    const platform = Contract(MatryxPlatform.address, MatryxPlatform, accountNum)
    const token = Contract(MatryxToken.address, MatryxToken, 0)

    const hasPeer = await platform.hasPeer(account)

    if (!hasPeer) {
      console.log('\nSetting up account:', account)
      
      await platform.createPeer({ gasLimit: 4.5e6 })

      const balance = await token.balanceOf(account) / 1e18 | 0
      console.log('Balance: ' + balance + ' MTX')

      const tokenReleaseAgent = await token.releaseAgent()
      if (tokenReleaseAgent === '0x0000000000000000000000000000000000000000') {
        await token.setReleaseAgent(account)
        await token.releaseTokenTransfer({ gasLimit: 1e6 })
        console.log('Token release agent set to accounts[' + accountNum + '] (' + account + ')')
      }

      if(balance == 0)
      {
        let tokens = web3.toWei(1e5)
        await token.mint(account, tokens)

        token.accountNumber = accountNum
        await token.approve(MatryxPlatform.address, tokens, { gasPrice: 25})

        const balance = await token.balanceOf(account) / 1e18 | 0
        console.log('Minted: ' + balance + ' MTX')
      }

      console.log('Account', accountNum, 'setup complete!')
    }

    return {
      MatryxPlatform,
      MatryxToken,
      MatryxTournament,
      MatryxRound,
      MatryxSubmission,
      platform,
      token
    }
  }
}