import pytest
from brownie import config, LooksStakerStrategy


@pytest.fixture
def andre(accounts):
    # Andre, giver of tokens, and maker of yield
    yield accounts[0]


@pytest.fixture
def gov(accounts):
    # yearn multis... I mean YFI governance. I swear!
    yield accounts[1]


@pytest.fixture
def guardian(accounts):
    # YFI Whale, probably
    yield accounts[2]


@pytest.fixture
def strategist(accounts):
    # You! Our new Strategist!
    yield accounts[3]


@pytest.fixture
def keeper(accounts):
    # This is our trusty bot!
    yield accounts[4]


@pytest.fixture
def bob(accounts):
    yield accounts[5]


@pytest.fixture
def alice(accounts):
    yield accounts[6]


@pytest.fixture
def rewards(gov):
    yield gov  # TODO: Add rewards contract


@pytest.fixture
def currency(interface):
    yield interface.ERC20("0xf4d2888d29D722226FafA5d9B24F9164c092421E")


@pytest.fixture
def whale(accounts):
    # Airdrop contract,has plenty tokens
    yield accounts.at("0xA35dce3e0E6ceb67a30b8D7f4aEe721C949B5970", force=True)


@pytest.fixture
def vault(pm, gov, rewards, guardian, currency):
    Vault = pm(config["dependencies"][0]).Vault
    vault = gov.deploy(Vault)
    vault.initialize(currency, gov, rewards, "", "", guardian)
    vault.setManagementFee(0, {"from": gov})
    vault.setDepositLimit(2 ** 256 - 1, {"from": gov})
    yield vault


@pytest.fixture
def stakingstrategy(strategist, keeper, vault):
    strategy = strategist.deploy(LooksStakerStrategy, vault)
    strategy.setKeeper(keeper)
    yield strategy
