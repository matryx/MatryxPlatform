pragma solidity ^0.4.18;

import "./MatryxOracleMessenger.sol";

/// @title MatryxQueryEncrypter - Readies queries and takes query results from the web client.
/// @author Max Howard - <max@nanome.ai>
contract MatryxQueryEncrypter {

  // The owner of this contract. i.e. The single MatryxOracleMessenger contract.
  MatryxOracleMessenger owner;
  // The address of the querier (user) for the query this resolver has been given.
  address querier;
  // The id of the query (this contract generates this value).
  uint256 queryID;

  function MatryxQueryEncrypter(address _querier) public {
    owner = MatryxOracleMessenger(msg.sender);
    querier = _querier;
  }

  modifier owneronly { 
    require(msg.sender == address(owner));
    _;
  }

  /// @dev Generates a Query ID for this query and returns it.
  /// @param _query Query being made.
  /// @return _id Query ID generated.
  function generateQueryID(bytes32 _query) owneronly public returns (uint256 _id) {
    // Set the queryID for this QueryResolver by hashing:
    // 1) The current blocknumber
    // 2) The time
    // 3) The query itself
    // 4) The sender of the query.
    queryID = uint256(keccak256(block.number, now, _query, msg.sender));

    // Return to the MatryxOracleMessenger the queryID we just created.
    return (queryID);
  }
}