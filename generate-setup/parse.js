const fs = require('fs')
const sha3 = require('solidity-sha3').default
const generate = require('./generate')

const version = process.argv[3] || 1
const batch = process.argv[2] === 'true'

const ignore = ['LibUtils', 'LibTrinity', 'LibTournamentHelper']

const st = Date.now()
const files = fs.readdirSync('../contracts')
const contracts = files
  .filter(f => f.includes('.sol'))
  .filter(f => f.includes('Matryx') || f.includes('Lib'))
  .map(f => fs.readFileSync(`../contracts/${f}`, 'utf-8'))
const source = contracts.join('\n')

const interfaceReg = /interface (\w+)\s+\{(.+?)^\}/gms
const libAndContractReg = /(?:library|contract) (\w+).+?\{(.+?)^\}/gms
const libReg = /library (\w+)\s+\{(.+?)^\}/gms
const structReg = /struct (\w+?)\s+\{(.+?)\}/gs
const membersReg = /^\s+(\S+)\s+\w+;/gm
const dynTypesReg = /.*\[\].*|^(?!address|bool|bytes\d+|u?int\d*)/
const fnReg = /function (\w+)\((.*?)\).*/g

const wordTypesReg = /^(address|bool|bytes\d+|u?int\d*)$/
const arrayType = /\[(\d*)\]/

const slots = {
  'MatryxPlatform.Info': 0,
  'MatryxPlatform.Data': 3,
  'LibCommit.CommitData': 16
}

const structs = {}
const selectors = {}
const setup = []
const methods = []

// return the size of a type in words
const sizeof = type => {
  if (structs[type] !== undefined) {
    return structs[type].words
  }
  
  if (wordTypesReg.test(type)) return 1
  if (type.includes('mapping')) return 1
  
  let match = arrayType.exec(type)
  if (!match) throw new Error('wtf happened: ' + type)
  return +match[1] || 1
}

// flattens a struct to basic types (no nested structs)
const flattenStruct = structName => {
  const struct = structs[structName]
  let members = struct.tuple.replace(/^\(|\)$/g, '').split(',')
  members = members.map(member => {
    if (structs[member] !== undefined) {
      return flattenStruct(member)
    } else return member
  })
  return members.join(',')
}

let match

// parse all the structs in the libraries
while ((match = libAndContractReg.exec(source))) {
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

// calculate all the struct sizes
for (const structName of Object.keys(structs)) {
  const struct = structs[structName]
  if (struct.dynamic) {
    struct.words = 1
    continue
  }

  const basicTypes = flattenStruct(structName).split(',')
  struct.words = basicTypes.map(sizeof).reduce((a, x) => a + x, 0)
}

console.log(JSON.stringify(structs, 0, 2))
console.log(' ')

// parse all interfaces to build selector->name lookup
while ((match = interfaceReg.exec(source))) {
  const [, interfaceName, interfaceContent] = match

  while ((match = fnReg.exec(interfaceContent))) {
    const [, fnName, fnArgs] = match

    if (match[0].includes(' view ')) continue

    const argTypes = (fnArgs || '')
      .split(/, ?/)
      .map(p => p.split(' ')[0])
      .map(type => {
        const s = structs[type]
        return s !== undefined ? s.tuple : type
      })

    const contractCall = `${interfaceName.replace('IMatryx', '')}.${fnName}`
    const call = `${fnName}(${argTypes.join(',')})`
    const selector = sha3(call).substr(0, 10)

    selectors[selector] = contractCall
  }
}

libReg.lastIndex = 0
while ((match = libReg.exec(source))) {
  const [, libName, libContent] = match
  if (ignore.includes(libName)) continue

  while ((match = fnReg.exec(libContent))) {
    if (match[0].includes('internal')) continue

    if (!match[2]) match[2] = ''

    const name = match[1]
    const params = match[2].split(/, ?/).map(p => p.split(' '))
    const injParams = params.filter(p => p.includes('storage')).map(p => slots[p[0]])
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

    // calculate dynamic param word indices, accounting for struct sizes
    let i = 0
    const dynParams = []
    const numDyn = nonStorage.reduce((c, type) => {
      if (!dynTypesReg.test(type)) {
        i += sizeof(type)
        return c
      }

      if (type && structs[type] !== undefined) {
        if (!structs[type].dynamic) {
          i += structs[type].words
          return c
        }
      }

      dynParams.push(i)
      i++
      return c + 1
    }, 0)

    console.log(`${libName}.${name}: inject ${numInject}, dynamic ${numDyn}${numDyn ? ` at ${dynParams.join(' ')}` : ''}`)
    console.log(fromSel, fromSig)
    console.log(toSel, toSig)
    console.log(' ')

    if (!batch) {
      const comment = `// ${libName.replace('Lib', 'Matryx')}.${name}`
      const fnData = `['${toSel}', [${injParams}], [${dynParams}]]`
      const call = `system.addContractMethod(${version}, stringToBytes('${libName}'), '${fromSel}', ${fnData})`

      setup.push(comment)
      setup.push(call)
    } else {
      methods.push({ libName, fromSel, toSel, injParams, dynParams })
    }
  }
  if (!batch) setup.push('')
}

if (batch) {
  // sort / group methods
  methods.sort((a, b) => {
    let dir = 0
    if (!dir && a.libName != b.libName) dir = a.libName > b.libName ? 1 : -1
    if (!dir && a.injParams != b.injParams) dir = a.injParams > b.injParams ? 1 : -1
    if (!dir && a.dynParams != b.dynParams) dir = a.dynParams > b.dynParams ? 1 : -1
    return dir
  })

  // split methods by group
  groups = []
  for (let m of methods) {
    let pushed = false
    for (let g of groups) {
      if (g[0].libName !== m.libName) continue
      if (g[0].injParams.toString() !== m.injParams.toString()) continue
      if (g[0].dynParams.toString() !== m.dynParams.toString()) continue
      g.push(m)
      pushed = true
    }
    if (!pushed) groups.push([m])
  }

  for (let g of groups) {
    const fromSels = g.map(m => `'${m.fromSel}'`)
    const toSels = g.map(m => `'${m.toSel}'`)
    const m = g[0]
    const fnData = `['0x00', [${m.injParams}], [${m.dynParams}]]`
    const command = `system.addContractMethods(${version}, stb('${m.libName}'), [${fromSels}], [${toSels}], ${fnData}, { gasLimit: 3e6 })`
    setup.push(command)
  }
}

fs.writeFileSync('./setup-commands', setup.join('\n'))
fs.writeFileSync('./selectors.json', JSON.stringify(selectors, 0, 2))
console.log(`completed in ${Date.now() - st} ms`)

generate(version)
