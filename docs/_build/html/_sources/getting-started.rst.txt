Diving into Matryx
==================

Matryx is a bounty-based platform that enables and incentivizes decentralized scientific collaboration in the form of tournaments and submissions, where all users participating in a tournament receive credit for their collaborations, and the tournament bounty is rightfully distributed among the chosen winners.

Welcome!

Becoming a MatryxPeer
^^^^^^^^^^^^^^^^^^^^^

To start using the platform, you first need to create a ``MatryxPeer`` for the Ethereum address you intend to use it with. You can do this as many times as you like with as many Ethereum addresses as you have, although the process does cost a bit of gas, so we're not sure why you would. That said, creating a peer is as simple as running the following:

.. code-block:: Solidity

	platform.createPeer({gas: platform.createPeer.estimateGas()})

Congrats! Now that you've created a peer, anytime you use the platform the positive and negative trust you earn through interacting with others will be aggregated by this ``MatryxPeer`` representation you've just created. For the ``MatryxPlatform`` Beta, we simply use ``MatryxPeer`` as a way to ensure that you cite your sources.

Approving Platform Transactions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To interact with the platform, you first need to tell ``MatryxToken`` that you approve of ``MatryxPlatform``, and specify a number of ``tokens`` you want to approve. This is done by calling 

.. code-block:: Solidity

	token.approve(MatryxPlatform.address, tokens)


Entering a Tournament
^^^^^^^^^^^^^^^^^^^^^

Now that you've done this, you should be able to enter the tournament. This is a call to the platform itself and goes like

.. code-block:: Solidity

	platform.enterTournament(tournament.address)

Whenever you enter a tournament, you will first have to pay the tournament entry fee designated by the tournament creator. To check a tournament's entry fee in advance, you can call

.. code-block:: Solidity

	tournament.getEntryFee()

The value returned here is the Wei equivalent of MTX, so a single unit is equal to one-eighteenth of a MTX. This fee is incurred solely to prevent malicious actors from attemping a cross-tournament Sybil attack and will be returned to you at the end of each tournament you enter.

Congratulations! You've now entered into your first Matryx Tournament! Assemble a team; Let's save the world!!

.. _diving_in