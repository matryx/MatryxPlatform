Entering Matryx
================

Matryx is a decentralized application for solving difficult scientific problems. The Matryx’s commit system allows you to timestamp and value your work on the Ethereum blockchain, providing you with immutable proof of ownership over your content. The Matryx bounty system enables users to place bounties on scientific problems and to award creative solutions, allowing people to build up chains of work and be rewarded for their contributions.

Welcome!

To start using the platform, you first need to enter Matryx with the Ethereum address that you intend to use on the platform. Entering Matryx is as simple as running the following:

.. code-block:: Solidity

	platform.enterMatryx()

Congrats! You have now entered the Matryx platform. We're glad to have you on board.

Approving Platform Transactions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To interact with the platform, you first need to tell ``MatryxToken`` that you approve of ``MatryxPlatform``, and specify a number of ``tokens`` you want to approve. This is done by calling

.. code-block:: Solidity

	token.approve(MatryxPlatform.address, tokens)

Great! Now that you know how to approve platform transactions, you can create tournaments, make submissions, and interact with other platform users.

Entering a Tournament
^^^^^^^^^^^^^^^^^^^^^

To enter a tournament that you'd like to participate in, you can make the following call:

.. code-block:: Solidity

	tournament.enter()

Whenever you enter a tournament, you will have to pay the tournament entry fee designated by the tournament creator, so you need to first approve at least that many MTX tokens. To check a tournament's entry fee before entering, you can call

.. code-block:: Solidity

	tournament.getEntryFee()

The value returned here is the Wei equivalent of MTX, so a single MTX has 1e18 digit precision. This fee is incurred solely to prevent malicious actors from attempting a cross-tournament Sybil attack, and it will be returned to you at the end of the tournament (or whenever you choose to exit the tournament).

Congratulations! You have now entered your first Matryx tournament. Assemble a team; let's get solving!

