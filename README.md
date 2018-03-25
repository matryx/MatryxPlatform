# Matryx Alpha Source Code - Develop Branch ![logo](https://github.com/matryx/matryx-alpha-source/blob/master/assets/Matryx-Logo-Black-1600px.png)

[![travisCI](https://travis-ci.org/matryx/matryx-alpha-source.svg?branch=develop)](https://travis-ci.org/matryx/matryx-alpha-source)
[![Telegram](https://img.shields.io/badge/chat-Telegram-blue.svg)](https://t.me/matryxai)
[![Latest News](https://img.shields.io/badge/Blog-Medium-yellowgreen.svg)](https://blog.matryx.ai/)


[![Jenkins coverage](https://img.shields.io/badge/coverage-Coming%20Soon-brightgreen.svg)](http://jenkins.matryx.ai/matryx-alpha-source/code-coverage)
[![Jenkins tests](https://img.shields.io/badge/tests-Coming%20Soon-brightgreen.svg)](http://jenkins.matryx.ai/matryx-alpha-source/tests)


## Introduction

> [Matryx.ai](https://www.matryx.ai): 
The Collaborative Research and Development Engine Optimized for Virtual Reality Interfaces

A full description about our platform is in our [whitepaper](https://matryx.ai/matryx-whitepaper.pdf).

This branch is where the latest development happens. As we develop code during our sprints for the next release, merge our user stories to this branch. So this is the most up to date branch. All merges undergo peer reviewed Pull Requests prior to being merged and must pass strict non-functional requirements such as code coverage.

For each tagged release, we will identify the major changes and add them to the CHANGELOG. Our next major release is March 31, 2018 so keep you eyes open for that huge push.

## How to use the platform on Develop Branch

Here you can test everything locally and run it as well. Running either our private chain or your own testRPC and then migrating the platform will be easy. 

```
truffle migrate
```

There are some major changes between Matryx Alpha v1 and the develop branch. In the first iteration since we focused on end-to-end integration, it is one main platform smart contract. Now we have multiple contracts such as Platform, Tournament, and Round.

This increases the complexity on the UI side to interact with the platform, but not that much. Coming soon is an API you can call for the 3 tiered system's contract addresses and related ABIs. 

If you migrate the Platform locally, we recommend using ```truffle console``` to interact with it's ease of use.
Here you can start typing MatryxPlatform and hit `tab` and it will be able to recognize the contract.
You can grab the ABI by calling `MatryxPlatform.abi` if you want to interact with it through a testRPC/ganache-cli/geth console.

### API

Visit the wiki for the [API Documentation](https://github.com/matryx/matryx-alpha-source/wiki/Platform-Technical-Overview-and-API#api)

The Matryx Alpha v1 Platform is deployed on our Private Ethereum Chain at address: `0x7c4970b887cfa95062ead0708267009dcd564017`
The Platform's ABI is: [here](https://github.com/matryx/matryx-alpha-source/blob/master/platformAbi.txt)

> Keep in mind that we do not have the develop branch deployed on the private chain.

#### Platform Contract API

  | Method    | Inputs | Output | 
|:----------|:-------------| ---: |
| **`tournamentByAddress()`** | uint256 tournamentId | bytes32 tournamentAddress|
| **`tournamentCount()`** | None | uint256 numberOfTournaments|
| **`createTournament()`** | string _tournamentName, bytes32 _externalAddress, uint256 _MTXReward, uint256 _entryFee | address tournamentAddress |
| **`enterTournament()`** | address _tournamentAddress | address _submissionViewer|

#### Tournament Contract API

| Method    | Inputs | Output | 
|:----------|:-------------| ---: |
| **`isOwner()`** | address _sender | bool |
| **`isEntrant()`** | address _sender | bool |
| **`tournamentOpen()`** | address _sender | bool |
| **`getExternalAddress()`** | None | bytes32 |
| **`mySubmissions()`** | None | address[] |
| **`submissionCount()`** | None | uint256 |
| **`getEntryFee()`** | None | uint256 |

## Interfaces
The are several interfaces that are being built that are designed to plug in to the Matryx Platform 
* [Calcflow](http://calcflow.io): A Virtual Reality tool for mathematical modeling (Oculus and HTC Vive)
* [Matryx WebApp](http://alpha.matryx.ai): A Web native application for interacting with the Matryx Platform and Marketplace
* [MatryxCore (Coming Soon)](http://matryx.ai): A OS native application for interacting with the Matryx Platform and Marketplace (Windows, Linux, Mac OSX)
* [Nano-one](http://store.steampowered.com/app/493430/nanoone/): A consumer Virtual Reality tool for chemical design and visualization
* [Nano-pro](http://nanome.ai): An enterprise ready Virtual Reality Platform for Chemical and Pharmaceutical drug development
* [Third party Interfaces](www.nanome.ai/TODO): Any third party integrated application utilizing the Matryx Platform- Contact us for details if you or your team is interested! 

Additonal information on the various interfaces supporting the Matryx Platform can be found on the [Matryx Interfaces Wiki](https://github.com/matryx/matryx-alpha-source/wiki/Matryx-Interfaces)


Below is a GIF of Matryx's Calcflow VR interface viewing Matryx tournaments on the private chain.
### Calcflow
![Calcflow](https://github.com/matryx/matryx-alpha-source/blob/master/assets/Calcflow_mtx.gif)


## Build, Deploy, and Test the Platform

### Launching the Platform
Specify the network configuration in the truffle.js file. Ours is originally pointed to localhost:8545 which is common for TestRPC/Ganache-CLI.

Make sure your have TestRPC or Ganache-CLI installed and run it a different tab.

```
truffle migrate
```

This will move the platform on to your network. You can then interact with the contract by attaching to it using truffle console.
```
truffle console
```

From there, when you type 'MatryxPlatform', it will recognize the contract and you can start to call functions with ease.

Check out the [Matryx Wiki on Technical Overview and API](https://github.com/matryx/matryx-alpha-source/wiki/Platform-Technical-Overview-and-API)

### Testing the Platform
The big ways we test the platform is through javascript tests using Mocha. You can see in the /tests/ folder some of our examples. We require extremely high code coverage for each contract to be know that we are covering all our bases. 

To run the tests:
```
./retest.sh
```

To run the code coverage:
```
./codeCoverage
```

If ./codecoverage.sh or retest.sh isnt able to be executed, make sure you change the permissions.
```
chmod +x codecoverage.sh
```

### Contributing
Our team at Matryx knows that the community is what will really drive the vision we all believe. So we strongly recommend that the community help us make improvements and we all make solid and sound decisions for the future direction of the platform. To report bugs with this package, please create an issue in this repository on the master branch.

Please read our contribution guidelines before getting started.

[Install npm](https://www.npmjs.com/get-npm?utm_source=house&utm_medium=homepage&utm_campaign=free%20orgs&utm_term=Install%20npm)


Install Truffle
```
npm install -g truffle
```

Install Ganache-cli
```
npm install -g ganache-cli
```

Make sure you pull the correct branch, which is called "develop"
```
git clone https://github.com/matryx/matryx-alpha-source -b develop
```

Install dependencies
```
npm install
```

For the develop branch, make sure you install the code coverage dependency.

Before running the tests, run the ganache-cli
```
ganache-cli -u 0,1,2,3,4,5
```

In a separate terminal, navigate to the project directory and run the following:
```
./retest.sh
truffle migrate
./codeCoverage.sh
```

Make sure that the code coverage is as close to 100% as possible (99%+ is required)

Please submit support related issues to the [issue tracker](https://github.com/matryx/matryx-alpha-source/issues)

We look forward to seeing the community feedback and issue identifications to make this platform the long term vision we all believe in!

Please take a look at our [Terms of Service](https://github.com/matryx/matryx-alpha-source/blob/master/TOS.txt) for using the platform that we have deployed

-The Matryx Team
