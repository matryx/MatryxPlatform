var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var SafeMath128 = artifacts.require("../libraries/math/SafeMath128.sol");
var SubmissionTrust = artifacts.require("./reputation/SubmissionTrust.sol");

module.exports = function(deployer) {
		deployer.link(SafeMath, SubmissionTrust);
		deployer.link(SafeMath128, SubmissionTrust);
		return deployer.deploy(SubmissionTrust);
};