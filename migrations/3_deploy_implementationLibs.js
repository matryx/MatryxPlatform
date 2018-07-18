var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var SafeMath128 = artifacts.require("../libraries/math/SafeMath128.sol");
var SubmissionTrust = artifacts.require("./reputation/SubmissionTrust.sol");
var LibTournamentAdminMethods = artifacts.require("../libraries/tournament/LibTournamentAdminMethods.sol");
var LibTournamentEntrantMethods = artifacts.require("../libraries/tournament/LibTournamentEntrantMethods.sol");
var LibTournamentStateManagement = artifacts.require("../libraries/tournament/LibTournamentStateManagement.sol");
var LibRound = artifacts.require("../libraries/round/LibRound.sol");

module.exports = function (deployer) {
    deployer.link(SafeMath, SubmissionTrust);
    deployer.link(SafeMath128, SubmissionTrust);
    return deployer.deploy(SubmissionTrust).then(() => {
        return deployer.deploy(LibTournamentStateManagement).then(() => {
            deployer.link(LibTournamentStateManagement, LibTournamentAdminMethods);
            return deployer.deploy(LibTournamentAdminMethods).then(() => {
                deployer.link(LibTournamentStateManagement, LibTournamentEntrantMethods);
                return deployer.deploy(LibTournamentEntrantMethods).then(() => {
                    return deployer.deploy(LibRound);
                });
            });
        });
    });
};
