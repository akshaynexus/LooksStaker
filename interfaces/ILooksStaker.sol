interface ILooksStaker {
  function PRECISION_FACTOR (  ) external view returns ( uint256 );
  function calculatePendingRewards ( address user ) external view returns ( uint256 );
  function calculateSharePriceInLOOKS (  ) external view returns ( uint256 );
  function calculateSharesValueInLOOKS ( address user ) external view returns ( uint256 );
  function currentRewardPerBlock (  ) external view returns ( uint256 );
  function deposit ( uint256 amount, bool claimRewardToken ) external;
  function harvest (  ) external;
  function lastRewardAdjustment (  ) external view returns ( uint256 );
  function lastRewardBlock (  ) external view returns ( uint256 );
  function lastUpdateBlock (  ) external view returns ( uint256 );
  function looksRareToken (  ) external view returns ( address );
  function owner (  ) external view returns ( address );
  function periodEndBlock (  ) external view returns ( uint256 );
  function renounceOwnership (  ) external;
  function rewardPerTokenStored (  ) external view returns ( uint256 );
  function rewardToken (  ) external view returns ( address );
  function tokenDistributor (  ) external view returns ( address );
  function totalShares (  ) external view returns ( uint256 );
  function transferOwnership ( address newOwner ) external;
  function updateRewards ( uint256 reward, uint256 rewardDurationInBlocks ) external;
  function userInfo ( address ) external view returns ( uint256 shares, uint256 userRewardPerTokenPaid, uint256 rewards );
  function withdraw ( uint256 shares, bool claimRewardToken ) external;
  function withdrawAll ( bool claimRewardToken ) external;
}
