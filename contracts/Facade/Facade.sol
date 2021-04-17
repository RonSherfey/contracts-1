pragma solidity 0.8.3;

/**
 *  _____________________________________________
 * / oooooo   oooooo     oooo ooooo ooooooooo    \
 * |  `888     `888       8'  `888' `888   `Y88  |
 * |   `888     8888     8'    888   888    d88' |
 * |    `888   8'`888   8'     888   888ooo88P'  |
 * |     `888 8'  `888 8'      888   888         |
 * |      `888'    `888'       888   888         |
 * |       `8'      `8'       o888o o888o        |
 * \____________________________________________/
 *        \   ^__^
 *         \  (oo)\_______
 *            (__)\       )\/\
 *                ||----w |
 *                ||     ||
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Hegic
 * Copyright (C) 2021 Hegic Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import "../Interfaces/Interfaces.sol";

contract Facade is Ownable {
    mapping(IERC20 => IHegicOptions) optionController;

    IWETH public immutable WETH;
    IERC20 public stableToken;
    IUniswapV2Router01 public immutable exchange;

    constructor(
        IWETH weth,
        IERC20 stable,
        IUniswapV2Router01 router
    ) {
        WETH = weth;
        exchange = router;
        stableToken = stable;
    }

    function createOption(
        IERC20 token,
        uint256 period,
        uint256 amount,
        uint256 strike,
        IHegicOptions.OptionType optionType
    ) external payable {
        (uint256 fee1, uint256 fee2) =
            optionController[token].priceCalculator().fees(
                period,
                amount,
                strike,
                optionType
            );
        _wrapTo(token, fee1 + fee2);
        IHegicOptions options = optionController[token];
        options.createFor(msg.sender, period, amount, strike, optionType);
        if (address(this).balance > 0)
            payable(msg.sender).transfer(address(this).balance);
    }

    function append(IERC20 token, IHegicOptions options) external onlyOwner {
        optionController[token] = options;
        stableToken.approve(address(options), type(uint256).max);
        token.approve(address(options), type(uint256).max);
    }

    function stop(IERC20 token) external onlyOwner {
        delete optionController[token];
    }

    function _wrapTo(IERC20 token, uint256 amount) internal {
        if (address(token) == address(WETH)) WETH.deposit{value: amount}();
        else {
            address[] memory path = new address[](2);
            path[0] = address(WETH);
            path[1] = address(token);
            uint256[] memory amounts = exchange.getAmountsIn(amount, path);
            exchange.swapETHForExactTokens{value: amounts[0]}(
                amount,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    /**
     * @notice Unlocks an array of options
     * @param optionIDs array of options
     */
    function unlockAll(IERC20 token, uint256[] calldata optionIDs) external {
        uint256 arrayLength = optionIDs.length;
        IHegicOptions options = optionController[token];
        for (uint256 i = 0; i < arrayLength; i++) {
            options.unlock(optionIDs[i]);
        }
    }
}
