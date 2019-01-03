pragma solidity ^0.5.0;

import './Syndicate.sol';

/**
 * A contract for multisignature Syndicate payment creation.
 **/

contract Decision {

  struct Proposal {
    address payable receiver;
    uint256 _time;
    uint256 weiValue;
    mapping (address => bool) votes;
    bool isExecuted;
    bool isMigration;
  }

  Proposal[] proposals;

  address[] members;

  address payable syndicateAddress;

  constructor(address payable _syndicateAddress, address[] memory _members) public {
    syndicateAddress = _syndicateAddress;
    require(_members.length >= 1);
    members = _members;
  }

  function () external payable {}

  function proposePayment(address payable _receiver, uint256 _weiValue, uint256 _time) public {
    proposals.push(Proposal({
      receiver: _receiver,
      weiValue: _weiValue,
      _time: _time,
      isMigration: false,
      isExecuted: false
    }));
  }

  function proposeMigration(address payable _receiver) public {
    proposals.push(Proposal({
      receiver: _receiver,
      weiValue: 0,
      _time: 0,
      isMigration: true,
      isExecuted: false
    }));
  }

  function proposalVote(uint256 index, bool vote) public {
    require(index >= 0);
    require(index < proposals.length);
    proposals[index].votes[msg.sender] = vote;
  }

  function isProposalPassed(uint256 index) public view returns (bool) {
    require(index >= 0);
    require(index < proposals.length);
    Proposal storage proposal = proposals[index];
    for (uint256 i = 0; i < members.length; i++) {
      if (proposal.votes[members[i]] == true) continue;
      return false;
    }
    return proposal.weiValue <= address(this).balance;
  }

  function proposalExecute(uint256 index) public {
    require(isProposalPassed(index));
    Proposal memory proposal = proposals[index];
    require(!proposal.isExecuted);
    if (proposal.isMigration == true) {
      selfdestruct(proposal.receiver);
      return;
    }
    Syndicate syndicate = Syndicate(syndicateAddress);
    syndicate.deposit.value(proposal.weiValue)(proposal.receiver, proposal._time);
    proposals[index].isExecuted = true;
    if (proposal._time != 0) return;
    syndicate.withdraw(proposal.weiValue, proposal.receiver);
  }

  function proposalCount() public view returns (uint256) {
    return proposals.length;
  }

}
