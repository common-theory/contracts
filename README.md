# contracts [![Build Status](https://travis-ci.org/common-theory/contracts.svg?branch=master)](https://travis-ci.org/common-theory/contracts) [![Coverage](https://raw.githubusercontent.com/common-theory/common-dac/master/test/badge.svg?sanitize=true)](https://gateway.commontheory.io/ipns/coverage.commontheory.io/)

The common theory contracts, with an overview of use. An open-source user interface for interacting with the latest deployed contracts can be found [here](https://github.com/common-theory/common-dapp).

## Syndicate

A Syndicate is a contract that allows creation of payments over time.

```
Syndicate

noun - a group of individuals combined to promote some common interest
```

Syndicates are a means by which to improve **fairness** and **efficiency** in financial interaction.

### Payments

A Syndicate can be used to send payments over time between Ethereum addresses. Balances are held in the contract and funds are frozen during transfer. Payments are guaranteed to complete once initiated.

### Forks

Once a payment has been initiated the recipient is able to fork some (or all) of the remaining payment to other addresses. A payment is ownership of a certain rate of wei/second and can be distributed between many addresses. A payment is delegation of responsibility for funds over time.

#### Proof

Unit tests cover all functions and logical paths, see the latest build log [here](https://travis-ci.org/common-theory/contracts). Mathematical proofs of functions can be found [here](https://github.com/common-theory/contracts/blob/master/proofs).

## Common Interest

A Syndicate can be used to coordinate funds between humans. Syndicate users should embody the opposite of the connotation and promote productivity and wellness (physically and mentally) in the beings involved.

Humans want to be happy, and want to see other humans happy. Humans need to feel included and connected to other humans. Action doesn't always induce happiness, even when well intentioned. Campaigns exist to advertise the good that is being done.

Let the good that is done be the advertisement.
