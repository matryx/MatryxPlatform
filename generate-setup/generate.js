const fs = require('fs')

module.exports = function(version) {
  let template = fs.readFileSync('./setup-template', 'utf-8')
  let commands = fs.readFileSync('./setup-commands', 'utf-8').split('\n')

  commands = commands.map(l => {
    if (!l || l.substr(0, 2) === '//') return l
    return `q.push("${l}")`
  })

  template = template.replace(/\$VERSION/g, version)
  template = template.replace('$COMMANDS', commands.join('\n'))
  fs.writeFileSync('../setup', template)
}
