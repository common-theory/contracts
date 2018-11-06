const CommonDAC = artifacts.require('CommonDAC');
const assert = require('assert');

contract('CommonDAC', accounts => {

  it('should initialize with a proposal', async () => {
    const contract = await CommonDAC.deployed();
    const proposalCount = await contract.proposalCount.call();
    assert.notEqual(proposalCount, 0, 'Initial proposal not present.');
  });

  it('should pass a proposal', async () => {
    const contract = await CommonDAC.deployed();
    const oldProposalCount = +(await contract.proposalCount());
    const proposalName = 'test proposal';
    await contract.createProposal(proposalName, 0, accounts[1], 50, 0, 0);
    const newProposalCount = oldProposalCount + 1;
    const proposalIndex = newProposalCount - 1;
    assert.equal(newProposalCount, await contract.proposalCount());
    // proposal is an array of values as defined in the contract
    // abi doesn't automatically map values to keys?
    const proposal = await contract.proposals(proposalIndex);
    assert.equal(proposal[3], proposalName);
    const checkForActiveVote = async () => {
      await new Promise(rs => setTimeout(rs, 1000));
      return +(await contract.currentVoteCycle()) === +proposal[2];
    };
    assert.rejects(contract.vote(proposalIndex, false));
    // Wait for active vote
    while (!checkForActiveVote) {}
    assert.rejects(contract.applyProposal(proposalIndex));
    assert.doesNotReject(contract.vote(proposalIndex, true));
    await new Promise(rs => setTimeout(rs, 15000));
    assert.equal(await contract.isProposalAccepted(proposalIndex), true);
  });

});
