const Decision = artifacts.require('Decision');
const assert = require('assert');
const BN = require('bn.js');

contract('Decision', accounts => {

  it('should create and execute proposal', async () => {
    const _contract = await Decision.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    const weiValue = 100;
    const toAddress = web3.eth.accounts.create().address;
    await contract.methods.proposePayment(toAddress, weiValue, 0).send({
      from: accounts[0],
      gas: 300000
    });
    const proposalCount = await contract.methods.proposalCount().call();
    const proposalIndex = proposalCount - 1;
    await contract.methods.proposalVote(proposalIndex, true).send({
      from: accounts[0],
      gas: 300000
    });
    await web3.eth.sendTransaction({
      from: accounts[3],
      to: _contract.address,
      value: weiValue,
      gas: 300000
    });
    await contract.methods.proposalExecute(proposalIndex).send({
      from: accounts[0],
      gas: 300000
    });
    const toAddressWei = await web3.eth.getBalance(toAddress);
    assert.equal(+toAddressWei, +weiValue);
  });

  it('isProposalPassed should fail for out of range index', async () => {
    const _contract = await Decision.deployed();
    const contract = new web3.eth.Contract(_contract.abi, _contract.address);
    await assert.rejects(contract.methods.isProposalPassed(-1).send({
      from: accounts[0],
      gas: 300000
    }), 'Negative proposal value should cause error');

    const proposalCount = await contract.methods.proposalCount().call();
    await assert.rejects(contract.methods.isProposalPassed(proposalCount).call(), 'Proposal outside of range should cause error');
  });

});
