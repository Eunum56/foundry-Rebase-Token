// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool{
    constructor(IERC20 token, address[] memory allowList, address rnmProxy, address router) TokenPool(token, allowList, rnmProxy, router) {}

    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external returns(Pool.LockOrBurnOutV1 memory lockOrBurnOut) {
        _validateLockOrBurn(lockOrBurnIn);
        address originalSender = lockOrBurnIn.originalSender;
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);
        lockOrBurnOut = Pool.LockOrBurnOutV1({destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector), destPoolData: abi.encode(userInterestRate)});
    }
    
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external returns(Pool.ReleaseOrMintOutV1 memory) {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount, userInterestRate);
        return Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}