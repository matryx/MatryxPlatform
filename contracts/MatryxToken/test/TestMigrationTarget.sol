pragma solidity ^0.5.0;

import "../UpgradeableToken.sol";

/**
 * A sample token that is used as a migration testing target.
 *
 * This is not an actual token, but just a stub used in testing.
 */
contract TestMigrationTarget is StandardToken, UpgradeAgent {

  UpgradeableToken public oldToken;

  uint public originalSupply;

  constructor(UpgradeableToken _oldToken) public {

    oldToken = _oldToken;

    // Let's not set bad old token
    require(address(oldToken) != address(0));

    // Let's make sure we have something to migrate
    originalSupply = _oldToken.totalSupply();
    require(originalSupply != 0);
  }

  function upgradeFrom(address _from, uint256 _value) public {
    require(msg.sender == address(oldToken)); // only upgrade from oldToken

    // Mint new tokens to the migrator
    totalSupply = totalSupply.add(_value);
    balances[_from] = balances[_from].add(_value);
    emit Transfer(address(0), _from, _value);
  }

  function() external {
    revert();
  }

}
