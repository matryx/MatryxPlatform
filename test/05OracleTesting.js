var utils = require("./utils.js");
var MatryxAlpha = artifacts.require("MatryxPlatform");

contract('MatryxPlatform', function(accounts) {
	let platform;
	let queryId;
	it("The oracle system produces a valid query id.", async function() {
		platform = await MatryxAlpha.new();
		let prepareBalanceTx = await platform.prepareBalance(0x0, {from: accounts[0]});
		queryId = prepareBalanceTx.logs[0].args.id;

		assert.notEqual(queryId.valueOf(), 0, "The query id should not be 0");
	});

	it("Query id exists, platform owner tries to store value under id", async function() {
		await platform.storeQueryResponse(queryId.valueOf(), 5);
		let balance = await platform.getBalance.call();
		assert.equal(balance.valueOf(), 5, "Balance should be 5.");
	});
});