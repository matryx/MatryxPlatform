const SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
const Strings = artifacts.require("../libraries/strings/strings.sol");
const LibSubmission = artifacts.require("../libraries/submission/LibSubmission.sol");
const LibSubmissionTrust = artifacts.require("../libraries/submission/LibSubmissionTrust.sol");
const MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
const MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
const MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function (deployer) {
	deployer.link(LibSubmission, MatryxSubmissionFactory);
	deployer.link(LibSubmissionTrust, MatryxSubmissionFactory);
	return deployer.deploy(MatryxSubmissionFactory);
};
