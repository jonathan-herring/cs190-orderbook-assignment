// SPDX-License-Identifier: UNLICENSED
// AI Usage: Gemini for Solidity syntax info and exposed base functions
pragma solidity ^0.8.20;

import {IOrderbook} from "./IOrderbook.sol";

/// @dev Minimal ERC20 surface the orderbook needs. The provided `MockERC20`
///      implements all of these methods (plus `mint`).
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @title Orderbook (template)
/// @notice Skeleton to complete. The constructor, immutable
///         token wiring, and the two trivial getters are already done —
///         everything else reverts with `"NotImplemented"`.
///
///         You are free to add additional state, structs, errors, and
///         helper functions. The only hard constraints are:
///         (1) keep the `IOrderbook` ABI exactly as declared in the
///             interface (the grading harness depends on it), and
///         (2) keep `baseToken`/`quoteToken` as immutables set in the
///             constructor.
contract Orderbook is IOrderbook {
    IERC20 public immutable baseToken;
    IERC20 public immutable quoteToken;

    struct Order {
        address maker;
        uint256 amount;
        uint256 price;
    }

    Order[] private bids;
    Order[] private asks;
    uint256 private nextOrderId = 1;

    /// @dev Suggested events. These are a starting point — your
    ///      implementation may emit a different set, rename them, or omit
    ///      events entirely. Nothing in the grading harness depends on
    ///      these signatures.
    event OrderPlaced(
        uint256 indexed orderId,
        address indexed maker,
        Side side,
        uint256 price,
        uint256 amount
    );
    event OrderFilled(
        uint256 indexed orderId,
        address indexed taker,
        uint256 fillAmount,
        uint256 fillPrice
    );
    event OrderCleared();

    constructor(address _baseToken, address _quoteToken) {
        require(_baseToken != address(0), "baseToken=0");
        require(_quoteToken != address(0), "quoteToken=0");
        require(_baseToken != _quoteToken, "base==quote");
        baseToken = IERC20(_baseToken);
        quoteToken = IERC20(_quoteToken);
    }

    function getBaseToken() external view returns (address) {
        return address(baseToken);
    }

    function getQuoteToken() external view returns (address) {
        return address(quoteToken);
    }

    function placeLimitOrder(Side side, uint256 price, uint256 amount) external returns (uint256) {
        
        Order memory order = Order({maker: msg.sender, price: price, amount: amount});

        if (side == Side.BUY) {
            uint256 quoteAmount = amount * price / 1e18;
            quoteToken.transferFrom(msg.sender, address(this), quoteAmount);

            uint i = 0;
            while (i < bids.length && bids[i].price >= order.price) {
                i++;
            }
            
            bids.push(order);
            uint256 j = bids.length - 1;
            while(j > i) {
                bids[j] = bids[j - 1];
                j--;
            }

            bids[i] = order;
        } else {
            baseToken.transferFrom(msg.sender, address(this), amount);

            uint i = 0;
            while (i < asks.length && asks[i].price <= order.price) {
                i++;
            }

            asks.push(order);
            uint256 j = asks.length - 1;
            while(j > i) {
                asks[j] = asks[j - 1];
                j--;
            }

            asks[i] = order;
        }

        return nextOrderId++;
    }

    function placeMarketOrder(Side side, uint256 amount) external {
        
        if (side == Side.BUY) {
            while (amount > 0 && asks.length > 0) {

                address seller = asks[0].maker;
                uint256 askPrice = asks[0].price;
                uint256 amountMatched;

                if (amount < asks[0].amount) {
                    amountMatched = amount;
                    asks[0].amount -= amountMatched;
                } else {
                    amountMatched = asks[0].amount;

                    for (uint256 i = 0; i < asks.length - 1; i++) {
                        asks[i] = asks[i + 1];
                    }

                    asks.pop();
                }

                uint256 quoteAmount = amountMatched * askPrice / 1e18;
                
                quoteToken.transferFrom(msg.sender, address(this), quoteAmount);
                quoteToken.transfer(seller, quoteAmount);
                baseToken.transfer(msg.sender, amountMatched);

                amount -= amountMatched;
            }
        } else {
            while (amount > 0 && bids.length > 0) {
                address buyer = bids[0].maker;
                uint256 bidPrice = bids[0].price;
                uint256 amountMatched;

                if (amount < bids[0].amount) {
                        amountMatched = amount;
                        bids[0].amount -= amountMatched;
                } else {
                    amountMatched = bids[0].amount;

                    for (uint256 i = 0; i < bids.length - 1; i++) {
                        bids[i] = bids[i + 1];
                    }

                    bids.pop();
                }

                uint256 quoteAmount = amountMatched * bidPrice / 1e18;

                baseToken.transferFrom(msg.sender, address(this), amountMatched);
                baseToken.transfer(buyer, amountMatched);
                quoteToken.transfer(msg.sender, quoteAmount);

                amount -= amountMatched;
            }
        }
    }

    function clear() external {
        delete bids;
        delete asks;
    }

    function getBidsCount() external view returns (uint256) {
        return bids.length;
    }

    function getAsksCount() external view returns (uint256) {
        return asks.length;
    }

    function getMidPrice() external view returns (uint256) {
        require(bids.length > 0, "there are no bids");
        require(asks.length > 0, "there are no asks");

        return (bids[0].price + asks[0].price) / 2;
    }
}
