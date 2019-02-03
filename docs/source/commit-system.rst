The Commit System
=================

The commit system is a collaborative content and IP tracking tool that allows value to be assigned and distributed across sequences of innovation.

Commits consist of an IPFS content hash, a value, and a group. Groups are used to allow people to team up and work freely off of each other's commits. In order to make a commit off of a parent commit, you must either be in the parent commit’s group, or pay the value of the commit chain to fork off of it and start working with a new group.


Committing Your Work
^^^^^^^^^^^^^^^^^^^^^

To create a commit, call:

.. code-block:: Solidity

	commit.initialCommit(content, value, groupName)

Where ``content`` is the IPFS hash of your content, ``value`` is an 18-decimal-precision MTX amount that indicates how much your commit is worth, and ``groupName`` is the name of the group that you would like to begin this work with.

Commit Groups
^^^^^^^^^^^^^

To send a join group request, call:

.. code-block:: Solidity

	commit.requestToJoinGroup(groupName)

Where ``groupName`` is the name of the group you would like to join. This will generate an event that members of the group will be able to see. Those members will then have the opportunity to add you to the group, allowing you to freely make commits off of the chain.

.. warning:: Group members cannot be removed from a group after being added.

Forking Commits
^^^^^^^^^^^^^^^

Forking a commit costs the total MTX value of the commit chain. If the chain is longer than the platform’s current maximum distribution depth, only the chain’s MTX value from the forked commit to that depth will be withdrawn.

To fork from a commit, call:

.. code-block:: Solidity

	commit.fork(contentHash, value, parentHash, group)

Unlike creating an initial commit, when forking from a previous commit you must provide ``parentHash``, the hash of the parent commit that the new commit will fork from. Additionally, forking allows you to select an alternate group to work with.