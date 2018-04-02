var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var MatryxToken = artifacts.require("./MatryxToken/MatryxToken.sol");
var SubmissionTrust = artifacts.require("SubmissionTrust");
var RoundManagement = artifacts.require("./reputation/RoundManagement.sol");
var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxPeerFactory = artifacts.require("MatryxPeerFactory");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");

module.exports = function(deployer) {
	return deployer.deploy(MatryxPlatform, MatryxToken.address, MatryxPeerFactory.address, MatryxTournamentFactory.address, SubmissionTrust.address).then(() =>
	{
		// Supply the platform address to the contracts that need it.
		MatryxTournamentFactory.deployed().then((tournamentFactory) =>
		{
			tournamentFactory.setPlatform(MatryxPlatform.address);
		});

		MatryxPeerFactory.deployed().then((peerFactory) =>
		{
			peerFactory.setPlatform(MatryxPlatform.address);
		})
	});
};