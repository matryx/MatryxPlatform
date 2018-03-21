# Matryx Alpha Source Code v1 ![logo](https://github.com/matryx/matryx-alpha-source/blob/master/assets/Matryx-Logo-Black-1600px.png)
[![Jenkins](https://img.shields.io/jenkins/s/https/jenkins.qa.ubuntu.com/view/Precise/view/All%20Precise/job/precise-desktop-amd64_default.svg)](http://jenkins.matryx.ai/matryx-alpha-source/build-status)
[![Jenkins coverage](https://img.shields.io/badge/coverage-Coming%20Soon-brightgreen.svg)](http://jenkins.matryx.ai/matryx-alpha-source/code-coverage)
[![Jenkins tests](https://img.shields.io/badge/tests-Coming%20Soon-brightgreen.svg)](http://jenkins.matryx.ai/matryx-alpha-source/tests)
[![Telegram](https://img.shields.io/badge/chat-Telegram-blue.svg)](https://t.me/matryxai)
[![Latest News](https://img.shields.io/badge/Blog-Medium-yellowgreen.svg)](https://blog.matryx.ai/)


## Introduction

> [Matryx.ai](https://www.matryx.ai): 
The Collaborative Research and Development Engine Optimized for Virtual Reality Interfaces

A full description about our platform is in our [whitepaper](https://matryx.ai/matryx-whitepaper.pdf).

## How to use the platform
In our first iteration we focused on end-to-end development for the platform across many layers. From our Matryx ethereum private chain to our backend MatryxOracle system to our VR Interfaces. 
In the next release, we will be working towards our long term architecture to be put in place and thoroughly tested across the full integration. 

Our lead Matryx Architect, Max, made a great medium article posting on how to use the first alpha release of the Matryx Platform that focuses on integration with our Virtual Reality Mathematics tool, [Calcflow](http://calcflow.io/).

A link to the article directly can be found [here](https://blog.matryx.ai/matryx-alpha-a-how-to-guide-b6b5b9ffcca4)

The Matryx platform is currently deployed on an Ethereum Private chain. In order to interact with the bounties and the alpha platform, you will need to run a node locally, as well as **_have Matryx Tokens (MTX) in your ERC20 Compatible Wallet_** such as [My Ether Wallet](https://www.myetherwallet.com/).
 
 Instructions on getting the private chain synced locally can be found here:
 * [Windows](https://github.com/matryx/matryx-alpha-source/wiki/Running-the-Matryx-Ethereum-Private-Chain-%5BWindows%5D) 
 * [OSX](https://github.com/matryx/matryx-alpha-source/wiki/Running-the-Matryx-Ethereum-Private-Chain-%5BOSX%5D)
 
### API

Visit the wiki for the [API Documentation](https://github.com/matryx/matryx-alpha-source/wiki/Platform-Technical-Overview-and-API#api)

The Platform is deployed on our Private Ethereum Chain at address: `0x7c4970b887cfa95062ead0708267009dcd564017`
The Platform's ABI is: [here](https://github.com/matryx/matryx-alpha-source/blob/master/platformAbi.txt)

| Method    | Inputs | Output | 
|:----------|:-------------| ---: |
| **`getBalance()`** | uint256 tournamentId, string title, string body, string references, string contributors | uint256 |
| **`createSubmission()`** | uint256 tournamentId, string title, string body, string references, string contributors | None |
| **`tournamentByIndex()`** | uint256 idx | uint256, string, string, uint256 |
| **`tournamentByAddress()`** | uint256 tournamentId | uint256, string, string, uint256 |
| **`tournamentCount()`** | None | uint256 |
| **`submissionByIndex()`** | uint256 tournamentId | uint256, string, string, string, string, address |
| **`submissionByAddress()`** | uint256 tournamentId | uint256, string, string, string, string, address |
| **`submissionCount()`** | None | uint256 |


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
An extremely important part of the platform is testing to make sure it is not compromised. Luckily for this iteration, we are focused solely on end-to-end integration, but in the following releases we have already started implementing unit and functional testing paired with code coverage reports.

Check out our develop branch to see the latest pushes to the platform, but beware, it is an unstable build as we are actively building on it everyday.

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


If you like Matryx, please consider donating ETH to 0xe665Dd2C090c7ceFD5C40cb9de00830108A62785

