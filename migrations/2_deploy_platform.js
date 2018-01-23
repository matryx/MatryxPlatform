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
		deployer.deploy(Strings).then(() =>
		{
			deployer.deploy(MatryxSubmissionFactory).then(() => 
			{
				deployer.link(SafeMath, MatryxRoundFactory);
				deployer.deploy(MatryxRoundFactory, MatryxSubmissionFactory.address).then(() => 
				{
					deployer.link(SafeMath, MatryxTournamentFactory);
					deployer.link(Strings, MatryxTournamentFactory);
					deployer.deploy(MatryxTournamentFactory, MatryxRoundFactory.address).then(() =>
					{
						deployer.deploy(MatryxPlatform, MatryxTournamentFactory.address);
					});
				});
			});
		});
	});
};