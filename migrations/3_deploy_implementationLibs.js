var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var SafeMath128 = artifacts.require("../libraries/math/SafeMath128.sol");
var SubmissionTrust = artifacts.require("./reputation/SubmissionTrust.sol");
var LibTournamentAdminMethods = artifacts.require("../libraries/tournament/LibTournamentAdminMethods.sol");
var LibTournamentEntrantMethods = artifacts.require("../libraries/tournament/LibTournamentEntrantMethods.sol");
var LibTournamentStateManagement = artifacts.require("../libraries/tournament/LibTournamentStateManagement.sol");

module.exports = async function(deployer) {
		deployer.link(SafeMath, SubmissionTrust);
		deployer.link(SafeMath128, SubmissionTrust);
		await deployer.deploy(SubmissionTrust);
        await deployer.deploy(LibTournamentStateManagement);
        deployer.link(LibTournamentStateManagement, LibTournamentAdminMethods);
        await deployer.deploy(LibTournamentAdminMethods);
        deployer.link(LibTournamentStateManagement, LibTournamentEntrantMethods);
        return deployer.deploy(LibTournamentEntrantMethods);      
};