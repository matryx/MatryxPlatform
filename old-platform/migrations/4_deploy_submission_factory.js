const LibSubmission = artifacts.require("../libraries/submission/LibSubmission.sol");
const LibSubmissionTrust = artifacts.require("../libraries/submission/LibSubmissionTrust.sol");
const MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function (deployer) {
	deployer.link(LibSubmission, MatryxSubmissionFactory);
	deployer.link(LibSubmissionTrust, MatryxSubmissionFactory);
	return deployer.deploy(MatryxSubmissionFactory);
};
