pragma solidity ^0.5.0;

interface Syndicate {
  function paymentCreate(address payable _receiver, uint256 _time) external payable;
  function paymentSettle(uint256 index) external;
  function paymentWeiOwed(uint256 index) external view returns (uint256);
  function paymentFork(uint256 index, address payable _receiver, uint256 _weiValue) external;
  function isPaymentForked(uint256 index) external view returns (bool);
  function paymentForkCount(uint256 index) external view returns (uint256);
  function isPaymentSettled(uint256 index) external view returns (bool);
  function requirePaymentIndexInRange(uint256 index) external view;
  function paymentCount() external view returns (uint256);
}

/// @title A way to allow multiple addresses to control funds
/// @author Chance Hudson
/// @notice This contract can be used to allow multiple addresses to control
/// funds locked in a contract. Helpful for allowing a cold storage key to
/// have control of funds.
contract Delegate {
  address payable public syndicateAddress;

  mapping (address => bool) public delegates;

  constructor(address payable _syndicateAddress) public {
    syndicateAddress = _syndicateAddress;
    delegates[msg.sender] = true;
  }

  function () external payable { }

  modifier delegateOnly() {
    require(delegates[msg.sender] == true);
    _;
  }

  function delegate(address _delegate, bool _delegated) public delegateOnly {
    delegates[_delegate] = _delegated;
  }

  function paymentCreate(uint256 weiValue, address payable receiver, uint256 time) public delegateOnly {
    require(weiValue <= address(this).balance);
    Syndicate syndicate = Syndicate(syndicateAddress);
    syndicate.paymentCreate.value(weiValue)(receiver, time);
  }

  function paymentFork(uint256 index, address payable receiver, uint256 weiValue) public delegateOnly {
    Syndicate syndicate = Syndicate(syndicateAddress);
    syndicate.paymentFork(index, receiver, weiValue);
  }

  function withdraw(uint256 weiValue) public delegateOnly {
    require(weiValue <= address(this).balance);
    msg.sender.transfer(weiValue);
  }
}
