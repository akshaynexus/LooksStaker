import pytest
from brownie import Wei, accounts, chain

# reference code taken from yHegic repo and stecrv strat
# https://github.com/Macarse/yhegic
# https://github.com/Grandthrax/yearnv2_steth_crv_strat


@pytest.mark.require_network("mainnet-fork")
def test_operation(
    currency,
    stakingstrategy,
    chain,
    vault,
    whale,
    gov,
    bob,
    alice,
    strategist,
    guardian,
    interface,
):
    # Amount configs
    test_budget = Wei("8880 ether")
    approve_amount = Wei("10000 ether")
    deposit_limit = Wei("8890 ether")
    bob_deposit = Wei("1000 ether")
    alice_deposit = Wei("7880 ether")
    currency.transfer(gov, test_budget, {"from": whale})

    vault.setDepositLimit(deposit_limit)

    # 100% of the vault's depositLimit
    vault.addStrategy(stakingstrategy, 10_000, 0, 2 ** 256 - 1, 0, {"from": gov})

    currency.approve(gov, approve_amount, {"from": gov})
    currency.transferFrom(gov, bob, bob_deposit, {"from": gov})
    currency.transferFrom(gov, alice, alice_deposit, {"from": gov})
    currency.approve(vault, approve_amount, {"from": bob})
    currency.approve(vault, approve_amount, {"from": alice})

    vault.deposit(bob_deposit, {"from": bob})
    vault.deposit(alice_deposit, {"from": alice})
    # Sleep and harvest 5 times
    sleepAndHarvest(5, stakingstrategy, gov)
    # sleep for 2 days
    chain.sleep(24 * 2 * 60 * 60)
    # Log estimated APR
    growthInShares = vault.pricePerShare() - 1e18
    growthInPercent = (growthInShares / 1e18) * 100
    growthInPercent = growthInPercent * 24
    growthYearly = growthInPercent * 365
    print(f"Yearly APR :{growthYearly}%")
    print(vault.pricePerShare() / 1e18)

    # We should have made profit or stayed stagnant (This happens when there is no rewards in 1INCH rewards)
    assert vault.pricePerShare() / 1e18 >= 1
    # Set debt ratio to lower than 100%
    vault.updateStrategyDebtRatio(stakingstrategy, 9_800, {"from": gov})
    # Withdraws should not fail
    vault.withdraw(alice_deposit, {"from": alice})
    assert stakingstrategy.surplusProfit() > 0
    # Try harvesting again,this should work
    stakingstrategy.harvest({"from": gov})
    vault.withdraw(bob_deposit, {"from": bob})

    # Depositors after withdraw should have a profit or gotten the original amount
    assert currency.balanceOf(alice) >= alice_deposit
    assert currency.balanceOf(bob) >= bob_deposit

    # Make sure it isnt less than 1 after depositors withdrew
    assert vault.pricePerShare() / 1e18 >= 1


def sleepAndHarvest(times, strat, gov):
    for i in range(times):
        debugStratData(strat, "Before harvest" + str(i))
        # Alchemix staking pools calculate reward per block,so mimic mainnet chain flow to get accurate returns
        for j in range(139):
            chain.sleep(13)
            chain.mine(1)
        strat.harvest({"from": gov})
        debugStratData(strat, "After harvest" + str(i))


# Used to debug strategy balance data
def debugStratData(strategy, msg):
    print(msg)
    print("Total assets " + str(strategy.estimatedTotalAssets()))
    print("LOOKS Balance " + str(strategy.balanceOfWant()))
    print("Stake balance " + str(strategy.balanceOfStake()))
    print("Pending reward " + str(strategy.pendingReward()))
