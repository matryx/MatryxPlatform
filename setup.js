q = []
// proxyArtifact = JSON.parse(fs.readFileSync('./build/contracts/MatryxProxy.json', 'utf-8'))
// if (typeof updatedAt == 'undefined') updatedAt = 0
// fresh = proxyArtifact.updatedAt !== updatedAt
// updatedAt = proxyArtifact.updatedAt
fresh = typeof proxy == "undefined"

if (fresh) q.push("proxy = contract(MatryxProxy.address, MatryxProxy)")
if (fresh) q.push("proxy.createVersion(1)")
if (fresh) q.push("proxy.setVersion(1)")

q.push("proxy.setContract(1, stringToBytes('MatryxPlatform'), MatryxPlatform.address)")
q.push("proxy.setContract(1, stringToBytes('LibPlatform'), LibPlatform.address)")
q.push("proxy.setContract(1, stringToBytes('LibTournament'), LibTournament.address)")
q.push("proxy.setContract(1, stringToBytes('LibRound'), LibRound.address)")
q.push("proxy.setContract(1, stringToBytes('LibSubmission'), LibSubmission.address)")

// Platform.createTournament
q.push("proxy.addContractMethod(1, stringToBytes('LibPlatform'), '0x9dae6081', ['0xcb322b65', [0, 3], []])")
// Platform.enterTournament
q.push("proxy.addContractMethod(1, stringToBytes('LibPlatform'), '0xf7468a3c', ['0xa8b4a6d7', [3], []])")
// Platform.getAllTournaments
q.push("proxy.addContractMethod(1, stringToBytes('LibPlatform'), '0xecccc6da', ['0x32676383', [3], []])")

// Tournament.getOwner
q.push("proxy.addContractMethod(1, stringToBytes('LibTournament'), '0x893d20e8', ['0x400e8212', [3], []])")
// Tournament.getRounds
q.push("proxy.addContractMethod(1, stringToBytes('LibTournament'), '0x6984d070', ['0x6a83c335', [3], []])")
// Tournament.createRound
q.push("proxy.addContractMethod(1, stringToBytes('LibTournament'), '0x3496e523', ['0x6e5a6d4e', [0, 3], []])")
// Tournament.createSubmission
q.push("proxy.addContractMethod(1, stringToBytes('LibTournament'), '0x35b9c23b', ['0x2e8796ce', [0, 3], []])")

// Round.getTournament
q.push("proxy.addContractMethod(1, stringToBytes('LibRound'), '0xe76c293e', ['0x462fda35', [3], []])")

// Submission.getTournament
q.push("proxy.addContractMethod(1, stringToBytes('LibSubmission'), '0xe76c293e', ['0x462fda35', [3], []])")
// Submission.getRound
q.push("proxy.addContractMethod(1, stringToBytes('LibSubmission'), '0x9f8743f7', ['0xb0cad189', [3], []])")

q.push("p = contract(MatryxPlatform.address, IMatryxPlatform)")

;(async () => { for (let cmd of q) await eval(cmd) })()
