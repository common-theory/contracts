pragma solidity ^0.5.0;

import './Syndicate.sol';

/**
 * A contract for multisignature Syndicate payment creation.
 *
 * Votes are successful only if 100% of voters agree, and at least 75% of voters
 * participate.
 **/

contract Decision {

  struct ProposedPayment {
    address payable receiver;
    uint256 _time;
    uint256 weiValue;
  }

  struct Proposal {
    ProposedPayment[] paymentProposals;
    uint256 votingMembers;
    uint256 votes;
  }

  Proposal[] proposals;

  address payable syndicateAddress;

  constructor(address payable _syndicateAddress) public {
    syndicateAddress = _syndicateAddress;
  }

  function canExecuteProposal(uint256 index) public view returns (bool) {
    require(index >= 0);
    require(index < proposals.length);
    Proposal memory proposal = proposals[index];
    uint256 totalWei = 0;
    for (uint256 i = 0; i < proposal.paymentProposals.length; i++) {
      totalWei += proposal.paymentProposals[i].weiValue;
    }
    return totalWei <= address(this).balance;
  }

  function executeProposal(uint256 index) public {
    require(canExecuteProposal(index));
    Proposal memory proposal = proposals[index];
    Syndicate syndicate = Syndicate(syndicateAddress);
    for (uint256 i = 0; i < proposal.paymentProposals.length; i++) {
      ProposedPayment memory payment = proposal.paymentProposals[i];
      syndicate.deposit.value(payment.weiValue)(payment.receiver, payment._time);
    }
  }

  function proposalCount() public view returns (uint256) {
    return proposals.length;
  }
}
