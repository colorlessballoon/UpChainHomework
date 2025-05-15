export const TOKEN_BANK_ADDRESS = '0x536D3f25380419047506DBbc7aa0Ad301E383b1A';

export const TOKEN_BANK_ABI = [
  {
    type: "constructor",
    inputs: [{ name: "tokenAddress", type: "address", internalType: "address" }],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "balances",
    inputs: [{ name: "", type: "address", internalType: "address" }],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "deposit",
    inputs: [{ name: "amount", type: "uint256", internalType: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "token",
    inputs: [],
    outputs: [{ name: "", type: "address", internalType: "contract IERC20" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "totalDeposits",
    inputs: [],
    outputs: [{ name: "", type: "uint256", internalType: "uint256" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "withdraw",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable"
  }
]; 