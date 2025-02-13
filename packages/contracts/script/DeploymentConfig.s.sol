//// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { MiniMeTokenFactory } from "@vacp2p/minime/contracts/MiniMeTokenFactory.sol";
import { MiniMeToken } from "@vacp2p/minime/contracts/MiniMeToken.sol";

contract DeploymentConfig is Script {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        uint32 votingLengthInSeconds;
        uint32 votingVerificationLengthInSeconds;
        uint32 timeBetweenVotingInSeconds;
        uint32 featuredVotingLengthInSeconds;
        uint32 featuredVotingVerificationLengthInSeconds;
        uint8 cooldownPeriod;
        uint8 featuredPerVotingCount;
        address voteToken;
    }

    uint32 internal constant TWO_DAYS_IN_SECONDS = 2 * 24 * 3600;
    uint32 internal constant FIVE_DAYS_IN_SECONDS = 5 * 24 * 3600;
    uint32 internal constant FOUR_MINS_IN_SECONDS = 4 * 60;
    uint32 internal constant TWO_MINS_IN_SECONDS = 2 * 60;
    uint32 internal constant ONE_MIN_IN_SECONDS = 60;
    uint32 internal constant TWO_WEEKS_IN_SECONDS = 2 * 7 * 24 * 3600;
    uint32 internal constant ONE_WEEK_IN_SECONDS = 7 * 24 * 3600;
    uint32 internal constant THIRTY_DAYS_IN_SECONDS = 30 * 24 * 3600;

    address public deployer;

    // solhint-disable-next-line var-name-mixedcase
    address internal SNT_ADDRESS_GOERLI = 0x3D6AFAA395C31FCd391fE3D562E75fe9E8ec7E6a;
    // solhint-disable-next-line var-name-mixedcase
    address internal SNT_ADDRESS_MAINNET = 0x744d70FDBE2Ba4CF95131626614a1763DF805B9E;

    constructor(address _broadcaster) {
        deployer = _broadcaster;
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 5) {
            activeNetworkConfig = getGoerliEthConfig();
        } else if (block.chainid == 31_337) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert("no network config for this chain");
        }
    }

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            votingLengthInSeconds: TWO_WEEKS_IN_SECONDS,
            votingVerificationLengthInSeconds: ONE_WEEK_IN_SECONDS,
            timeBetweenVotingInSeconds: THIRTY_DAYS_IN_SECONDS,
            featuredVotingLengthInSeconds: FIVE_DAYS_IN_SECONDS,
            featuredVotingVerificationLengthInSeconds: TWO_DAYS_IN_SECONDS,
            cooldownPeriod: 3,
            featuredPerVotingCount: 5,
            voteToken: SNT_ADDRESS_MAINNET
        });
    }

    function getGoerliEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            votingLengthInSeconds: FOUR_MINS_IN_SECONDS,
            votingVerificationLengthInSeconds: TWO_MINS_IN_SECONDS,
            timeBetweenVotingInSeconds: ONE_MIN_IN_SECONDS,
            featuredVotingLengthInSeconds: FOUR_MINS_IN_SECONDS,
            featuredVotingVerificationLengthInSeconds: TWO_MINS_IN_SECONDS,
            cooldownPeriod: 1,
            featuredPerVotingCount: 3,
            voteToken: SNT_ADDRESS_GOERLI
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast(deployer);
        MiniMeTokenFactory minimeFactory = new MiniMeTokenFactory();
        MiniMeToken minimeToken = new MiniMeToken(
            minimeFactory,
            MiniMeToken(payable(address(0))),
            0,
            "Status Network Token",
            18,
            "STT",
            true
        );
        vm.stopBroadcast();

        return NetworkConfig({
            votingLengthInSeconds: FOUR_MINS_IN_SECONDS,
            votingVerificationLengthInSeconds: TWO_MINS_IN_SECONDS,
            timeBetweenVotingInSeconds: ONE_MIN_IN_SECONDS,
            featuredVotingLengthInSeconds: FOUR_MINS_IN_SECONDS,
            featuredVotingVerificationLengthInSeconds: TWO_MINS_IN_SECONDS,
            cooldownPeriod: 1,
            featuredPerVotingCount: 3,
            voteToken: address(minimeToken)
        });
    }
}
