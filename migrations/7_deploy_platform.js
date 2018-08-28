var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");
var LibTournamentEntrantMethods = artifacts.require("../libraries/tournament/LibTournamentEntrantMethods.sol");
var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");
var { tokenAddress } = require('../truffle/network');
const LibCategories = artifacts.require("../libraries/platform/LibCategories.sol")


module.exports = function (deployer) {
	deployer.link(LibCategories, MatryxPlatform);
	return deployer.deploy(MatryxPlatform, tokenAddress, MatryxTournamentFactory.address, MatryxSubmissionFactory.address).then((platform) => {

		// Supply the platform address to the contracts that need it.
		MatryxTournamentFactory.deployed().then((tournamentFactory) => {
			tournamentFactory.setPlatform(MatryxPlatform.address);
		});

		// TODO: Make this particular call in the platform constructor by passing iterable mapping struct
		// leave the set and get methods though :) Could be useful for manual things later (think: modifiers for registers of allowed addresses)
		platform.setContractAddress(web3.sha3("LibTournamentEntrantMethods"), LibTournamentEntrantMethods.address);
		platform.setTokenAddress(tokenAddress);
	});
}
