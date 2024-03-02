// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import "../ERC20.sol";


contract TitanX is ERC20 {


    constructor() ERC20("TITANX", "TITANX") {
        _mint(msg.sender, 1000000000 * (10 ** 18));
    }

}