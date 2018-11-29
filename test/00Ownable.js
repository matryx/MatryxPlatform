var Ownable = artifacts.require('Ownable')

var ownable
var owner

contract('Ownable', function(accounts){
  it("The owner should be accounts[0]", async function() {
      ownable = await Ownable.new({from: web3.eth.accounts[0]})
      owner = await ownable.owner()
      assert.equal(owner, accounts[0], "The owner of the contract should be " + accounts[0])
  })
})

contract('Ownable', function(accounts) {
	it("The owner should be accounts[1]", async function() {
		ownable = await Ownable.new({from: web3.eth.accounts[1]})
		owner = await ownable.owner()
		// test if the owner is who they should be
		assert.equal(owner, accounts[1], "The owner of the contract should be " + accounts[1])
	})
})

contract('Ownable', function(accounts) {
	it("The owner should be accounts[3] after the transfer", async function() {
		ownable = await Ownable.new({from: web3.eth.accounts[0]})
		await ownable.transferOwnership(accounts[3], {from: web3.eth.accounts[0]})
		owner = await ownable.owner()
		assert.equal(owner, accounts[3], "The owner of the contract should be " + accounts[3])
	})

	//testing require statements
	it("Unable to transfer ownership to null account", async function() {
		ownable = await Ownable.new({from: web3.eth.accounts[0]})
		try {
    			await ownable.transferOwnership(0x0, {from: web3.eth.accounts[0]})
   				assert.fail('Expected revert not received')
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0
    			assert(revertFound, 'Unable to catch revert')
  			}
	})

	it("Only the current owner is able to transfer ownership", async function() {
		ownable = await Ownable.new({from: web3.eth.accounts[0]})
		try {
				//accounts[3] should not be able to call transfer ownership
    			await ownable.transferOwnership(accounts[3], {from: accounts[1]})
   				assert.fail('Expected revert not received')
  			} catch (error) {
    			const revertFound = error.message.search('revert') >= 0
    			assert(revertFound, 'Unable to catch revert')
  			}
	})
})
