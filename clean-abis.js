const fs = require('fs')
const exec = require('child_process').execSync

const CONTRACTS = './build/contracts/'
const KEEPERS = [
  'contractName',
  'abi',
  'networks',
  'schemaVersion',
  'updatedAt'
]

const stagedBuild = exec(
  'git diff-index --name-status --cached HEAD \
  | grep -v ^D | grep build/contracts | cut -c3-'
)
  .toString()
  .trim()

if (stagedBuild === '') process.exit(0)

const files = stagedBuild.split('\n')
files.forEach(path => {
  const contract = JSON.parse(fs.readFileSync(path, 'utf8'))
  if (!contract.abis.length) return

  const cleaned = {}
  KEEPERS.forEach(key => (cleaned[key] = contract[key]))

  path = path.replace('contracts', 'abis')
  fs.writeFileSync(path, JSON.stringify(cleaned, 0, 2))
  exec(`git add -f ${path}`)
})
