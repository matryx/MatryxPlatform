Tournament Administration
=========================

Creating a Tournament
^^^^^^^^^^^^^^^^^^^^^

To create a tournament, you can call the ``createTournament`` function on the platform. The function signature is: 

.. code-block:: Solidity

	function createTournament(tournamentData, roundData) returns (address _tournamentAddress)

Where ``TournamentData`` and ``RoundData`` are stuctured as follows:

.. code-block:: Solidity

    struct TournamentData
    {
        bytes32 category;
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
        uint256 initialBounty;
        uint256 entryFee;
    }

    struct RoundData
    {
        uint256 start;
        uint256 end;
        uint256 reviewPeriodDuration;
        uint256 bounty;
        bool closed;
    }

These structs contain all the information we need about the tournament that you are about to create and the first round that will kick off when the tournament starts. You can add more funds to the tournament bounty at any point, but you cannot remove funds from it after you make the ``createTournament`` call, so choose your initial bounty wisely!

Similarly, you cannot remove funds from the share of the tournament bounty you assign to the first round, and you won’t be able to edit the round details after the round has started. Be sure to enter a reasonable amount of time (in seconds) for the round’s start and end time, as well as its review period. You’ll need some time to look over the submissions and choose your round winners before the review period ends!

.. note:: The tournament and round bounty will be visible to any users looking to enter your tournament, as well as the tournament and round details.

Your Tournaments
^^^^^^^^^^^^^^^^

Congratulations, you have now created your first tournament! You can access all of your tournaments with the following call to the platform:

.. code-block:: Solidity

	platform.myTournaments()

The last address that this call returns is the address of your most recently created tournament.
You can also check the current state of your tournament with

.. code-block:: Solidity

	tournament.getState()

This will tell you whether your tournament is Not Yet Open, On Hold, Open, Closed, or Abandoned.

Updating Tournament Details
^^^^^^^^^^^^^^^^^^^^^^^^^^^

To edit the details of your tournament, you can call the ``update`` function. The function signature is:

.. code-block:: Solidity
	
	function update(tournamentModificationData)

Where ``TournamentModificationData`` is the following:

.. code-block:: Solidity

    struct TournamentModificationData
    {
        bytes32 category;
        bytes32[3] title;
        bytes32[2] descriptionHash;
        bytes32[2] fileHash;
        uint256 entryFee;
        bool entryFeeChanged;
    }

Adding Funds to your Tournament
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Suppose you wanted to add one-eighteenth of a MTX to a tournament's bounty. You can call the ``addFunds`` function as follows:

.. code-block:: Solidity

	tournament.addFunds(1)

.. warning::  Remember that you cannot remove funds from a tournament's bounty after you’ve added them.

Choosing Winners
^^^^^^^^^^^^^^^^

Once the round enters its review period, users will no longer be able to make any more submissions, and all the submissions that participants have made will become accessible to you. It is now time to review the submissions and select some winners.

To get all the submissions made to this round, you can call

.. code-block:: Solidity
	
	round.getSubmissions()

To choose your round winners, you can call ``selectWinners`` on the tournament. The function signature of ``selectWinners`` is the following:

.. code-block:: Solidity
	
	function selectWinners(selectWinnersData, roundData)

Where ``SelectWinnersData`` is 

.. code-block:: Solidity

    struct SelectWinnersData
    {
        address[] winningSubmissions;
        uint256[] rewardDistribution;
        uint256 selectWinnerAction;
        uint256 rewardDistributionTotal;
    }

and ``RoundData`` is 

.. code-block:: Solidity

    struct RoundData
    {
        uint256 start;
        uint256 end;
        uint256 reviewPeriodDuration;
        uint256 bounty;
        bool closed;
    }

In ``SelectWinnersData``, you can specify which submissions get rewarded and how much MTX is assigned to each one as the first two parameters of the struct; the first parameter contains all the winning submissions' addresses, and the second contains the reward each one will get, respectively, expressed as a percentage or a propoprtion of the total round bounty.

When you choose your round winners, you can choose to wait until the end of the review period for a new round to start automatically, start the next round immediately after selecting the winners, or close the tournament. The action you choose to proceed with (``0``, ``1`` or ``2``, respectively) is passed as the third parameter. If you choose to start the next round immediately when you select the winners, it will be initialized with the round data that you provide. If you choose to wait until the end of the review period, the next round will automatically be created as an identical copy of the last round.
The last parameter is simply the sum of all the values in your ``rewardDistribution`` array. This value is also calulated internally within the platform later, so feel free to ignore it for now.

.. warning:: Once you close the tournament, you can’t open it up again. Any remaining funds that might still be in the tournament’s balance will be evenly distributed among the last round’s winners when you close the tournament.

.. warning:: If the round's review period ends and you still have not chosen any winners, the tournament will be considered Abandoned, and any remaining funds in the tournament's balance will be evenly distributed among all the round participants automatically.
