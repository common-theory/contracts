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
    mapping (address => bool) votes;
  }

  Proposal[] proposals;

  address[] members;

  address payable syndicateAddress;

  constructor(address payable _syndicateAddress, address[] memory _members) public {
    syndicateAddress = _syndicateAddress;
    require(_members.length >= 1);
    members = _members;
  }

  function proposalVote(uint256 index, bool vote) public {
    require(index >= 0);
    require(index < proposals.length);
    proposals[index].votes[msg.sender] = vote;
  }

  function canExecuteProposal(uint256 index) public view returns (bool) {
    require(index >= 0);
    require(index < proposals.length);
    Proposal storage proposal = proposals[index];
    for (uint256 i = 0; i < members.length; i++) {
      if (proposal.votes[members[i]]) continue;
      return false;
    }
    uint256 totalWei = 0;
    for (uint256 i = 0; i < proposal.paymentProposals.length; i++) {
      totalWei += proposal.paymentProposals[i].weiValue;
    }
    return totalWei <= address(this).balance;
  }

  function proposalExecute(uint256 index) public {
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
