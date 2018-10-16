pragma solidity ^0.4.23;

/**
 * A simple payment routing contract for people looking to work together. Any
 * funds sent to this contract are distributed to members based on their ratio
 * of ownership vs the total amount of ownership in existence.
 *
 * Changes to members can be proposed and are voted on every 2 weeks.
 *
 * Votes are successful only if 100% of voters agree, and at least 75% of voters
 * participate.
 **/

contract CommonDAC {
  uint totalVotingMembers = 0;
  uint totalOwnership = 0;
  /**
   * A member is an entity that has a right to ownership/totalOwnership of all
   * funds sent to this contract.
   *
   * The extra fields are optional, and only used for user interfaces that may
   * consume the data.
   **/
  struct Member {
    uint ownership;
    string name;
    string github;
    string website;
  }

  struct Proposal {
    uint number; // The proposal number
    uint voteCycle;
    bool updateMember;
    address memberAddress;
    uint newOwnership;
    address newContractAddress;
    bool updateContract;
  }

  struct ProposalVoteState {
    uint totalAccepting;
    uint totalRejecting;
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

  event ProposalAccepted(
    uint proposalNumber
  );

  mapping (address => Member) public members;
  mapping (address => Vote[]) public votes;
  mapping (address => mapping (uint => bool)) public memberProposalVotes;

  /**
   * Approximately 2 weeks between votes.
   *
   * This is not mutable in this contract, but can be included in proposals in
   * a subsequent version of this DAC.
   **/
  uint votePeriod = 60;
  uint genesisBlockTimestamp;

  Proposal[] public proposals;
  ProposalVoteState[] public proposalVotes;

  bool contractUpdated = false;
  address newContract;

  constructor(string name, string github, string website) public {
    members[msg.sender] = Member({
      ownership: 1000,
      name: name,
      github: github,
      website: website
    });
    totalVotingMembers += 1;
    genesisBlockTimestamp = block.timestamp;
  }

  /**
   * Does the msg.sender have voting rights generally. Further restrictions
   * should be performed (preventing duplicate proposal votes).
   **/
  modifier canVote() {
    if (members[msg.sender].ownership > 0) _;
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

    votes[msg.sender].push(Vote({
      voteCycle: currentVoteCycle(),
      proposalNumber: proposalNumber,
      accept: accept
    }));

    if (accept) {
      proposalVotes[proposalNumber].totalAccepting += 1;
    } else {
      proposalVotes[proposalNumber].totalRejecting += 1;
    }

    memberProposalVotes[msg.sender][proposalNumber] = true;

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
    if (proposalVotes[proposalNumber].totalRejecting > 0) {
      return false;
    }
    return proposalVotes[proposalNumber].totalAccepting > 75 * totalVotingMembers / 100;
  }

  /**
   * Proposals may be applied in the voting cycle following creation.
   **/
  function applyProposal(uint proposalNumber) public {
    require(isProposalAccepted(proposalNumber));
    if (proposalVotes[proposalNumber].applied) return;
    
    if (proposals[proposalNumber].updateMember) {
      members[proposals[proposalNumber].memberAddress].ownership = proposals[proposalNumber].newOwnership;
    }
    if (proposals[proposalNumber].updateContract) {
      contractUpdated = true;
      newContract = proposals[proposalNumber].newContractAddress;
    }
    proposalVotes[proposalNumber].applied = true;
  }

  /**
   * Proposals can be created by members with voting rights.
   *
   * Proposals will be included in the _next_ voting cycle.
   **/
  function createProposal(bool updateMember, address memberAddress, uint newOwnership, address newContractAddress, bool updateContract) public canVote {
    proposals.push(Proposal({
      number: proposals.length,
      voteCycle: currentVoteCycle() + 1,
      updateMember: updateMember,
      memberAddress: memberAddress,
      newOwnership: newOwnership,
      newContractAddress: newContractAddress,
      updateContract: updateContract
    }));
    proposalVotes.push(ProposalVoteState({
      totalAccepting: 0,
      totalRejecting: 0,
      applied: false
    }));
  }

  /**
   * Determine current vote cycle based on time offset and vote time period.
   **/
  function currentVoteCycle() public view returns (uint) {
    return (block.timestamp - genesisBlockTimestamp) / votePeriod;
  }
}
