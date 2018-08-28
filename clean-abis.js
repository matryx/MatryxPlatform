const fs = require('fs')

const CONTRACTS = './build/contracts/'
const KEEPERS = [
  'contractName',
  'abi',
  'networks',
  'schemaVersion',
  'updatedAt'
]

const files = fs.readdirSync(CONTRACTS)
files.forEach(file => {
  const path = CONTRACTS + file
  const contract = JSON.parse(fs.readFileSync(path, 'utf8'))
  const cleaned = {}
  KEEPERS.forEach(key => cleaned[key] = contract[key])

  if (JSON.stringify(contract) !== JSON.stringify(cleaned))
    fs.writeFileSync(path, JSON.stringify(cleaned, 0, 2))
})
