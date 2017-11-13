pragma solidity ^0.4.18;

import "./MatryxOracle.sol";

contract MatryxPlatform is MatryxOracle {
  
  mapping(address => bool) addressForHasMatryx;

  function getResponse(uint256 queryID) public returns (bytes32)
  {
      return queryResponses[queryID];
  }
}