const spawn = require('child_process').spawn
const chalk = require('chalk')
const ethers = require('ethers')

const selectors = require('../generate-setup/selectors.json')

const ganache = spawn('../ganache-local.sh')
const tx = /Transaction: (0x[0-9a-f]+)/
const ready = /Listening on/
const commaSep = num => num.toString().replace(/(\d)(?=(\d{3})+$)/g, '$1,')

let provider
let totalGas = 0

ganache.stdout.on('data', data => {
  const lines = data.toString().split('\n')
  lines.forEach(async line => {
    if (!provider && ready.test(line)) {
      provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')
    }

    const match = tx.exec(line)
    if (match) {
      const hash = match[1]
      const tx = await provider.getTransaction(hash)
      const rcpt = await provider.getTransactionReceipt(hash)

      if (!rcpt) return

      const gas = +rcpt.gasUsed
      const color = gas < 1e6 ? 'green' : gas < 2e6 ? 'yellow' : 'red'
      const gasUsage = chalk`{${color} ${gas.toString().padStart(7, ' ')}}`

      const method = selectors[tx.data.substr(0, 10)]
      let fnCall = ''
      if (method) {
        const [contract, method] = selectors[tx.data.substr(0, 10)].split('.')
        fnCall = chalk`{cyan ${contract}}.{yellow ${method}}`
      }

      const revert = !rcpt.status
      const hashMsg = chalk`{${revert ? 'red' : 'grey'} ${hash}}`

      console.log(`${hashMsg} ${gasUsage} ${fnCall}`)
      totalGas += gas
    }
  })
})

process.on('SIGINT', () => {
  console.log(chalk`\ntotal gas: {cyan ${commaSep(totalGas)}}`)
})
