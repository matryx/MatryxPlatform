Tournament Administration
=========================

Creating a Tournament
^^^^^^^^^^^^^^^^^^^^^

To create a tournament, call  the ``createTournament`` function on the platform, passing in the category (string), tournament name (string), externalAddress (bytes), Bounty (uint256) and entryFee (uint256). The full signature of the function is:

.. code-block:: Solidity

	function createTournament(string _category, string _tournamentName, 
	bytes _externalAddress, uint256 _BountyMTX, uint256 _entryFee) 
	public onlyPeerLinked(msg.sender) returns (address _tournamentAddress)

An example of calling this through web3 might look like

.. code-block:: Solidity

	platform.createTournament.sendTransaction("nanotechnology", "Negative Refractive HMD Display", "QmNNdjUdpJjKwPjd61S2T93F93SS8XkMgG7Svem4Smpdv5", 100*(10**18), 0, {gas: 4500000})

.. note::
    You must be a peer to create a tournament.

Your Tournaments
^^^^^^^^^^^^^^^^

Great! Now that you've created your tournament, let's create its first round. To do this, lets first get the address of this most recent tournament of yours by calling

.. code-block:: Solidity

	platform.myTournaments()

Creating a Round
^^^^^^^^^^^^^^^^

After your createTournament transaction has gone through, you should see a new address appear on this list. This is the address of your tournament! You now have the option to set the number of rounds that this tournament will run for. By default, each tournament has 3 rounds, but you may change this number as you see fit. To do this, see Editing Tournaments and Submissions. Create a web3 representation of it and call the following to start a round:

.. code-block:: Solidity
	
	let numberOfRounds = tournament.maxRounds();
	let tournamentBounty = tournament.Bounty();
	let gasEstimate = tournament.createRound.estimateGas(tournamentBounty*(10**18)/numberOfRounds);
	tournament.createRound(tournamentBounty*(10**18)/numberOfRounds, {gas: gasEstimate})

Starting a Round
^^^^^^^^^^^^^^^^

Great! Now its time to start your tournament! Be sure to enter a reasonable amount of time (in seconds) for both the round's open-submission state as well as its review state.

.. code-block:: Solidity
	
	tournament.startRound(7257600, 1209600, {gas: tournament.startRound.estimateGas(7257600, 1209600)});


Choosing a Round Winner
^^^^^^^^^^^^^^^^^^^^^^^


Choosing a Tournament Winner
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Choosing a winner for the tournament is much like choosing a winner for a round. Simply call ``tournament.chooseWinner`` on the final round. This final round winner is considered the winner of the tournament. Calling ``tournament.isOpen`` should yield a false.
