const ethers = require('ethers')
const sleep = ms => new Promise(done => setTimeout(done, ms))

// key from ganache
const key = '0x' + '2c22c05cb1417cbd17c57c1bd0f50142d8d7884984e07b2d272c24c6e120a9ea'

module.exports = {
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

  async setup(artifacts, web3) {
    const MatryxPlatform = artifacts.require('MatryxPlatform')
    const MatryxToken = artifacts.require('MatryxToken')
    const MatryxTournament = artifacts.require('MatryxTournament')
    const MatryxRound = artifacts.require('MatryxRound')
    const MatryxSubmission = artifacts.require('MatryxSubmission')

    const account = web3.eth.accounts[0]
    web3.eth.defaultAccount = account
    console.log('Account:', account)

    const wallet = new ethers.Wallet(key)
    wallet.provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')

    const platform = new ethers.Contract(MatryxPlatform.address, MatryxPlatform.abi, wallet)
    const hasPeer = await platform.hasPeer(account)
    if (!hasPeer) await platform.createPeer({ gasLimit: 4.5e6 })

    const token = new ethers.Contract(MatryxToken.address, MatryxToken.abi, wallet)
    const balance = await token.balanceOf(account) / 1e18 | 0
    console.log('Balance: ' + balance + ' MTX')

    if (balance == 0) {
      let tokens = web3.toWei(1e5)
      await token.setReleaseAgent(account)
      await token.releaseTokenTransfer({ gasLimit: 1e6 })
      await token.mint(account, tokens)
      await token.approve(MatryxPlatform.address, tokens, { gasPrice: 25})

      const balance = await token.balanceOf(account) / 1e18 | 0
      console.log('New balance: ' + balance + ' MTX')
    }
    console.log('setup complete\n')

    return {
      MatryxPlatform,
      MatryxToken,
      MatryxTournament,
      MatryxRound,
      MatryxSubmission,
      account,
      wallet,
      platform,
      token
    }
  }
}
