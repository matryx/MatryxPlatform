The Commit System
=================

The commit system is a collaborative content and IP tracking tool that allows value to be assigned and distributed across sequences of innovation.

Commits consist of an IPFS content hash, a value, and a group. Groups are used to allow people to work freely off of each other; in order to make a commit as a child of another one, you must either be in the parent commit’s group, or you can pay to fork off of it and start work with a new group.


Creating your first Commit
^^^^^^^^^^^^^^^^^^^^^^^^^^

To create your first commit, call:

.. code-block:: Solidity

	commit.initialCommit(content, value, groupName)

Where ``content`` is the IPFS hash of your content, ``value`` is an 18-decimal-precision MTX amount and ``groupName`` is the name of the work group that you would like to begin this work with.

Commit Groups
^^^^^^^^^^^^^

To send a join group request, call:

.. code-block:: Solidity

	commit.requestToJoinGroup(groupName)

Where ``groupName`` is the name of the group you would like to join. This will generate an event that members of the group will be able to see. Once this event has been noticed by members of the group, those members will have the opportunity to add you to the group.
Once you become a part of the group, you will be able to make new commits along the same commit chain without having to pay your group members the value of their commits.

.. warning:: Group members cannot be removed from the group once you have added them.

Forking Commits
^^^^^^^^^^^^^^^

Forking a commit incurs the cost of the commit chain’s total value in MTX. If the chain is longer than the platform’s current maximum distribution depth, only the chain’s MTX value from the forked commit to that depth will be withdrawn.

To fork off from a commit, call:
commit.fork(contentHash, value, parentHash, group)

Unlike creating an initial commit, forking from a previous commit entails providing ``parentHash``: the hash of the commit that this commit will fork from. Additionally, forking allows you to select an alternate group to work with.