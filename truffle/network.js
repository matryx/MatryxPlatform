const fs = require('fs')
const path = require('path')
const ethers = require('ethers')

const mnemonicHelper = require('mnemonichelper')

const network = 'ropsten'
// const network = 'ganache'

const mnemonicPath = path.join(__dirname, '../../keys', network + '_mnemonic.txt')
const mnemonic = fs.readFileSync(mnemonicPath, 'utf8').trim().replace(/(\n|\r|\t|\u2028|\u2029|)/gm, '')

let provider, tokenAddress
if (network === 'ganache') {
    provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')
    tokenAddress = '0x0c484097e2f000aadaef0450ab35aa00652481a1'
}
else if (network === 'ropsten') {
    provider = new ethers.providers.InfuraProvider('ropsten', 'metamask')
    tokenAddress = '0xf35a0f92848bdfdb2250b60344e87b176b499a8f'
}
else console.log('bro check yo network')



module.exports = {
    accounts: mnemonicHelper.getAccounts(mnemonic, 0, 10),
    provider,
    tokenAddress,
    mnemonicPath
}
