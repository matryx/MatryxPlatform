var MatryxPlatform = artifacts.require("MatryxPlatform");

let platform

contract('MatryxPlatform', function(accounts)
{
	it("The number of tournaments should be 0.", function() {
    return MatryxPlatform.deployed().then(function(instance) {
      return instance.tournamentCount();
    }).then(function(count) {
    	assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
    });
  });
});

// contract('MatryxPlatform', function(accounts)
// {
// 	it("The number of tournaments should be 1.", 
// 		function() 
// 		{
// 			var platform;
// 		    return MatryxPlatform.deployed()
// 		    .then(
// 		    	function(instance)
// 		    	{	
// 		    		platform = instance;
// 		    		return instance.createTournament("Test Tournament 1", "external address 1", 100, 1, {from: accounts[0]});
// 		    	})
// 		    .then(
// 		    	function(_tournamentAddress)
// 		    	{
// 		    		return platform.tournamentCount();
// 		    	})
// 		    .then(function(count)
// 		    	{
// 		    		return assert.equal(count.valueOf(), 1, "The tournament count was not 1.");
// 		    	});
// 		});
// });


contract('MatryxPlatform', function(accounts) {
	var tournamentAddress;
  it("The number of tournaments should be 1.", async function() {
    platform = await MatryxPlatform.new()
    tournamentAddress = await platform.createTournament("tournament", "external address", 100, 2, {from: accounts[0]});
    let tournamentCount = await platform.tournamentCount();
    // assert there should be one tournament
    assert.equal(tournamentCount.valueOf(), 1, "The number of tournaments should be 1.");
  })

  it("The tournament should be able to be looked up by address.", async function() {
  	let tournamentExternalAddress = await platform.tournamentByAddress(tournamentAddress, {from: accounts[0]});
  	assert.equal(tournamentExternalAddress, "external address", "The tournament should exist.")
  })
});