Creating a Tournament
=====================

.. note::
    You must be a peer to create a tournament.

To create a tournament, call  the ``createTournament`` function on the platform, passing in the category (string), tournament name (string), externalAddress (bytes), Bounty (uint256) and entryFee (uint256). The full signature of the function is:

.. code-block:: Solidity

	function createTournament(string _category, string _tournamentName, 
	bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee) 
	public onlyPeerLinked(msg.sender) returns (address _tournamentAddress)