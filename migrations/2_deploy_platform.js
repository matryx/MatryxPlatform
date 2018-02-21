var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

var MatryxToken = artifacts.require("MatryxToken");
var MatryxPlatform = artifacts.require("MatryxPlatform");
var MatryxTournament = artifacts.require("MatryxTournament");
var MatryxRound = artifacts.require("MatryxRound");
var MatryxTournamentFactory = artifacts.require("MatryxTournamentFactory");
var MatryxRoundFactory = artifacts.require("MatryxRoundFactory");
var MatryxSubmissionFactory = artifacts.require("MatryxSubmissionFactory");

module.exports = function(deployer) {
	deployer.deploy(MatryxToken).then(() => 
	{
		return deployer.deploy(SafeMath).then(() =>
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
						return deployer.deploy(MatryxTournamentFactory, MatryxToken.address, MatryxRoundFactory.address).then(() =>
						{
							return deployer.deploy(MatryxPlatform, MatryxToken.address, MatryxTournamentFactory.address);
						});
					});
				});
			});
		});
	})
};