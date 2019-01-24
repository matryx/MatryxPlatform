const { setup, genId, genAddress, getMinedTx, sleep, stringToBytes32, stringToBytes, Contract } = require('./utils')
const toWei = n => web3.utils.toWei(n.toString())
web3.toWei = toWei

let platform, token, commit

const init = async () => {
  const data = await setup(artifacts, web3, 0)
  platform = data.platform
  token = data.token

  MatryxCommit = artifacts.require('MatryxCommit')
  IMatryxCommit = artifacts.require('IMatryxCommit')
  commit = Contract(MatryxCommit.address, IMatryxCommit)
}

const createCommit = async (treeHash, value, parent, group) => {
  await commit.commit([treeHash, value, parent], group)

  // return the newly created commit hash
  if (parent != '0x00') {
    const parentCommit = await commit.getCommit(parent)
    return parentCommit.children[parentCommit.children.length - 1]            
  } else {
    const commits = await commit.getRootCommits()
    return commits[commits.length - 1]        
  }
}

const congaLine = async (length) => {
  let parent = '0x00'
  for(let i = 0; i < length; i++) {
    parent = await createCommit(stringToBytes(i), toWei(i), parent, 'group')
    console.log(parent + ' created')
  }
}

module.exports = async exit => {
  try {
    await init()
    // await commit.createGroup('group')
    // await createCommit('0x72ee', '0x777', '0x00', 'group')
    await congaLine(10)
  } catch (err) {
    console.log(err.message)
  } finally {
    exit()
  }
}
