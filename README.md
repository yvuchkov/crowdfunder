# Crowdfunding Smart Contract Platform

A decentralized crowdfunding platform built with Solidity and Foundry. Features campaign creation, contributions, refunds, cancellation, and a 2% platform fee mechanism.

## Features

- **Campaign Creation**: Create campaigns with funding goals and deadlines
- **Contributions**: Contributors can fund campaigns before the deadline
- **Withdrawals**: Campaign creators can withdraw funds after reaching their goal
- **Refunds**: Contributors can claim refunds if campaigns fail or are cancelled
- **Cancellation**: Creators can cancel campaigns before the deadline
- **Platform Fee**: 2% fee (200 basis points) automatically deducted on successful withdrawals
- **Security**: ReentrancyGuard, custom errors, and Checks-Effects-Interactions pattern

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/downloads)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/crowdfunder
cd crowdfunder

# Install dependencies
make install

# Build the project
make build
```

### Environment Setup

1. Copy the environment example file:
```bash
cp .env.example .env
```

2. Edit `.env` and add your configuration:
   - `PRIVATE_KEY`: Your wallet private key (NEVER commit this!)
   - `SEPOLIA_RPC_URL`: Your Sepolia RPC URL (e.g., from Alchemy)
   - `ETHERSCAN_API_KEY`: Your Etherscan API key for verification

## Testing

Run all tests:
```bash
make test
```

Run tests with gas reporting:
```bash
forge test --gas-report
```

Run tests with verbosity:
```bash
forge test -vvvv
```

## Deployment

### Local Deployment (Anvil)

1. Start a local Anvil node:
```bash
make anvil
```

2. In a new terminal, deploy the contract:
```bash
make deploy
```

### Testnet Deployment

Deploy to Sepolia:
```bash
make deploy ARGS="--network sepolia"
```

Deploy to Base Sepolia:
```bash
make deploy ARGS="--network base-sepolia"
```

Deploy to Arbitrum Sepolia:
```bash
make deploy ARGS="--network arbitrum-sepolia"
```

### Mainnet Deployment

**⚠️ WARNING: Update `DEFAULT_MAINNET_FEE_RECIPIENT` in `HelperConfig.s.sol` before deploying to mainnet!**

Deploy to Ethereum Mainnet:
```bash
make deploy ARGS="--network mainnet"
```

## Interactions

After deployment, you can interact with the contract using the provided scripts:

### Create a Campaign
```bash
make create-campaign ARGS="--network sepolia"
```

### Contribute to a Campaign
```bash
make contribute ARGS="--network sepolia"
```

### Withdraw Funds
```bash
make withdraw ARGS="--network sepolia"
```

### Get Campaign Details
```bash
make get-details ARGS="--network sepolia"
```

## Manual Deployment & Verification

### Deploy
```bash
forge script script/DeployCrowdfunding.s.sol:DeployCrowdfunding --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Verify
```bash
forge verify-contract <CONTRACT_ADDRESS> src/Crowdfunding.sol:Crowdfunding --chain sepolia --etherscan-api-key $ETHERSCAN_API_KEY --constructor-args $(cast abi-encode "constructor(address)" <PLATFORM_FEE_RECIPIENT>)
```

## Contract Architecture

### State Variables
- `s_campaignCounter`: Tracks the number of campaigns created
- `s_campaigns`: Mapping of campaign IDs to Campaign structs
- `s_contributions`: Nested mapping tracking contributions (campaignId => contributor => amount)
- `PLATFORM_FEE_BPS`: Platform fee in basis points (200 = 2%)
- `i_platformFeeRecipient`: Immutable address receiving platform fees

### Key Functions

#### Public Functions
- `createCampaign(title, description, goal, deadline)`: Create a new campaign
- `contribute(campaignId)`: Contribute ETH to a campaign (payable)
- `withdrawFunds(campaignId)`: Withdraw funds from successful campaign
- `claimRefund(campaignId)`: Claim refund from failed/cancelled campaign
- `cancelCampaign(campaignId)`: Cancel an active campaign (creator only)

#### View Functions
- `getCampaignState(campaignId)`: Returns campaign state enum
- `getCampaignDetails(campaignId)`: Returns full campaign details
- `getContribution(campaignId, contributor)`: Returns contribution amount
- `isGoalReached(campaignId)`: Check if funding goal was reached
- `getTimeRemaining(campaignId)`: Time remaining until deadline
- `getTotalCampaigns()`: Total number of campaigns
- `getAllCampaignIds()`: Array of all campaign IDs

### Campaign States
- `ACTIVE`: Campaign is ongoing and accepting contributions
- `SUCCESSFUL`: Campaign reached its goal after deadline
- `FAILED`: Campaign did not reach goal after deadline
- `WITHDRAWN`: Funds have been withdrawn by creator
- `CANCELLED`: Campaign was cancelled by creator

## Security Features

1. **ReentrancyGuard**: Protects against reentrancy attacks on fund transfers
2. **Custom Errors**: Gas-efficient error handling
3. **Checks-Effects-Interactions**: Secure pattern for state changes
4. **Input Validation**: Comprehensive validation on all user inputs
5. **Access Control**: Proper authorization checks for sensitive operations

## Gas Optimization

- Custom errors instead of require strings
- State variable naming conventions (s_, i_, CONSTANT)
- Efficient storage layout
- Optimized loop operations

## Platform Fee

The platform charges a 2% fee (200 basis points) on successful withdrawals:
- Fee is automatically calculated and deducted when creators withdraw funds
- Remaining fees accumulate in the contract for the platform owner
- Fee calculation: `platformFee = (totalAmount * 200) / 10000`

## Testing Coverage

The project includes 58 comprehensive tests covering:
- Campaign creation and validation
- Contribution mechanics
- Withdrawal functionality
- Refund mechanisms
- Campaign cancellation
- Platform fee calculations
- State transitions
- Edge cases and error conditions
- Fuzz testing for critical functions

## Network Support

### Testnets
- Ethereum Sepolia
- Base Sepolia
- Arbitrum Sepolia

### Mainnets
- Ethereum Mainnet
- Base Mainnet
- Arbitrum Mainnet

## Project Structure

```
crowdfunder/
├── script/
│   ├── DeployCrowdfunding.s.sol    # Main deployment script
│   ├── HelperConfig.s.sol           # Multi-network configuration
│   └── Interactions.s.sol           # Interaction scripts
├── src/
│   └── Crowdfunding.sol             # Main contract
├── test/
│   └── Crowdfunding.t.sol           # Test suite
├── foundry.toml                     # Foundry configuration
├── Makefile                         # Deployment shortcuts
├── .env.example                     # Environment template
└── README.md                        # This file
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Support

For questions or issues, please open an issue on GitHub.

## Acknowledgments

- Built with [Foundry](https://getfoundry.sh/)
- Inspired by [Cyfrin Updraft](https://updraft.cyfrin.io/)
- Uses [OpenZeppelin](https://openzeppelin.com/) contracts
