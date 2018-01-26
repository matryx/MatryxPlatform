var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

var MatryxPlatform = artifacts.require("./MatryxPlatform.sol");
var MatryxTournament = artifacts.require("./MatryxTournament.sol");
var MatryxRound = artifacts.require('./MatryxRound.sol');
var MatryxTournamentFactory = artifacts.require('./MatryxTournamentFactory.sol');
var MatryxRoundFactory = artifacts.require('./factories/MatryxRoundFactory.sol');
var MatryxSubmissionFactory = artifacts.require('./factories/MatryxSubmissionFactory.sol');

module.exports = function(deployer) {
	deployer.deploy(SafeMath).then(() =>
	{
		return deployer.deploy(Strings).then(() =>
		{
			return deployer.deploy(MatryxSubmissionFactory).then(() => 
			{
				deployer.link(SafeMath, MatryxRoundFactory);
				return deployer.deploy(MatryxRoundFactory, MatryxSubmissionFactory.address).then(() => 
				{
					deployer.link(SafeMath, MatryxTournamentFactory);
					deployer.link(Strings, MatryxTournamentFactory);
					return deployer.deploy(MatryxTournamentFactory, MatryxRoundFactory.address).then(() =>
					{
						return deployer.deploy(MatryxPlatform, MatryxTournamentFactory.address).then(() =>
						{
							MatryxTournamentFactory.deployed().then((instance) => instance.setPlatform(MatryxPlatform.address));
						});
					});
				});
			});
		});
	});
};