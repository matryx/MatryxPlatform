const { setup, genId, genAddress, getMinedTx, sleep, stringToBytes32, stringToBytes, Contract } = require('./utils')
const toWei = n => web3.utils.toWei(n.toString())
web3.toWei = toWei

let platform, token, commit

const init = async () => {
  const data = await setup(artifacts, web3, 0)
  await setup(artifacts, web3, 1)
  platform = data.platform
  token = data.token

  MatryxCommit = artifacts.require('MatryxCommit')
  IMatryxCommit = artifacts.require('IMatryxCommit')
  commit = Contract(MatryxCommit.address, IMatryxCommit)
}

const randHash = () => new Array(32).fill(0).map(() => Math.floor(16 * Math.random()).toString(16)).join('')

const createCommit = async (contentHash, value, parent) => {
  await commit.commit(contentHash, value, parent)

  // return the newly created commit hash
  const parentCommit = await commit.getCommit(parent)
  return parentCommit.children[parentCommit.children.length - 1]            
}

const congaLine = async (root, length) => {
  let parent = root
  for (let i = 0; i < length; i++) {
    parent = await createCommit(stringToBytes(randHash(), 2), toWei(1), parent)
    console.log(parent + ' created')
  }
  return parent
}

const forkCommit = async (contentHash, value, parent, accountNumber) => {
  const lastAccount = commit.accountNumber
  commit.accountNumber = accountNumber

  const group = "group " + randHash()
  await commit.createGroup(group)
  await commit.fork(contentHash, value, parent, group, { gasLimit: 8e6 })
  
  commit.accountNumber = lastAccount
}

const findLastForkable = async (commitHash) => {
  let hash = commitHash

  while (true) {
    try {
      await forkCommit(stringToBytes(randHash(), 2), toWei(1), hash, 1)
      console.log('success!')
      break;
    } catch (err) {
      c = await commit.getCommit(hash)
      console.log(`nope ${+c.height} ${hash}`)
      hash = c.parentHash
    }
  }
}

module.exports = async exit => {
  try {
    await init()

    // await findLastForkable('0xa1beed75d8bd5a7d444d72f694a3cad10c4bf5d443bd06b606c3a0c029a55fd0')
    
    // const group = 'group ' + randHash()
    // await commit.createGroup(group)
    // await commit.initialCommit(stringToBytes(randHash(), 2), toWei(1), group)
    
    // const initialCommits = await commit.getInitialCommits()
    // const root = initialCommits[initialCommits.length - 1]

    // let lastCommit = root
    // let lastCommit = '0x85ac80ab1e2a05e234a84ff7debe47fcf6528555cafa83f06129038cf0d4fec0'
    // for (let i = 0; i < 10; i++) {
    //   lastCommit = await congaLine(lastCommit, 1)

    //   await forkCommit(stringToBytes(randHash(), 2), toWei(1), lastCommit, 1)
    // }
    // console.log('conga line done')


    // await commit.submitToTournament()
  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}

// c.submitToTournament('', network.accounts[0], [stb('title', 3), stb('Qmajsldjfalsdjflsjdfklajsdf', 2), stb('Qmasdfasdfasdfsdfaasdf', 2), [], [], []])
/*

0x
f682d61e67882dce638e092b142460ec7d6064082c54382e3d8eb352c5dabf9e
0000000000000000000000000000000000000000000000000000000000000000

0x
26658fb3173faa59b79220fe72f35ef74568ce1716f7d1b69447beb78b0fe1ab
ae9d6122d518d2eedc296da2b9325d594b6327b13ed8785e4071eca33e8c280c


*/