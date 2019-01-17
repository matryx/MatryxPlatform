Tournament Administration
=========================

Creating a Tournament
^^^^^^^^^^^^^^^^^^^^^

To create a tournament, you can call the ``createTournament`` function on the platform as follows:

.. code-block:: Solidity

	platform.createTournament(tournamentData, roundData)

Where ``TournamentData`` and ``RoundData`` are stuctured as follows:

.. code-block:: Solidity

    struct TournamentData
    {
        bytes32[3] title;
        bytes32 category;
        bytes32[2] descHash;
        bytes32[2] fileHash;
        uint256 bounty;
        uint256 entryFee;
    }

    struct RoundData
    {
        uint256 start;
        uint256 end;
        uint256 review;
        uint256 bounty;
    }

These structs contain all the information we need about the tournament that you are about to create and the first round that will kick off when the tournament begins. You can add more funds to the tournament bounty at any point, but you cannot remove funds from it after you make the ``createTournament`` call, so choose your initial bounty wisely!

Similarly, you cannot remove funds from the share of the tournament bounty you assign to the first round, and you won’t be able to edit the round details after the round has started. Be sure to enter a reasonable amount of time (in seconds) for the round’s start and end time, as well as its review period. You’ll need some time to look over the submissions and choose your round winners before the review period ends!

.. note:: The tournament and round bounty will be visible to any users looking to enter your tournament, as well as the tournament and round details.

You can always check the current state of your tournament with

.. code-block:: Solidity

	tournament.getState()

This will tell you whether your tournament is Not Yet Open, On Hold, Open, Closed, or Abandoned.

Your Tournaments
^^^^^^^^^^^^^^^^

Congratulations, you have now created your first tournament! You can access all of your user information, including any tournaments that you have created or entered, with the following calls to the MatryxUser contract:

.. code-block:: Solidity

	users.getTournaments(userAddress)
	users.getTournamentsEntered(userAddress)

If you pass your own address as the ``userAddress``, the last address that the ``getTournaments`` call returns is the address of your most recently created tournament.

Updating Tournament Details
^^^^^^^^^^^^^^^^^^^^^^^^^^^

To edit the data of your tournament, you can call the ``updateDetails`` function as follows:

.. code-block:: Solidity

	tournament.updateDetails(tournamentData)

Where ``tournamentData`` is the same data struct used to create the tournament originally. The ``bounty`` field, however, will not change when you try to modify the tournament's data.

Adding Funds to your Tournament
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Suppose you wanted to add funds to a tournament's bounty. You can call the ``addFunds`` function as follows:

.. code-block:: Solidity

	tournament.addFunds(1)

This function transfers funds to the specified tournament. To allocate these new funds to the current round, you can call the ``transferToRound`` function.

.. code-block:: Solidity

    tournament.transferToRound(1)

The added funds will now also be distributed to this round's winners when it is time to reward their submissions.

.. warning::  Remember that you cannot remove funds from a tournament's bounty after you’ve added them or remove funds from a round after it has already started.

Choosing Winners
^^^^^^^^^^^^^^^^

Once the round enters its review period, users will no longer be able to make any more submissions, and all the submissions that participants have made will become accessible to you. It is now time to review the submissions and select some winners.

To get all the submissions made to this round, you can call

.. code-block:: Solidity

	round.getSubmissions(0, 0)

The first parameter indicates the starting index of the submissions to return, and the second parameter indicates the number of submissions to return starting at that index. To get all of the round's submissions, you can use the parameters ``(0, 0)``.

To choose your round winners, you can call ``selectWinners`` on the tournament as follows:

.. code-block:: Solidity

	tournament.selectWinners(winnersData, roundData)

Where ``winnersData`` is

.. code-block:: Solidity

    struct WinnersData
    {
        address[] submissions;
        uint256[] distribution;
        uint256 action;
    }

where action represents an enumerated value from the following enum

.. code-block:: Solidity

    enum SelectWinnerAction { DoNothing, StartNextRound, CloseTournament }

and ``RoundData`` is

.. code-block:: Solidity

    struct RoundData
    {
        uint256 start;
        uint256 end;
        uint256 review;
        uint256 bounty;
    }

In ``winnersData``, you can specify which submissions get rewarded and how much MTX is assigned to each one; the first parameter contains all the winning submissions' addresses, and the second contains the reward each one will get, respectively, expressed as a percentage or a propoprtion of the total round bounty.

When selecting round winners, you have three options for how to proceed with the tournament: you can choose to wait until the end of the review period for the next round to start, to start the next round immediately after selecting the winners, or to close the tournament. The action you choose (``0``, ``1`` or ``2``, representing SelectWinnerAction.DoNothing, SelectWinnerAction.StartNextRound and SelectWinnerAction.CloseTournament, respectively) is passed as the third parameter of winnersData and indicates how you would like to proceed. If you choose to wait until the end of the review period (DoNothing), the next round will automatically be created as an identical copy of the last round. If you choose to start the next round immediately when you select the winners (StartNextRound), the next round will be initialized with the round data that you provide. If you choose the third action, CloseTournament, the Tournament will close and the remaining bounty unallocated to any round will be allocated to the current round and used to award ``winnersData.submissions``.

.. warning:: Once you close the tournament, you can’t open it up again. Any remaining funds that might still be in the tournament’s balance will be evenly distributed among the last round’s winners when you close the tournament.

.. warning:: If the round's review period ends and you still have not chosen any winners, the tournament will be considered Abandoned, and any remaining funds in the tournament's balance will be uniformly allocated to all tournament participants for them to withdraw.
