const ethers = require('ethers')
const chalk = require('chalk')
const network = require('./network')

const genId = length => new Array(length).fill(0).map(() => Math.floor(36 * Math.random()).toString(36)).join('')
const genAddress = () => '0x' + new Array(40).fill(0).map(() => Math.floor(16 * Math.random()).toString(16)).join('')

function getMinedTx(hash) {
  return new Promise((resolve, reject) => {
    async function checkTx() {
      const txr = await network.provider.getTransactionReceipt(hash)
      if (txr) {
        if (!txr.status) return reject({ message: 'revert' })
        resolve(txr)
      } else setTimeout(checkTx, 1000)
    }

    setTimeout(checkTx, 1000)
  })
}

const nonces = {}

function Contract(address, artifact, accountNumber = 0) {
  const name = artifact.contractName.replace(/I?Matryx/g, '')

  let data = {
    name,
    accountNumber,
    contract: {},
    logLevel: Contract.logLevel || 2, // 0 none, 1 reverts, 2 completion, 3 verbose
    wallet: {},
    resetNonce,
  }

  let noncePromise = Promise.resolve()

  function resetNonce() {
    noncePromise = new Promise(async resolve => {
      const nonce = await data.wallet.getTransactionCount()
      nonces[data.accountNumber] = nonce
      resolve()
    })
  }

  const fnWrapper = fnName => async function () {
    // wait for nonce reset, if not done yet
    await noncePromise

    const fn = data.contract[fnName]
    const constant = artifact.abi.find(fn => fn.name === fnName).constant
    const prefix = chalk`{grey       * }`

    let nonce
    if (!constant && nonces[data.accountNumber] !== undefined) {
      const realNonce = await data.wallet.getTransactionCount()

      if (realNonce > nonces[data.accountNumber]) {
        // if nonce on chain is higher, replace saved nonce
        nonces[data.accountNumber] = realNonce
      }

      nonce = nonces[data.accountNumber]
      nonces[data.accountNumber]++
    }

    try {
      let config = { nonce }
      const args = [...arguments]
      const last = args[args.length - 1]

      const configKeys = ['gasLimit', 'gasPrice', 'from', 'gas']
      if (typeof last === "object" && Object.keys(last).some(key => configKeys.includes(key))) {
        args.pop()
        config = { ...last, ...config }
      }

      const res = await fn.apply(null, [...args, config])

      if (data.logLevel >= 3 && !constant) {
        console.log(chalk`${prefix}{grey Waiting for {cyan ${name}}.{yellow ${fnName}} ({cyan ${res.hash}})...}`)
      }

      if (data.logLevel >= 2 && !constant) {
        getMinedTx(res.hash).then(txr => {
          const status = chalk`{${txr.status ? 'green completed' : 'red failed'}}`
          const gas = +txr.gasUsed
          const color = gas < 1e6 ? 'green' : gas < 2e6 ? 'yellow' : 'red'
          const gasUsed = chalk`{grey (used {${color} ${gas}} gas)}`
          console.log(chalk`${prefix}{cyan ${name}}.{yellow ${fnName}} ${status} ${gasUsed}`)
        })
      }

      return res
    } catch (err) {
      let message = ''
      if (err.message.includes('revert')) message = 'revert'
      if (err.message.includes('out of gas')) message = 'out of gas'

      if (data.logLevel >= 1 && message) {
        console.log(chalk`${prefix}{cyan ${name}}.{yellow ${fnName}} {red ${message}}`)
      }
      else if (!err.message.includes('VM') && !constant) {
        // if error before even firing tx, decrement nonce
        nonces[data.accountNumber]--
      }
      throw err
    }
  }

  let proxy = new Proxy(data, {
    set(obj, prop, val) {
      if (['acc', 'accountNumber'].includes(prop)) {
        obj.accountNumber = val
        obj.wallet = new ethers.Wallet(network.privateKeys[obj.accountNumber], network.provider)
        obj.contract = new ethers.Contract(address, artifact.abi, obj.wallet)
        obj.c = obj.contract
        resetNonce()
      } else if (prop === 'wallet') {
        obj.accountNumber = -1
        obj.wallet = val
        obj.contract = new ethers.Contract(address, artifact.abi, obj.wallet)
        obj.c = obj.contract
        resetNonce()
      } else if (prop === 'logLevel') {
        obj.logLevel = val
      }
    },
    get(obj, prop) {
      if (obj.hasOwnProperty(prop)) return obj[prop]
      else if (prop === 'nonce') {
        return nonces[obj.accountNumber]
      } else {
        if (typeof obj.contract[prop] === 'function') return fnWrapper(prop)
        else return obj.contract[prop]
      }
    }
  })

  proxy.accountNumber = accountNumber

  return proxy
}

