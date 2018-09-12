pragma solidity ^0.4.13;


/**
 * @title SafeMath128
 * @dev Math operations with safety checks that throw on error
 * @    Written for datatype uint128.
 */
library SafeMath128 {
  function mul(uint128 a, uint128 b) internal pure returns (uint128) {
    uint128 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint128 a, uint128 b) internal pure returns (uint128) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint128 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint128 a, uint128 b) internal pure returns (uint128) {
    assert(b <= a);
    return a - b;
  }

  function add(uint128 a, uint128 b) internal pure returns (uint128) {
    uint128 c = a + b;
    assert(c >= a);
    return c;
  }
}