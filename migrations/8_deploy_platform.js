var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var LibTournamentEntrantMethods = artifacts.require("../libraries/tournament/LibTournamentEntrantMethods.sol");
var SubmissionTrust = artifacts.require("SubmissionTrust");
var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxPeerFactory = artifacts.require("MatryxPeerFactory");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");
var matryxTokenAddress = require('./tokenAddress');


module.exports = function(deployer) {
	return deployer.deploy(MatryxPlatform, matryxTokenAddress, MatryxPeerFactory.address, MatryxTournamentFactory.address, MatryxSubmissionFactory.address, SubmissionTrust.address).then((platform) =>
	{
		// Supply the platform address to the contracts that need it.
		MatryxTournamentFactory.deployed().then((tournamentFactory) =>
		{
			tournamentFactory.setPlatform(MatryxPlatform.address);
		});

		MatryxPeerFactory.deployed().then((peerFactory) =>
		{
			peerFactory.setPlatform(MatryxPlatform.address);
		});

		// TODO: Make this particular call in the platform constructor by passing iterable mapping struct
		// leave the set and get methods though :) Could be useful for manual things later (think: modifiers for registers of allowed addresses)
		platform.setContractAddress(web3.sha3("LibTournamentEntrantMethods"), LibTournamentEntrantMethods.address);
	});
}
