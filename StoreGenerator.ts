
export type ContractABI {
  {
    constant: boolean,
    inputs: {
      name: string,
      type: 'uint256' | 'uint8'
    }[]
  }
}

const abi = require('./build/contracts/CommandDAC.json');