async function setup(artifacts, web3, accountNum, silent) {
  const MatryxSystem = artifacts.require('MatryxSystem')
  const IMatryxSystem = artifacts.require('IMatryxSystem')
  const MatryxPlatform = artifacts.require('MatryxPlatform')
  const IMatryxPlatform = artifacts.require('IMatryxPlatform')
  const MatryxToken = artifacts.require('MatryxToken')
  const MatryxCommit = artifacts.require('MatryxCommit')
  const IMatryxCommit = artifacts.require('IMatryxCommit')
  const MatryxTournament = artifacts.require('MatryxTournament')
  const IMatryxTournament = artifacts.require('IMatryxTournament')

  const account = network.accounts[accountNum]

  const platform = Contract(MatryxPlatform.address, IMatryxPlatform, accountNum)
  const commit = Contract(MatryxCommit.address, IMatryxCommit)
  const token = Contract(network.tokenAddress, MatryxToken)
  const system = Contract(MatryxSystem.address, IMatryxSystem)

  const log = silent ? () => { } : console.log

  log(chalk`\nSetup {yellow ${account}}`)
  const tokenReleaseAgent = await token.releaseAgent()
  if (tokenReleaseAgent === '0x0000000000000000000000000000000000000000') {
    let { hash } = await token.setReleaseAgent(account)
    await this.getMinedTx(hash)
    await token.releaseTokenTransfer()
    log('Token release agent set to: ' + account)
  }

  const balance = await token.balanceOf(account) / 1e18 | 0
  log('Balance: ' + balance + ' MTX')
  let tokens = web3.toWei(1e5)
  if (balance == 0) {
    let { hash } = await token.mint(account, tokens)
    await this.getMinedTx(hash)
  }

  const allowance = await token.allowance(account, platform.address) / 1e18 | 0
  log('Allowance: ' + allowance + ' MTX')
  if (allowance == 0) {
    token.accountNumber = accountNum
    let { hash } = await token.approve(MatryxPlatform.address, tokens)
    await this.getMinedTx(hash)
  }

  log(`Account ${accountNum} setup complete!\n`)

  return {
    MatryxPlatform,
    MatryxToken,
    MatryxTournament,
    IMatryxTournament,
    system,
    platform,
    commit,
    token
  }
}

module.exports = {
  Contract,
  genId,
  genAddress,
  getMinedTx,
  setup,

  sleep(ms) {
    return new Promise(done => setTimeout(done, ms))
  },

  bytesToString(bytes) {
    if (bytes.length && !bytes.map) bytes = [bytes]
    let arr = bytes.map(b => Array.from(ethers.utils.arrayify(b)))
    let utf8 = [].concat(...arr).filter(x => x)
    return ethers.utils.toUtf8String(utf8)
  },

  numberToBytes(number) {
    let bytes = ethers.utils.hexlify(number)
    return '0x' + ('0'.repeat(64) + bytes.substr(2)).substr(-64)
  },

  stringToBytes(text, len = 0) {
    text = text || ''
    let data = ethers.utils.toUtf8Bytes(text)
    let padding = 64 - ((data.length * 2) % 64)
    data = ethers.utils.hexlify(data)
    data = data + '0'.repeat(padding)
    if (len <= 0) return data

    data = data.substring(2)
    data = data.match(/.{1,64}/g)
    data = data.map(v => '0x' + v)
    while (data.length < len) {
      data.push('0x00')
    }
    return data
  }
}
