// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

abstract contract CodeConstants {
    /*//////////////////////////////////////////////////////////////
                               CHAIN IDS
    //////////////////////////////////////////////////////////////*/
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant BASE_MAINNET_CHAIN_ID = 8453;
    uint256 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint256 public constant ARBITRUM_MAINNET_CHAIN_ID = 42161;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    /*//////////////////////////////////////////////////////////////
                          PLATFORM FEE RECIPIENTS
    //////////////////////////////////////////////////////////////*/
    // Default platform fee recipient for testnets (replace with your address)
    address public constant DEFAULT_TESTNET_FEE_RECIPIENT =
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Anvil default account #1

    // Default platform fee recipient for mainnets (replace with your address)
    address public constant DEFAULT_MAINNET_FEE_RECIPIENT =
        0x0000000000000000000000000000000000000000; // UPDATE THIS FOR MAINNET!
}

contract HelperConfig is CodeConstants, Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error HelperConfig__InvalidChainId();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct NetworkConfig {
        address platformFeeRecipient;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    // Local network state variables
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        networkConfigs[BASE_SEPOLIA_CHAIN_ID] = getBaseSepoliaConfig();
        networkConfigs[BASE_MAINNET_CHAIN_ID] = getBaseMainnetConfig();
        networkConfigs[ARBITRUM_SEPOLIA_CHAIN_ID] = getArbitrumSepoliaConfig();
        networkConfigs[ARBITRUM_MAINNET_CHAIN_ID] = getArbitrumMainnetConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].platformFeeRecipient != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /*//////////////////////////////////////////////////////////////
                          TESTNET CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({platformFeeRecipient: DEFAULT_TESTNET_FEE_RECIPIENT});
    }

    function getBaseSepoliaConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({platformFeeRecipient: DEFAULT_TESTNET_FEE_RECIPIENT});
    }

    function getArbitrumSepoliaConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({platformFeeRecipient: DEFAULT_TESTNET_FEE_RECIPIENT});
    }

    /*//////////////////////////////////////////////////////////////
                          MAINNET CONFIGS
    //////////////////////////////////////////////////////////////*/
    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({platformFeeRecipient: DEFAULT_MAINNET_FEE_RECIPIENT});
    }

    function getBaseMainnetConfig() public pure returns (NetworkConfig memory) {
        return
            NetworkConfig({platformFeeRecipient: DEFAULT_MAINNET_FEE_RECIPIENT});
    }

    function getArbitrumMainnetConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({platformFeeRecipient: DEFAULT_MAINNET_FEE_RECIPIENT});
    }

    /*//////////////////////////////////////////////////////////////
                              LOCAL CONFIG
    //////////////////////////////////////////////////////////////*/
    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory)
    {
        // Check to see if we set an active network config
        if (localNetworkConfig.platformFeeRecipient != address(0)) {
            return localNetworkConfig;
        }

        console2.log(unicode"⚠️ You are deploying to a local Anvil chain!");
        console2.log("Make sure this was intentional");

        // Use Anvil's default account #1 as the platform fee recipient
        // Private key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
        localNetworkConfig = NetworkConfig({
            platformFeeRecipient: DEFAULT_TESTNET_FEE_RECIPIENT
        });

        return localNetworkConfig;
    }
}
