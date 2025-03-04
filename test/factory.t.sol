// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/factory/inscriptionFactory_v1.sol";
import "../src/factory/inscriptionFactory_v2.sol";
contract InscriptionFactoryTest is Test {
    InscriptionFactoryV1 factoryV1;
    InscriptionFactoryV2 factoryV2;
    address user = address(0x123);

    function setUp() public {
        factoryV1 = new InscriptionFactoryV1();
        factoryV2 = new InscriptionFactoryV2();
        vm.deal(user, 10 ether);
    }

    function testV1DeployAndMint() public {
        address token = factoryV1.deployInscription("TEST", 1000, 100);
        assertTrue(factoryV1.isInscription(token));
        
        vm.prank(user);
        factoryV1.mintInscription(token);
        
        InscriptionToken tokenContract = InscriptionToken(token);
        assertEq(tokenContract.balanceOf(user), 100);
        assertEq(tokenContract.symbol(), "TEST");
    }

    function testV2DeployAndMint() public {
        address token = factoryV2.deployInscription("Test Token", "TEST", 1000, 100, 0.01 ether);
        assertTrue(factoryV2.isInscription(token));
        
        vm.prank(user);
        factoryV2.mintInscription{value: 1 ether}(token);
        
        InscriptionTokenV2 tokenContract = InscriptionTokenV2(token);
        assertEq(tokenContract.balanceOf(user), 100);
        assertEq(tokenContract.name(), "Test Token");
        assertEq(tokenContract.symbol(), "TEST");
        assertEq(tokenContract.price(), 0.01 ether);
        assertEq(tokenContract.perMint(), 100);
    }

    function testUpgradeCompatibility() public {
        address tokenV1 = factoryV1.deployInscription("TEST", 1000, 100);
        vm.prank(user);
        factoryV1.mintInscription(tokenV1);
        
        address tokenV2 = factoryV2.deployInscription("Test Token", "TEST", 1000, 100, 0.01 ether);
        vm.prank(user);
        factoryV2.mintInscription{value: 1 ether}(tokenV2);
        
        assertEq(InscriptionToken(tokenV1).balanceOf(user), 
                InscriptionTokenV2(tokenV2).balanceOf(user));
        
        assertEq(InscriptionTokenV2(tokenV2).name(), "Test Token");
        assertEq(InscriptionTokenV2(tokenV2).symbol(), "TEST");
    }

    function testV2MintPayment() public {
        address token = factoryV2.deployInscription("Test Token", "TEST", 1000, 100, 0.01 ether);
        
        vm.prank(user);
        vm.expectRevert("Insufficient payment");
        factoryV2.mintInscription{value: 0.005 ether}(token);

        vm.prank(user);
        factoryV2.mintInscription{value: 1 ether}(token);
        assertEq(InscriptionTokenV2(token).balanceOf(user), 100);

        uint256 balanceBefore = user.balance;
        vm.prank(user);
        factoryV2.mintInscription{value: 2 ether}(token);
        uint256 balanceAfter = user.balance;
        assertEq(InscriptionTokenV2(token).balanceOf(user), 200);
        assertEq(balanceBefore - balanceAfter, 1 ether);
    }
}