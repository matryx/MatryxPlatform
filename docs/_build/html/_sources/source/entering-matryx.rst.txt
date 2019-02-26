Entering Matryx
================

Matryx is a decentralized application for solving difficult scientific problems.
The Matryx’s commit system allows you to timestamp and value your work on the Ethereum blockchain, providing you with immutable proof of ownership over your content.
The Matryx bounty system enables users to place bounties on scientific problems and to award creative solutions, allowing people to build up chains of work and be rewarded for their contributions.

Welcome!

Approving Platform Transactions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To interact with the platform, you first need to tell ``MatryxToken`` that you approve of ``MatryxPlatform``, and specify a number of ``tokens`` you want to approve.
This is done by calling

.. code-block:: Solidity

	token.approve(MatryxPlatform.address, tokens)

Great! Now that you know how to approve platform transactions, you can create tournaments, make submissions, and interact with other platform users.
