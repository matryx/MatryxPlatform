const fs = require('fs')
const sha3 = require('solidity-sha3').default

const files = fs.readdirSync('../contracts')
const contracts = files
  .filter(f => f.includes('.sol') && f.includes('Matryx'))
  .map(f => fs.readFileSync(`../contracts/${f}`, 'utf-8'))
const source = contracts.join('\n')

const libReg = /library (\w+)\s+\{(.+?)^\}/gms
const structReg = /struct (.+?)\s+\{(.+?)\}/gs
const membersReg = /([^\s]+)\s\w+;/g
const dynTypesReg = /.*\[\].*|^(?!address|bool|bytes[\d]+|u?int[\d]*)/
const fnReg = /function (\w+)\((.*?)\)/g

const slots = {
  'info': 0,
  'data': 4
}
const structs = {}
const setup = []

let match
while ((match = libReg.exec(source))) {
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

// console.log(JSON.stringify(structs, 0, 2))
// console.log(' ')
libReg.lastIndex = 0

while ((match = libReg.exec(source))) {
  const [, libName, libContent] = match
  if (libName === "LibTrinity") continue

  while ((match = fnReg.exec(libContent))) {
    if (!match[2]) match[2] = ''

    const name = match[1]
    const params = match[2].split(/, ?/).map(p => p.split(' '))
    const injParams = params.filter(p => p.includes('storage')).map(p => slots[p[2]])
    const numInject = injParams.length

    const toParams = params.map(p => {
      if (p[1] == 'storage') return `${p[0]} ${p[1]}`
      else return p[0]
    })
    const toSig = `${name}(${toParams.join(',')})`
    const toSel = sha3(toSig).substr(0, 10)

    // slice 2 to ignore 2 addresses at start (self and sender)
    const nonStorage = toParams.slice(2).filter(p => !p.includes('storage'))
    const fromParams = nonStorage.map(type => {
      const s = structs[type]
      return s !== undefined ? s.tuple : type
    })
    const fromSig = `${name}(${fromParams.join(',')})`
    const fromSel = sha3(fromSig).substr(0, 10)

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
      `${libName}.${name}: inject ${numInject}, dynamic ${numDyn}${
        numDyn ? ` at ${dynParams.join(' ')}` : ''
      }`
    )
    console.log(fromSel, fromSig)
    console.log(toSel, toSig)
    console.log(' ')

    const comment = `// ${libName.replace('Lib', 'Matryx')}.${name}`
    const fnData = `['${toSel}', [${injParams}], [${dynParams}]]`
    const call = `system.addContractMethod(1, stringToBytes('${libName}'), '${fromSel}', ${fnData})`

    setup.push(comment)
    setup.push(call)
  }
  setup.push('')
}

fs.writeFileSync('./setup-commands', setup.join('\n'))
