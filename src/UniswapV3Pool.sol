pragma solidity ^0.8.14;

import "./lib/Position.sol";
import "./lib/Tick.sol";
import "forge-std/interfaces/IERC20.sol";
import "./interfaces/callback/IUniswapV3MintCallback.sol";

contract CustomError {
    error InvalidTickRange();
    error ZeroLiquidity();
    error InsufficientInputAmount();
}

// src/UniswapV3Pool.sol
contract UniswapV3Pool is CustomError {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    event Mint(address, address, int24, int24, uint128, uint128, uint128);

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    // Pool tokens, immutable
    address public immutable token0;
    address public immutable token1;

    // Packing variables that are read together
    struct Slot0 {
        // Current sqrt(P)
        uint160 sqrtPriceX96;
        // Current tick
        int24 tick;
    }
    Slot0 public slot0;

    // Amount of liquidity, L.
    uint128 public liquidity;

    // Ticks info
    mapping(int24 => Tick.Info) public ticks;
    // Positions info
    mapping(bytes32 => Position.Info) public positions;

    constructor(
        address token0_,
        address token1_,
        uint160 sqrtPriceX96,
        int24 tick
    ) {
        token0 = token0_;
        token1 = token1_;

        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    /**
     *
     * @param owner Owner’s address, to track the owner of the liquidity.
     * @param lowerTick Upper and lower ticks, to set the bounds of a price range.
     * @param upperTick Upper and lower ticks, to set the bounds of a price range.
     * @param amount The amount of liquidity we want to provide.
     * @return amount0
     * @return amount1
     */
    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount
    ) external returns (uint128 amount0, uint128 amount1) {
        if (
            lowerTick >= upperTick ||
            lowerTick < MIN_TICK ||
            upperTick > MAX_TICK
        ) revert InvalidTickRange();

        if (amount == 0) revert ZeroLiquidity();

        ticks.update(lowerTick, amount);
        ticks.update(upperTick, amount);

        Position.Info storage position = positions.get(
            owner,
            lowerTick,
            upperTick
        );
        position.update(amount);

        //hardcode temporary
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        liquidity += uint128(amount);

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1
        );

        if (amount0 > 0 && balance0Before + amount0 > balance0())
            revert InsufficientInputAmount();

        if (amount1 > 0 && balance1Before + amount1 > balance1())
            revert InsufficientInputAmount();

        emit Mint(
            msg.sender,
            owner,
            lowerTick,
            upperTick,
            amount,
            amount0,
            amount1
        );
    }

    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }
}
