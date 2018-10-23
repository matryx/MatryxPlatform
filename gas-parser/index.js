const spawn = require('child_process').spawn
const chalk = require('chalk')
const ethers = require('ethers')

const ganache = spawn('../ganache-local.sh')
const tx = /Transaction: (0x[0-9a-f]+)/
const commaSep = num => num.toString().replace(/(\d)(?=(\d{3})+$)/g, '$1,')

const provider = new ethers.providers.JsonRpcProvider('http://127.0.0.1:8545')
let totalGas = 0

ganache.stdout.on('data', data => {
  const lines = data.toString().split('\n')
  lines.forEach(async line => {
    const match = tx.exec(line)
    if (match) {
      const hash = match[1]
      const rcpt = await provider.getTransactionReceipt(hash)
      const gas = +rcpt.gasUsed
      const color = gas < 1e6 ? 'green' : gas < 2e6 ? 'yellow' : 'red'
      console.log(chalk`{grey ${hash}} {${color} ${gas}}`)
      totalGas += gas
    }
  })
})

process.on('SIGINT', () => {
  console.log(chalk`\ntotal gas: {cyan ${commaSep(totalGas)}}`)
})
