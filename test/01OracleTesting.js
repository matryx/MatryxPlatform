var utils = require("./utils.js");
var MatryxAlpha = artifacts.require("MatryxPlatform");

contract('MatryxPlatform', function(accounts) {
	let platform;
	let queryId;

	//Testing oracle with unused account with empty balance - accounts[6]
	it("The oracle system produces a valid query id.", async function() {
		web3.eth.defaultAccount = web3.eth.accounts[6]
		platform = await MatryxAlpha.deployed({from: accounts[6]});
		let balance = await platform.getBalance.call({from: accounts[6]});
		//console.log(balance);

		let prepareBalanceTx = await platform.prepareBalance(0x0, {from: accounts[6]});
		queryId = prepareBalanceTx.logs[0].args.id;

		assert.notEqual(queryId.valueOf(), 0, "The query id should not be 0");
	});

	it("Query id exists, platform owner tries to store value under id", async function() {
		web3.eth.defaultAccount = web3.eth.accounts[6]
		console.log(queryId.valueOf());
		await platform.storeQueryResponse(queryId.valueOf(), 5);
		let balance = await platform.getBalance.call({from: accounts[6]});
		console.log(balance);
		assert.equal(balance.valueOf(), 5, "Balance should be 5.");
	});
});