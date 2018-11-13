pragma solidity ^0.4.23;

import './StringUtils.sol';

/**
 * A contract to facilitate decision making between humans.
 *
 * Changes to members can be proposed and are voted voteCycleLength seconds.
 *
 * Votes are successful only if 100% of voters agree, and at least 75% of voters
 * participate.
 **/

contract CommonDecision {
  uint public totalActiveMembers = 0;

  /**
   * A member is an entity that has a right to value/totalValue of all
   * funds sent to this contract.
   *
   * The extra fields are optional, and only used for user interfaces that may
   * consume the data.
   **/
  struct Member {
    address _address;
    bool active;
  }

  uint256 constant MAX_PROPOSAL_ARG_COUNT = 3;
  /**
   * A proposal for members to vote on. Proposals can change contract state.
   **/
  struct Proposal {
    /* Static values */
    uint number;
    uint voteCycle;
    uint creationTimestamp;
    address creator;

    /* Input values */
    string description;
    address targetContract;
    string functionSignature;
    bytes32[MAX_PROPOSAL_ARG_COUNT] arguments;

    /* State info */
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

  Member[] public members;
  mapping (address => uint256) memberIndex;
  mapping (address => Vote[]) public votes;
  mapping (address => mapping (uint256 => bool)) public memberProposalVotes;

  /**
   * 30 minute vote cycles
   * Changeable via proposal
   **/
  uint256 public minVoteCycleLength = 15;
  uint256 public voteCycleLength = 60 * 30;
  uint256 public lastVoteCycleLengthUpdate;
  uint256 public lastVoteCycleNumber;
  uint256 public genesisBlockTimestamp;

  Proposal[] public proposals;

  bool public contractUpdated = false;
  address public newContract;

  constructor(address addr, uint _voteCycleLength) public {
    genesisBlockTimestamp = block.timestamp;
    lastVoteCycleLengthUpdate = block.timestamp;
    lastVoteCycleNumber = 0;
    /**
     * Proposals can be applied immediately when there are 0 members.
     **/
    bytes32[MAX_PROPOSAL_ARG_COUNT] memory arguments;
    arguments[0] = bytes32(addr);
    arguments[1] = bytes32(1);
    createProposal('The bootstrap proposal, creates the first address value binding.', address(this), 'updateMember(bytes32, bytes32, bytes32)', arguments);
    if (_voteCycleLength != 0) {
      bytes32[MAX_PROPOSAL_ARG_COUNT] memory voteArguments;
      voteArguments[0] = bytes32(_voteCycleLength);
      createProposal('Adjust vote cycle time.', address(this), 'putVoteCycleLength(bytes32, bytes32, bytes32)', voteArguments);
      applyProposal(1);
    }
    applyProposal(0);
  }

  function () public {
    require(false, 'Method is invalid');
  }

  /**
   * Does the msg.sender have voting rights generally. Further restrictions
   * should be performed (preventing duplicate proposal votes).
   **/
  modifier canVote() {
    if (members[memberIndex[msg.sender]].active) _;
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

    Proposal memory proposal = proposals[proposalNumber];

    require(proposal.voteCycle == currentVoteCycle());
    require(!memberProposalVotes[msg.sender][proposalNumber]);

    // Check if it's a vote to change a member of _this_ contract
    // And if the current member voting is the one being updated
    if (proposal.targetContract == address(this) &&
        proposal.arguments[0] == bytes32(msg.sender) &&
        StringUtils.stringContains(proposal.functionSignature, 'updateMember')) {
      // Members can vote in favor of a change to themselves, but not against
      // This solves the edge case of 2 or 3 members trying to consensually remove 1
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
   *
   * When less than 4 people are present in a contract all must participate in
   * votes.
   **/
  function isProposalAccepted(uint proposalNumber) public view returns (bool) {
    if (proposals[proposalNumber].totalRejectingVotes > 0) {
      return false;
    }
    /**
     * When bootstrapping the totalRejectingVotes and totalAcceptingVotes will
     * both be 0.
     *
     * The expression below evaluates as equal when totalAcceptingVotes and
     * totalActiveMembers are both 0: 100 * 0 >= 75 * 0
     **/
    return 100 * proposals[proposalNumber].totalAcceptingVotes >= 75 * totalActiveMembers;
  }

  /**
   * Proposals may be applied in the voting cycle following creation.
   *
   * Proposed executions must supply 3 bytes32 arguments
   **/
  function applyProposal(uint proposalNumber) public {
    require(isProposalAccepted(proposalNumber));
    if (proposals[proposalNumber].applied) return;

    Proposal memory proposal = proposals[proposalNumber];
    bytes4 signature = bytes4(keccak256(abi.encodePacked(proposal.functionSignature)));
    bytes32 arg0 = proposal.arguments[0];
    bytes32 arg1 = proposal.arguments[1];
    bytes32 arg2 = proposal.arguments[2];
    address targetContract = proposal.targetContract;
    assembly {
      // Setup the call at 0x40, initialize x to the start of the memory region
      let x := mload(0x40)

      // Store the 4 byte function signature at x
      mstore(x, signature)
      // Store arg0 4 bytes past x
      mstore(add(x, 0x04), arg0)
      // Store arg1 36 bytes past x
      mstore(add(x, 0x24), arg1)
      // Store arg2 68 bytes past x
      mstore(add(x, 0x44), arg2)

      // Full call data now resides at 0x40 - 0xA4, x is a pointer to the
      // beginning of this region

      // Execute the function, collect success as 0 or 1
      let success := call(
        5000, // the gas to send
        targetContract, // target contract being executed
        0, // Not sending any value
        x, // argument beginning offset
        0x64, // input is 100 bytes long (4 + 32 + 32 + 32)
        x, // output of the call will overwrite the call data
        0x20 // pull 32 bytes of output data
      )
      // Revert if execution fails
      // This should probably be changed to updating the proposal as failing to
      // apply
      mstore(0x40, success)
      if eq(success, 0) { revert(0, 0) }
      mstore(0x40, add(x, 0x64)) // clear the memory region
    }
    proposals[proposalNumber].applied = true;
    emit ProposalApplied(proposalNumber);
  }

  /**
   * Proposals can be created by members with voting rights.
   *
   * Proposals will be included in the _next_ voting cycle.
   **/
  function createProposal(string _description, address _targetContract, string _functionSignature, bytes32[MAX_PROPOSAL_ARG_COUNT] _arguments) public {
    proposals.push(Proposal({
      description: _description,
      targetContract: _targetContract,
      functionSignature: _functionSignature,
      arguments: _arguments,
      number: proposals.length,
      voteCycle: currentVoteCycle() + 1,
      totalAcceptingVotes: 0,
      totalRejectingVotes: 0,
      applied: false,
      creator: msg.sender,
      creationTimestamp: block.timestamp
    }));
  }

  modifier commonDecision() {
    require(msg.sender == address(this));
    _;
  }

  /**
   * Called when a proposal is applied
   **/
  function updateMember(bytes32 a0, bytes32 a1, bytes32) public {
    Member memory member = Member({
      _address: address(a1),
      active: (a0 != 0)
    });
    if (members[memberIndex[member._address]]._address != member._address) {
      // new member
      members.push(member);
      if (member.active) totalActiveMembers++;
      return;
    }
    Member memory current = members[memberIndex[member._address]];
    if (current.active != member.active && member.active) {
      totalActiveMembers++;
    } else if (current.active != member.active) {
      totalActiveMembers--;
    }
    members[memberIndex[member._address]] = member;
  }

  /* putVoteCycleLength(bytes32 a0, bytes32 a1, bytes32, a2) public {

  } */

  /**
   * Public getters for array lengths
   **/
  function proposalCount() public view returns (uint) {
    return proposals.length;
  }

  /**
   * Determine current vote cycle based on time offset and vote time period.
   **/
  function currentVoteCycle() public view returns (uint) {
    return lastVoteCycleNumber + (block.timestamp - lastVoteCycleLengthUpdate) / voteCycleLength;
  }

  /**
   * Getter for members array length
   **/
  function memberCount() public view returns (uint) {
    return members.length;
  }
}
