pragma solidity ^0.4.18;

import "./MatryxOracle.sol";

contract MatryxPlatform is MatryxOracle {
  
  mapping(address => uint256) addressForBalance;

  function PrepareBalance() public returns (bool _success)
  {
      this.Query(0x0);
      return true;
  }

  function CheckBalance() public returns (uint256 _balance)
  {
  		return addressForBalance[msg.sender];
  }
}