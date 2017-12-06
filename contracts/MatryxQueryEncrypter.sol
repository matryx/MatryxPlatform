pragma solidity ^0.4.18;

//
// The lookup contract for storing both the query and responder addresses
//
import "./MatryxOracleMessenger.sol";

// Readies and takes query results from the web client.
contract MatryxQueryEncrypter {

  // The owner of this contract. i.e. The single TinyOracle contract.
  MatryxOracleMessenger owner;
  // The address of the querier (user) for the query this resolver has been given.
  address querier;
  // The id of the query (this contract generates this value).
  uint256 queryID;
  // The response. The server 
  bytes32 response;

  function MatryxQueryEncrypter(address _querier) public {
    owner = MatryxOracleMessenger(msg.sender);
    querier = _querier;
  }

  modifier owneronly { 
    require(msg.sender == address(owner));
    _;
  }

  modifier querierOnly {
    require(msg.sender == querier);
    _;
  }

  function query(bytes32 _query) owneronly public returns (uint256 _id) {
    // Set the queryID for this QueryResolver by hashing:
    // 1) The current blocknumber
    // 2) The time
    // 3) The query itself
    // 4) The sender of the query.
    queryID = uint256(keccak256(block.number, now, _query, msg.sender));

    // Return to the MatryxOracle the queryID we just created.
    return (queryID);
  }

  function kill() owneronly public {
    selfdestruct(msg.sender);
  }
}
