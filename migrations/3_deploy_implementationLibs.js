const SafeMath = artifacts.require("../libraries/math/SafeMath.sol")
const SafeMath128 = artifacts.require("../libraries/math/SafeMath128.sol")
const LibSubmission = artifacts.require("../libraries/submission/LibSubmission.sol");
const LibSubmissionTrust = artifacts.require("../libraries/submission/LibSubmissionTrust.sol");
const LibTournamentAdminMethods = artifacts.require("../libraries/tournament/LibTournamentAdminMethods.sol")
const LibTournamentEntrantMethods = artifacts.require("../libraries/tournament/LibTournamentEntrantMethods.sol")
const LibTournamentStateManagement = artifacts.require("../libraries/tournament/LibTournamentStateManagement.sol")
const LibRound = artifacts.require("../libraries/round/LibRound.sol")

module.exports = function (deployer) {
    deployer.link(SafeMath, LibSubmissionTrust)
    deployer.link(SafeMath128, LibSubmissionTrust)
    return deployer.deploy(LibSubmissionTrust).then(async () => {
        deployer.link(LibSubmissionTrust, LibSubmission)
        await deployer.deploy(LibSubmission)
        await deployer.deploy(LibTournamentStateManagement)
        deployer.link(LibTournamentStateManagement, LibTournamentAdminMethods)
        await deployer.deploy(LibTournamentAdminMethods)
        deployer.link(LibTournamentStateManagement, LibTournamentEntrantMethods)
        await deployer.deploy(LibTournamentEntrantMethods)
        await deployer.deploy(LibRound)
    })
}
