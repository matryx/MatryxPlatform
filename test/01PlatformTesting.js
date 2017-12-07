var MatryxAlpha = artifacts.require("MatryxPlatform");

contract('MatryxPlatform', function(accounts)
{
	it("The number of tournaments should be 0.", function() {
    return MatryxAlpha.deployed().then(function(instance) {
      return instance.tournamentCount();
    }).then(function(count) {
    	assert.equal(count.valueOf(), 0, "The tournament count was non-zero to begin with.");
    });
  });
});