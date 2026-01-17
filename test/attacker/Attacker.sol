// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IFlashLoan {

}

contract Attacker {
    // this contract receiving token 
    // maybe deposit 

    constructor() {}
    function executeOperation(address token,uint256 amount,uint256 fee ,address flashLoan,bytes calldata params) external {
        
    }
}