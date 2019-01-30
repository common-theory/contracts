# contracts [![Build Status](https://travis-ci.org/common-theory/contracts.svg?branch=master)](https://travis-ci.org/common-theory/contracts) [![Coverage](https://raw.githubusercontent.com/common-theory/common-dac/master/test/badge.svg?sanitize=true)](https://gateway.commontheory.io/ipns/coverage.commontheory.io/contracts/index.html)

The common theory contracts, with an overview of use. An open-source user interface for interacting with the latest deployed contracts can be found [here](https://github.com/common-theory/common-dapp).

## Syndicate

A Syndicate is a contract that allows creation of payments over time.

```
Syndicate

noun - a group of individuals combined to promote some common interest
```

Syndicates are a means by which to improve **fairness** and **efficiency** in financial interaction.

### Payments

A Syndicate can be used to send a payment over time to an Ethereum address. Balances are held in the contract and funds are frozen during transfer. Funds are distributed linearly in time: if 100 wei is sent over 10 seconds then 10 wei becomes available every second.

### Forks

Once a payment has been initiated the recipient is able to fork some (or all) of the remaining payment to other addresses. A payment is delegation of responsibility for funds over time.

When a payment is forked the original payment `weiValue` is subtracted by the amount being forked. A new payment is created with the desired amount of `weiValue` and a completion time equal to that of the original payment. The forked payment may itself be forked.

Each payment can be represented as a tree with nodes being individual payments. All payments in a given tree will complete at the same time.

## Delegate

A Delegate contract can interact with Syndicate payments on behalf of a user. Multiple addresses can be authorized in a delegate contract.

This can be used for receiving and sending payments to avoid individual addresses being entrusted with large stores of value. It also allows for cold generated addresses to receive and control value.

#### Proof

Unit tests cover all functions and logical paths, see the latest build log [here](https://travis-ci.org/common-theory/contracts). Mathematical proofs of functions can be found [here](https://github.com/common-theory/contracts/blob/master/proofs).

## Common Interest

A Syndicate can be used to coordinate funds between humans. Syndicate users should embody the opposite of the connotation and promote productivity and wellness (physically and mentally) in the beings involved.

Humans want to be happy, and want to see other humans happy. Humans need to feel included and connected to other humans. Action doesn't always induce happiness, even when well intentioned. Campaigns exist to advertise the good that is being done.

Let the good that is done be the advertisement.
