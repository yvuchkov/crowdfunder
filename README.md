# Crowdfunding Smart Contract

A decentralized crowdfunding platform built with Solidity and Foundry. This smart contract allows users to create campaigns, contribute ETH, and manage funds securely on the Ethereum blockchain.

## Features

- Create crowdfunding campaigns with customizable goals and deadlines
- Contribute ETH to active campaigns
- Automatic refund mechanism for failed campaigns
- Secure withdrawal for successful campaigns
- ReentrancyGuard protection for all ETH transfers

## Technology Stack

- **Solidity** ^0.8.20
- **Foundry** - Development framework
- **OpenZeppelin** - Security libraries

## Project Structure

```
/src
  - Crowdfunding.sol       # Main contract
/test
  - Crowdfunding.t.sol     # Test suite
/script
  - Deploy.s.sol           # Deployment script
```

## Getting Started

### Build

```shell
forge build
```

### Test

```shell
forge test
```

### Deploy

```shell
forge script script/Deploy.s.sol:DeployScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

## License

MIT
