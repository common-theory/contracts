pragma solidity ^0.4.23;

/**
 * A simple payment routing contract for people looking to work together. Any
 * funds sent to this contract are distributed to members based on their ratio
 * of value vs the total amount of value in the contract.
 *
 * Changes to members can be proposed and are voted on every 2 weeks.
 *
 * Votes are successful only if 100% of voters agree, and at least 75% of voters
 * participate.
 **/

contract CommonDAC {
  uint public totalVotingMembers = 0;
  uint public totalValue = 0;

  /**
   * A member is an entity that has a right to value/totalValue of all
   * funds sent to this contract.
   *
   * The extra fields are optional, and only used for user interfaces that may
   * consume the data.
   **/
  struct Member {
    uint value;
    string link;
  }

  /**
   * A proposal for members to vote on. Proposals can change contract state.
   **/
  struct Proposal {
    uint number;
    uint voteCycle;
    string description;
    address creator;

    bool updateMember;
    address memberAddress;
    uint oldValue;
    uint newValue;

    bool updateContract;
    address newContractAddress;

    uint totalAcceptingVotes;
    uint totalRejectingVotes;

    bool applied;
  }

  struct Vote {
    uint voteCycle;
    uint proposalNumber;
    bool accept;
  }

  event MemberVote(
    address memberAddress,
    uint proposalNumber,
    bool accept
  );

  event ProposalApplied(
    uint proposalNumber
  );

  mapping (address => Member) public members;
  address[] public memberAddresses;
  mapping (address => Vote[]) public votes;
  mapping (address => mapping (uint => bool)) public memberProposalVotes;

  mapping (address => uint) public balances;

  /**
   * Approximately 2 weeks between votes.
   *
   * This is not mutable in this contract, but can be included in proposals in
   * a subsequent version of this DAC.
   **/
  uint public votePeriod = 60 * 30;
  uint public genesisBlockTimestamp;

  Proposal[] public proposals;

  bool public contractUpdated = false;
  address public newContract;

  struct Payment {
    address sender;
    uint value;
    bool settled;
  }

  Payment[] public payments;

  constructor(address addr) public {
    genesisBlockTimestamp = block.timestamp;
    createProposal('The bootstrap proposal, creates the first address:value binding.', true, addr, 1000, 0x0, false);
    applyProposal(0);
  }

  /**
   * Does the msg.sender have voting rights generally. Further restrictions
   * should be performed (preventing duplicate proposal votes).
   **/
  modifier canVote() {
    if (members[msg.sender].value > 0) _;
  }

  /**
   * Default payment function. Adds an unsettled payment entry, or forwards the
   * payment to the updated contract (if an update proposal has passed).
   **/
  function() public payable {
    if (contractUpdated) {
      newContract.transfer(msg.value);
    } else {
      payments.push(Payment({
        sender: msg.sender,
        value: msg.value,
        settled: false
      }));
    }
  }

  /**
   * Settles all outstanding payments into user balances. Should be used prior
   * to modifying value information to ensure funds are always distributed
   * using the correct value ratio.
   **/
  function settleBalances() public canVote {
    for (uint i = 0; i < payments.length; i++) {
      if (payments[i].settled) continue;
      settlePayment(i);
    }
  }

  /**
   * Settles a specific payment into smart contract balances.
   *
   * Funds can be withdrawn using the withdraw function below.
   **/
  function settlePayment(uint index) public canVote {
    uint totalDistributedWei = 0;
    for (uint i = 0; i < memberAddresses.length; i++) {
      address a = memberAddresses[i];
      if (members[a].value == 0) continue;
      uint owedWei = payments[index].value * members[a].value / totalValue;
      totalDistributedWei += owedWei;
      balances[a] += owedWei;
    }
    assert(totalDistributedWei == payments[index].value);
    payments[index].settled = true;
  }

  /**
   * Withdraw the balance for the calling address.
   **/
  function withdraw() public {
    if (balances[msg.sender] == 0) return;
    msg.sender.transfer(balances[msg.sender]);
    balances[msg.sender] = 0;
  }

  /**
   * Each member may vote for a proposal once. Members may also abstain from
   * voting.
   *
   * Voting occurs during the vote cycle specified on the proposal (one cycle
   * after the proposal creation).
   *
   * If acceptance is achieved the proposed changes are excecuted immediately.
   **/
  function vote(uint proposalNumber, bool accept) public canVote {

    require(proposals[proposalNumber].voteCycle == currentVoteCycle());
    require(!memberProposalVotes[msg.sender][proposalNumber]);

    if (proposals[proposalNumber].updateMember &&
        proposals[proposalNumber].memberAddress == msg.sender) {
      // Members can vote in favor of a change to themselves, but not against
      // This solves the edge case of 2 members trying to consensually remove 1
      require(accept);
    }

    votes[msg.sender].push(Vote({
      voteCycle: currentVoteCycle(),
      proposalNumber: proposalNumber,
      accept: accept
    }));

    if (accept) {
      proposals[proposalNumber].totalAcceptingVotes += 1;
    } else {
      proposals[proposalNumber].totalRejectingVotes += 1;
    }

    memberProposalVotes[msg.sender][proposalNumber] = true;

    emit MemberVote(msg.sender, proposalNumber, accept);

    if (isProposalAccepted(proposalNumber)) {
      applyProposal(proposalNumber);
    }
  }

  /**
   * Helper to determine if proposal is accepted.
   *
   * Proposals must have 0 rejections, and at least 75% voting participation.
   **/
  function isProposalAccepted(uint proposalNumber) public view returns (bool) {
    if (proposals[proposalNumber].totalRejectingVotes > 0) {
      return false;
    }
    return proposals[proposalNumber].totalAcceptingVotes >= 75 * totalVotingMembers / 100;
  }

  /**
   * Proposals may be applied in the voting cycle following creation.
   **/
  function applyProposal(uint proposalNumber) public {
    require(isProposalAccepted(proposalNumber));
    if (proposals[proposalNumber].applied) return;

    // Update the member
    if (proposals[proposalNumber].updateMember) {
      uint currentValue = members[proposals[proposalNumber].memberAddress].value;
      uint oldValue = proposals[proposalNumber].oldValue;
      require(oldValue == currentValue);
      uint newValue = proposals[proposalNumber].newValue;
      if (oldValue != 0 && newValue == 0) {
        // A voting member is being removed
        totalVotingMembers -= 1;
      } else if (oldValue == 0 && newValue != 0) {
        // A voting member is being added
        totalVotingMembers += 1;
      }
      totalValue = totalValue - oldValue + newValue;
      members[proposals[proposalNumber].memberAddress].value = newValue;
      memberAddresses.push(proposals[proposalNumber].memberAddress);
    }

    // Update the contract address if necessary
    if (proposals[proposalNumber].updateContract) {
      contractUpdated = true;
      newContract = proposals[proposalNumber].newContractAddress;
    }
    proposals[proposalNumber].applied = true;
    emit ProposalApplied(proposalNumber);
  }

  /**
   * Proposals can be created by members with voting rights.
   *
   * Proposals will be included in the _next_ voting cycle.
   **/
  function createProposal(string _description, bool updateMember, address memberAddress, uint newValue, address newContractAddress, bool updateContract) public {
    proposals.push(Proposal({
      description: _description,
      number: proposals.length,
      voteCycle: currentVoteCycle() + 1,
      updateMember: updateMember,
      memberAddress: memberAddress,
      newValue: newValue,
      oldValue: members[memberAddress].value,
      newContractAddress: newContractAddress,
      updateContract: updateContract,
      totalAcceptingVotes: 0,
      totalRejectingVotes: 0,
      applied: false,
      creator: msg.sender
    }));
  }

  /**
   * Public getters for array lengths
   **/
  function proposalCount() public view returns (uint) {
    return proposals.length;
  }

  function paymentCount() public view returns (uint) {
    return payments.length;
  }

  function memberAddressCount() public view returns (uint) {
    return memberAddresses.length;
  }

  /**
   * Determine current vote cycle based on time offset and vote time period.
   **/
  function currentVoteCycle() public view returns (uint) {
    return (block.timestamp - genesisBlockTimestamp) / votePeriod;
  }
}
