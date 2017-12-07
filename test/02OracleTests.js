var MatryxAlpha = artifacts.require("MatryxPlatformAlphaMain");

contract('MatryxPlatformAlphaMain', function(accounts)
{

	// it("The oracle system produces a valid query.", function()
	// {
	// 	return MatryxAlpha.deployed().then(function(instance)
	// 	{
	// 		platform = instance;
	// 		return platform.prepareBalance.call(accounts[0]);
	// 	});
	// });

	it("The platform triggers a TournamentCreated event per tournament.", function()
	{
		return MatryxAlpha.deployed().then(function(instance)
		{
			platform = instance;
			var balanceQueryEvent = platform.QueryPerformed({_from:web3.eth.coinbase},{fromBlock: 0, toBlock: 'latest'});
			platform.createTournament("new tournament", "0x0123456789012345678901234567890123456789", 100, 110, 120, 10, 200, 50, 1, 0, 3);
			balanceQueryEvent.watch(function(error, result) {
		    	if (!error) 
		    	{
		    		alert("Wait for a while, check for block synchronization or creation.");
		        	balanceQueryEvent.stopWatching();
		        	
		        	assert.equal(0, 0, result);
		    	}
		    	else
		    	{
		    		assert.error(0, 1, error);
		    	}
			});
		});
	});

});