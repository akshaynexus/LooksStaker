// SPDX-License-Identifier: AGPL-3.0
// Feel free to change the license, but this is what we use

// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {BaseStrategy} from "@yearnvaults/contracts/BaseStrategy.sol";
import {SafeERC20, SafeMath, IERC20, Address} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

// Import interfaces for many popular DeFi projects, or add your own!
import "../interfaces/ILooksStaker.sol";
import "../interfaces/ITokenDistributor.sol";

import "../interfaces/IUniswapRouter.sol";

contract LooksStakerStrategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    //Initiate staking gov interface
    ILooksStaker public staker = ILooksStaker(0xBcD7254A1D759EFA08eC7c3291B2E85c5dCC12ce);
    ITokenDistributor public distributor = ITokenDistributor(staker.tokenDistributor());

    IUniswapRouter public router = IUniswapRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    IERC20 weth = IERC20(router.WETH());
    event ProfitReported(uint profit);
    event WithdrewMore(uint more);

    constructor(address _vault) public BaseStrategy(_vault) {
        //Approve staking contract to spend LOOKS tokens
        want.safeApprove(address(staker), type(uint256).max);
        //Approve weth to swap for looks on univ2 router
        weth.safeApprove(address(router),type(uint256).max);
    }

    function name() external view override returns (string memory) {
        return "StrategyLooksStaking";
    }

    // returns balance of LOOKS
    function balanceOfWant() public view returns (uint256) {
        return want.balanceOf(address(this));
    }

    //Returns staked LOOKS value
    function balanceOfStake() public view returns (uint256) {
        return staker.calculateSharesValueInLOOKS(address(this));
    }

    function _convertLooksToShares(uint _looksAmt) internal view returns (uint) {
        //Get total shares
        uint256 totalShares = staker.totalShares();
        // Retrieve amount staked
        (uint256 totalAmountStaked, ) = distributor.userInfo(address(staker));

        // Adjust for pending rewards
        totalAmountStaked += distributor.calculatePendingRewards(address(staker));

        // Return amount of shares for looks
        return _looksAmt == 0 ? 0 : (_looksAmt * totalShares) / totalAmountStaked;
    }

    function getStakingPendingProfit() public view returns (uint256) {
        //Get total shares
        uint256 totalShares = staker.totalShares();
        // Retrieve amount staked
        (uint256 totalAmountStaked, ) = distributor.userInfo(address(staker));

        // Adjust for pending rewards
        uint totalRewardsPending = distributor.calculatePendingRewards(address(staker));

        uint stakedAmount = balanceOfStake();
        uint scaler = 1e9;
        return stakedAmount == 0 ? 0 : (((stakedAmount * scaler)/ totalAmountStaked)  * totalRewardsPending) / scaler; 
    }

    function _getBuyPath() internal view returns (address[] memory _path) {
        _path = new address[](2);
        _path[0] = address(weth);
        _path[1] = address(want);
    }

    function _convertToLooks(uint wethAmount) internal view returns (uint) {
        if(wethAmount == 0) return wethAmount;
        address[] memory _buyPath = _getBuyPath();
        router.getAmountsOut(wethAmount, _buyPath)[_buyPath.length- 1];
    }

    function pendingWETH() public view returns (uint256) {
        return staker.calculatePendingRewards(address(this));
    }

    function pendingReward() public view returns (uint256) {
        return _convertToLooks(pendingWETH()) + getStakingPendingProfit();
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return balanceOfWant().add(balanceOfStake()).add(pendingReward());
    }

    function _deposit(uint256 _depositAmount) internal {
       staker.deposit(_depositAmount, true);
    }

    function _withdraw(uint256 _withdrawAmount) internal {
        staker.withdraw(_convertLooksToShares(_withdrawAmount), true);
    }

    function getReward() internal {
        if(getStakingPendingProfit() > 0) {staker.harvest();}
        uint wethBal = weth.balanceOf(address(this));
        if (wethBal > 0) {
            //Sell any weth for looks via univ2
            router.swapExactTokensForTokens(wethBal, 0, _getBuyPath(), address(this), block.timestamp);
        }
    }

    function pendingProfit() public view returns (uint256) {
        uint256 debt = vault.strategies(address(this)).totalDebt;
        uint256 assets = estimatedTotalAssets();
        if (debt < assets) {
            //This will add to profit
            return assets.sub(debt);
        }
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        // We might need to return want to the vault
        if (_debtOutstanding > 0) {
            uint256 _amountFreed = 0;
            (_amountFreed, _loss) = liquidatePosition(_debtOutstanding);
            _debtPayment = Math.min(_amountFreed, _debtOutstanding);
        }

        uint256 balanceOfWantBefore = balanceOfWant();
        getReward();
        uint256 balanceAfter = balanceOfWant();

        _profit = pendingProfit();
        emit ProfitReported(_profit);
        uint256 requiredWantBal = _profit + _debtPayment;
        if (balanceAfter < requiredWantBal) {
            //Withdraw enough to satisfy profit check
            emit WithdrewMore(requiredWantBal.sub(balanceAfter));
            _withdraw(requiredWantBal.sub(balanceAfter));
        }
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        uint256 _wantAvailable = balanceOfWant();

        if (_debtOutstanding >= _wantAvailable) {
            return;
        }

        uint256 toInvest = _wantAvailable.sub(_debtOutstanding);

        if (toInvest > 0) {
            _deposit(toInvest);
        }
    }

    function liquidatePosition(uint256 _amountNeeded) internal override returns (uint256 _liquidatedAmount, uint256 _loss) {
        // NOTE: Maintain invariant `want.balanceOf(this) >= _liquidatedAmount`
        // NOTE: Maintain invariant `_liquidatedAmount + _loss <= _amountNeeded`
        uint256 balanceWant = balanceOfWant();
        uint256 balanceStaked = balanceOfStake();
        uint256 toWithdraw;
        if (_amountNeeded > balanceWant) {
            toWithdraw = (Math.min(balanceStaked, _amountNeeded - balanceWant));
            // unstake needed amount
            _withdraw(toWithdraw);
        }
        // Since we might free more than needed, let's send back the min
        _liquidatedAmount = Math.min(balanceOfWant(), _amountNeeded);
        _loss = _liquidatedAmount < _amountNeeded ? _amountNeeded.sub(_liquidatedAmount) : 0;
    }

    function prepareMigration(address _newStrategy) internal virtual override {
        //Withdraw all the staked Looks and claim any pending WETH
        staker.withdrawAll(true);
        //Transfer all gotten weth to new strat,we arent compounding on preparemigration
        weth.transfer(_newStrategy,weth.balanceOf(address(this)));
    }

    // Override this to add all tokens/tokenized positions this contract manages
    // on a *persistent* basis (e.g. not just for swapping back to want ephemerally)
    function protectedTokens() internal view override returns (address[] memory) {}
}
