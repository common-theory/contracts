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

  modifier authorized() {
    require(delegates[msg.sender] == true);
    _;
  }

  /// @notice Set whether an address can control the contract.
  /// @param _delegate The address to be updated
  /// @param _delegated Whether the address should have execution privileges
  function delegate(address _delegate, bool _delegated) public authorized {
    delegates[_delegate] = _delegated;
  }

  /// @notice Creates a payment from the contract to an address.
  /// @param weiValue The amount of wei to send
  /// @param receiver The address to receive the payment
  /// @param time The number of seconds the payment should be made over
  function paymentCreate(uint256 weiValue, address payable receiver, uint256 time) public authorized {
    require(weiValue <= address(this).balance);
    Syndicate syndicate = Syndicate(syndicateAddress);
    syndicate.paymentCreate.value(weiValue)(receiver, time);
  }

  /// @notice Forks a payment being received by the contract.
  /// @param index The payment index to be forked
  /// @param receiver The address that should be forked to
  /// @param weiValue The amount of wei to be forked
  function paymentFork(uint256 index, address payable receiver, uint256 weiValue) public authorized {
    Syndicate syndicate = Syndicate(syndicateAddress);
    syndicate.paymentFork(index, receiver, weiValue);
  }

  /// @notice Withdraw funds from the contract to the caller.
  /// @param weiValue The amount of wei to be withdrawn
  function withdraw(uint256 weiValue) public authorized {
    require(weiValue <= address(this).balance);
    msg.sender.transfer(weiValue);
  }
}
