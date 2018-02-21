pragma solidity ^0.4.13;

import "./MintableToken.sol";
import "./UpgradeableToken.sol";

/**
 * Matryx Ethereum token.
 */
contract MatryxToken is MintableToken, UpgradeableToken{

  string public name = "MatryxToken";
  string public symbol = "MTX";
  uint public decimals = 18;

  // supply upgrade owner as the contract creation account
  function MatryxToken() public UpgradeableToken(msg.sender) {

  }
}