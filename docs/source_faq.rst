##########################
Frequently Asked Questions
##########################

***************
Basic Questions
***************

My transactions to create a new tournament keep reverting. Why is this?
=======================================================================

This will happen for one of two reasons.
1. You have not yet created a MatryxPeer for your Ethereum account.
2. You have not yet approved MatryxToken to spend the bounty you intend to issue in the tournament.

Why can't I enter this tournament?
==================================

The reasons for this are quite similar to the above. Either:
1. You have not yet created a MatryxPeer for your Ethereum account, or
2. You have not yet approved MatryxToken to take the tournament's entry fee from you.

******************
Advanced Questions
******************

How does a peer approving a reference affect the amount of MTX I earn?
======================================================================

Currently, our trust system is a lazy eigentrust implementation. In essence, the amount of MTX you earn directly from a submission is a weighted sum of the reputations of the reputations of the peers who approved your references (each reputation is itself weighted by the proportion of references approved and belonging to that single peer). Additionally, by approving a reference to a submission, you increase the reputation of the author of that submission. This means that if many people approve of you referencing their work, you in turn receive more MTX when others use your work. For more details about reputation, please see `Versions <./versions.html>`_


Can I edit a submission after a round has ended?
================================================

You can't edit any fields that would alter the judgement of the tournament creator in choosing your submission to win the round. You can however add and remove references at any time, even after a round has ended.