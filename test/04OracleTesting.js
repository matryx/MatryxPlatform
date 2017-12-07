var utils = require("./utils.js");
var MatryxAlpha = artifacts.require("MatryxPlatform");

contract('MatryxPlatform', function(accounts)
{

	// it("The oracle system produces a valid query.", function()
	// {
	// 	return MatryxAlpha.deployed().then(function(instance)
	// 	{
	// 		platform = instance;
	// 		return platform.prepareBalance.call(accounts[0]);
	// 	});
	// });

	// it("The platform triggers a TournamentCreated event per tournament.", function()
	// {
	// 	return MatryxAlpha.deployed().then(function(instance)
	// 	{
	// 		platform = instance;
	// 		var balanceQueryEvent = platform.QueryPerformed({_from:web3.eth.coinbase},{fromBlock: 0, toBlock: 'latest'});
	// 		return platform.createTournament("new tournament", "external address", 100, 1)
	// 		.then(() => 
	// 			{
	// 				// Additionally you can start watching right away, by passing a callback:
	// 				web3.eth.filter('latest', function(error, result){
	// 					if (!error)
	// 					{
	// 					  	console.log(result);
	// 					}
	// 				});
	// 			});
	// 	});
	// });
});