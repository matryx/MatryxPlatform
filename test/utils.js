const ethers = require('ethers')
const network = require('../truffle/network.js')
var _ = require("lodash");
var Promise = require("bluebird");
const sleep = ms => new Promise(done => setTimeout(done, ms))

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
          obj.wallet = new ethers.Wallet(network.privateKeys[obj.accountNumber], network.provider)
          obj.contract = new ethers.Contract(address, abi, obj.wallet)
          obj.c = obj.contract
        }
        else if (prop === 'wallet') {
          obj.accountNumber = -1
          obj.wallet = val
          obj.contract = new ethers.Contract(address, abi, obj.wallet)
          obj.c = obj.contract
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

  getMinedTx(msg, hash) {
    if (arguments.length == 1) {
      hash = msg
      msg = 'transaction'
    }

    return new Promise((resolve, reject) => {
      (async function checkTx() {
        let res = await network.provider.getTransactionReceipt(hash)
        if (res) {
          if (!res.status) return reject({ message: 'revert' })
          let gas = +res.gasUsed
          resolve(res)
        }
        else setTimeout(checkTx, 1000)
      })()
    })
  },

  sleep(ms) {
    return new Promise(done => setTimeout(done, ms))
  },

  bytesToString(bytes) {
    if (bytes.length && !bytes.map) bytes = [bytes]
    let arr = bytes.map(b => Array.from(ethers.utils.arrayify(b)))
    let utf8 = [].concat(...arr).filter(x => x)
    return ethers.utils.toUtf8String(utf8)
  },

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

    const account = network.accounts[accountNum]

    const platform = Contract(MatryxPlatform.address, MatryxPlatform, accountNum)
    const token = Contract(network.tokenAddress, MatryxToken, 0)

    const hasEnteredMatryx = await platform.hasEnteredMatryx(account)
    if (!hasEnteredMatryx) {
      let { hash } = await platform.enterMatryx({ gasLimit: 4.5e6 })
      await this.getMinedTx('Platform.enterMatryx', hash)
    }

    const tokenReleaseAgent = await token.releaseAgent()
    if (tokenReleaseAgent === '0x0000000000000000000000000000000000000000') {
      let { hash } = await token.setReleaseAgent(account)
      await this.getMinedTx('Token.setReleaseAgent', hash)
      await token.releaseTokenTransfer({ gasLimit: 1e6 })
    }

    const balance = await token.balanceOf(account) / 1e18 | 0
    let tokens = web3.toWei(1e5)
    if (balance == 0) {
      let { hash } = await token.mint(account, tokens)
      await this.getMinedTx('Token.mint', hash)
    }

    const allowance = await token.allowance(account, platform.address) / 1e18 | 0
    if (allowance == 0) {
      token.accountNumber = accountNum
      let { hash } = await token.approve(MatryxPlatform.address, tokens, { gasPrice: 25 })
      await this.getMinedTx('Token.approve', hash)
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
