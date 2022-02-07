interface ITokenDistributor {
  function NUMBER_PERIODS (  ) external view returns ( uint256 );
  function PRECISION_FACTOR (  ) external view returns ( uint256 );
  function START_BLOCK (  ) external view returns ( uint256 );
  function accTokenPerShare (  ) external view returns ( uint256 );
  function calculatePendingRewards ( address user ) external view returns ( uint256 );
  function currentPhase (  ) external view returns ( uint256 );
  function deposit ( uint256 amount ) external;
  function endBlock (  ) external view returns ( uint256 );
  function harvestAndCompound (  ) external;
  function lastRewardBlock (  ) external view returns ( uint256 );
  function looksRareToken (  ) external view returns ( address );
  function rewardPerBlockForOthers (  ) external view returns ( uint256 );
  function rewardPerBlockForStaking (  ) external view returns ( uint256 );
  function stakingPeriod ( uint256 ) external view returns ( uint256 rewardPerBlockForStaking, uint256 rewardPerBlockForOthers, uint256 periodLengthInBlock );
  function tokenSplitter (  ) external view returns ( address );
  function totalAmountStaked (  ) external view returns ( uint256 );
  function updatePool (  ) external;
  function userInfo ( address ) external view returns ( uint256 amount, uint256 rewardDebt );
  function withdraw ( uint256 amount ) external;
  function withdrawAll (  ) external;
}
