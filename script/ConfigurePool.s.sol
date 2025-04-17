// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePool is Script {
    function run(
        address localPool,
        address remotePool,
        address remoteToken,
        uint64 remoteChainSelector,
        bool outBoundRateLimiterIsEnabled,
        uint128 outBoundRateLimiterCapacity,
        uint128 outBoundRateLimiterRate,
        bool inBoundRateLimiterIsEnabled,
        uint128 inBoundRateLimiterCapacity,
        uint128 inBoundRateLimiterRate
    ) public {
        //   struct ChainUpdate {
        //     uint64 remoteChainSelector; // ──╮ Remote chain selector
        //     bool allowed; // ────────────────╯ Whether the chain should be enabled
        //     bytes remotePoolAddress; //        Address of the remote pool, ABI encoded in the case of a remote EVM chain.
        //     bytes remoteTokenAddress; //       Address of the remote token, ABI encoded in the case of a remote EVM chain.
        //     RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
        //     RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
        //   }

        //   struct Config {
        //     bool isEnabled; // Indication whether the rate limiting should be enabled
        //     uint128 capacity; // ────╮ Specifies the capacity of the rate limiter
        //     uint128 rate; //  ───────╯ Specifies the rate of the rate limiter
        //  }
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outBoundRateLimiterIsEnabled,
                capacity: outBoundRateLimiterCapacity,
                rate: outBoundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inBoundRateLimiterIsEnabled,
                capacity: inBoundRateLimiterCapacity,
                rate: inBoundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}
