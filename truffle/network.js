const fs = require('fs')
const path = require('path')
const ethers = require('ethers')

const mnemonicHelper = require('mnemonichelper')
let accounts, privateKeys, mnemonicPath, provider, tokenAddress, network

const setNetwork = id => {
    // if network already set, short circuit
    if (network === id) return

    network = id
    // ganache mnemonic below, ropsten mnemonic loaded from <project_root>/../keys/ropsten_mnemonic.txt
    let mnemonic = "fix tired congress gold type flight access jeans payment echo chef host"

    if (network === 'ganache') {
        provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')
        tokenAddress = '0x0c484097e2f000aadaef0450ab35aa00652481a1'
    }
    else if (network === 'develop') {
        provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:9545')
        tokenAddress = '0x0c484097e2f000aadaef0450ab35aa00652481a1'
    }
    else if (network == 'coverage') {
        provider = new ethers.providers.JsonRpcProvider('')
        tokenAddress = '0x0c484097e2f000aadaef0450ab35aa00652481a1'
    }
    else if (network === 'ropsten') {
        provider = new ethers.providers.InfuraProvider('ropsten', 'metamask')
        tokenAddress = '0xf35a0f92848bdfdb2250b60344e87b176b499a8f'
        const mnemonicPath = path.join(__dirname, '../../keys/ropsten_mnemonic.txt')
        mnemonic = fs.readFileSync(mnemonicPath, 'utf8').trim().replace(/(\n|\r|\t|\u2028|\u2029|)/gm, '')
    }
    else console.log('bro check yo network')

    const accs = mnemonicHelper.getAccounts(mnemonic, 0, 10)
    accounts = accs.map(acc => acc[0])
    privateKeys = accs.map(acc => acc[1])
}

module.exports = {
    setNetwork,
    get network() { return network },
    get accounts() { return accounts },
    get privateKeys() { return privateKeys },
    get provider() { return provider },
    get tokenAddress() { return tokenAddress },
    get mnemonicPath() { return mnemonicPath }
}
