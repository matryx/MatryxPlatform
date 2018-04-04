var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var SubmissionTrust = artifacts.require("SubmissionTrust");
var RoundManagement = artifacts.require("./reputation/RoundManagement.sol");
var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxPeerFactory = artifacts.require("MatryxPeerFactory");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");

module.exports = function(deployer) {
	return deployer.deploy(MatryxPlatform, "0x89c81164a847fae12841c7d2371864c7656f91c9", MatryxPeerFactory.address, MatryxTournamentFactory.address, SubmissionTrust.address).then(() =>
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