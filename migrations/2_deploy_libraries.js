var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var SafeMath128 = artifacts.require("../libraries/math/SafeMath128.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

module.exports = function(deployer) {
	return deployer.deploy(SafeMath).then(() =>
	{
		return deployer.deploy(SafeMath128).then(() =>
		{
			return deployer.deploy(Strings);
		});
	});
};