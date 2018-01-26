var Ownable = artifacts.require('Ownable');

var ownable;
var owner;

contract('Ownable', function(accounts){
  it("The owner should be accounts[0]", async function() {
      ownable = await Ownable.new({from: accounts[0]});
      // get the owner
      owner = await ownable.getOwner.call();
      // test if the owner is who they should be
      assert.equal(owner.valueOf(), accounts[0], "The owner of the contract should be " + accounts[0]); 
  });
});

contract('Ownable', function(accounts) {
	it("The owner should be accounts[1]", async function() {
		ownable = await Ownable.new({from: accounts[1]});
		// get the owner
		owner = await ownable.getOwner.call();
		// test if the owner is who they should be
		assert.equal(owner.valueOf(), accounts[1], "The owner of the contract should be " + accounts[1]);
	});
});

contract('Ownable', function(accounts) {
	it("The owner should be accounts[3] after the transfer", async function() {
		ownable = await Ownable.new();
		await ownable.transferOwnership(accounts[3]);
		owner = await ownable.getOwner.call();
		assert.equal(owner.valueOf(), accounts[3], "The owner of the contract should be " + accounts[3]);
	});
});
