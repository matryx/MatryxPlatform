var Ownable = artifacts.require('Ownable');

var ownable;
var owner;

contract('Ownable', function(accounts){
  it("The owner should be accounts[0]", async function() {
      ownable = await Ownable.new({from: web3.eth.accounts[0]});
      owner = await ownable.owner();
      assert.equal(owner, accounts[0], "The owner of the contract should be " + accounts[0]); 
  });
});

contract('Ownable', function(accounts) {
	it("The owner should be accounts[1]", async function() {
		ownable = await Ownable.new({from: web3.eth.accounts[1]});
		owner = await ownable.owner();
		// test if the owner is who they should be
		assert.equal(owner, accounts[1], "The owner of the contract should be " + accounts[1]);
	});
});

contract('Ownable', function(accounts) {
	it("The owner should be accounts[3] after the transfer", async function() {
		ownable = await Ownable.new({from: web3.eth.accounts[0]});
		await ownable.transferOwnership(accounts[3]);
		owner = await ownable.owner();
		assert.equal(owner, accounts[3], "The owner of the contract should be " + accounts[3]);
	});
});
