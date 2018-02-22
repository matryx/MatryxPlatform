var SafeMath = artifacts.require("../libraries/math/SafeMath.sol");
var Strings = artifacts.require("../libraries/strings/strings.sol");

module.exports = function(deployer) {
	return deployer.deploy(SafeMath).then(() =>
	{
		return deployer.deploy(Strings);
	});
};	