const fs = require('fs')
const sha3 = require('solidity-sha3').default
const lib = fs.readFileSync('../contracts/MatryxSubmission.sol', 'utf-8')

const libReg = /library (\w+)\s+\{(.+?)^\}/gms
const structReg = /struct (.+?)\s+\{(.+?)\}/gs
const membersReg = /([^\s]+)\s\w+;/g
const dynTypesReg = /.*\[\].*|^(?!address|bool|bytes[\d]+|u?int[\d]*)/
const fnReg = /function (\w+)\((.*?)\)/g

const structs = {}

let match
while ((match = libReg.exec(lib))) {
  const [, libName, libContent] = match

  while ((match = structReg.exec(libContent))) {
    const [, name, members] = match
    let isDyn = false

    let types = []
    while ((match = membersReg.exec(members))) {
      const type = match[1]
      types.push(type)
      isDyn |= !!dynTypesReg.test(type)
    }

    structs[`${libName}.${name}`] = {
      dynamic: !!isDyn,
      tuple: `(${types.join(',')})`
    }
  }
}

console.log(JSON.stringify(structs, 0, 2))
console.log(' ')

while ((match = fnReg.exec(lib))) {
  if (!match[2]) match[2] = ''

  const name = match[1]
  const params = match[2].split(/, ?/).map(p => p.split(' '))
  const numInject = params.reduce((c, p) => (p[1] === 'storage' ? c + 1 : c), 0)

  const toParams = params.map(p => p.slice(0, p.length - 1).join(' '))
  const toSig = `${name}(${toParams.join(',')})`

  const nonStorage = toParams.filter(p => !p.includes('storage'))
  const fromParams = nonStorage.map(type => {
    const s = structs[type]
    return s !== undefined ? s.tuple : type
  })
  const fromSig = `${name}(${fromParams.join(',')})`

  const dynParams = []
  const numDyn = nonStorage.reduce((c, type, i) => {
    if (!dynTypesReg.test(type)) return c

    let dyn = 1
    if (type && structs[type] !== undefined) {
      if (!structs[type].dynamic) dyn = 0
    }

    if (dyn) dynParams.push(i)
    return c + dyn
  }, 0)

  console.log(
    `${name}: inject ${numInject}, dynamic ${numDyn}${
      numDyn ? ` at ${dynParams.join(' ')}` : ''
    }`
  )
  console.log(sha3(fromSig).substr(0, 10), fromSig)
  console.log(sha3(toSig).substr(0, 10), toSig)
  console.log(' ')
}
