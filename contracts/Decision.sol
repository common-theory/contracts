pragma solidity ^0.5.0;

import './StringUtils.sol';
import './Syndicate.sol';

/**
 * A contract to facilitate decision making between humans.
 *
 * Votes are successful only if 100% of voters agree, and at least 75% of voters
 * participate.
 **/

contract Decision {
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

  struct ProposedPayment {
    address receiver;
    uint256 weiValue;
    uint256 time;
  }

  /**
   * A proposal for members to vote on. Proposals can change contract state.
   **/
  struct Proposal {
    uint256 timestamp;
    address creator;

    /* Input values */
    string description;
    ProposedPayment[] proposedPayments;

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
  address payable syndicate;

  constructor(address payable _syndicate) public {
    syndicate = _syndicate;
  }

  function () external payable {
    Syndicate s = Syndicate(syndicate);
    s.deposit.value(msg.value)(address(this), 0);
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
  }

  /**
   * Proposals can be created by members with voting rights.
   *
   * Proposals will be included in the _next_ voting cycle.
   **/
  function createProposal(string memory _description, address _targetContract, string memory _functionSignature, bytes32[3] memory _arguments) public {
  }

  modifier commonDecision() {
    require(msg.sender == address(this));
    _;
  }

  /**
   * Called when a proposal is applied
   **/
  function updateMember(bytes32 a0, bytes32 a1, bytes32) public {
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
  }

  /**
   * Getter for members array length
   **/
  function memberCount() public view returns (uint) {
    return members.length;
  }
}
