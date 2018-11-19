# contracts [![Build Status](https://travis-ci.org/common-theory/contracts.svg?branch=master)](https://travis-ci.org/common-theory/contracts) [![Coverage](https://raw.githubusercontent.com/common-theory/common-dac/master/test/badge.svg?sanitize=true)](https://coverage.commontheory.io)

The common-theory contracts, with an overview of use.

_Alpha development in progress in [`#8`](https://github.com/common-theory/contracts/pull/8)_

## Syndicate

```
Syndicate

noun - a group of individuals or syndicates combined to promote some common interest
```

Syndicates can send and receive [ether](https://coinmarketcap.com/currencies/ethereum/) or [ERC-20 tokens](https://etherscan.io/tokens) two ways:
  - lump sum - sends a one time payment to a syndicate or individual (e.g. 1 ether to address `0x...`)
  - per second - sends a fixed amount over a period of time (e.g. 5000 [`dai`](https://makerdao.com/dai) over 30 days to address `0x...`)

Syndicates do not allow debt by default. All transactions are guaranteed to complete; funds are locked once committed.

Syndicates are a means by which to improve **fairness** and **efficiency** in financial interaction.

## Decision

Syndicates are operated by decision contracts. Decision contracts allow members to create and vote on proposals to execute functions in themselves other contracts (in this case a syndicate).

Decision contracts have members, the creator being the first member. Decisions can only be made unanimously and must have at least 75% voter participation. Members cannot vote against changes to their own membership; a member cannot be voted out against their will until at least 4 people are present (75% voter participation).

The current [`common-dapp`](https://github.com/common-theory/common-dapp) has _basic_ voting and membership (mirrors):

- [`https://commontheory.io`](https://commontheory.io)
- [`https://ipfs.io/ipns/commontheory.io`](https://ipfs.io/ipns/commontheory.io)
- [![latest hash](https://dnslink-cid-badge.commontheory.io/commontheory.io)](https://commontheory.io)

Decision contracts are a means by which to improve **transparency** and force humans to **communicate**.

## Intended Use

Syndicates can be deployed to form alliances between groups of humans. Syndicates should embody the opposite of the connotation and promote productivity and wellness (physically and mentally) in the beings involved.

[`Ethereum`](https://everipedia.org/wiki/lang_en/Ethereum/) can be used as the mechanism for consensus in governing policy. Open source web applications can be the controller.

Decisions should not be a full time job. It should be no different than checking email.

Humans should exist peacefully. In the case that they don't it is the fault of the governing system, or the absence of one.

## Interest

Humans want to be happy, and want to see other humans happy. Humans need to feel included and connected to other humans. Action doesn't always induce happiness, even when well intentioned. Campaigns exist to advertise the good that is being done.

Let the good that is done be the advertisement.
