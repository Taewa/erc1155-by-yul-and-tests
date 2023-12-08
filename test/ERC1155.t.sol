// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
// pragma solidity = 0.8.15;

// import {DSTestPlus} from "./utils/DSTestPlus.sol";
import "forge-std/Test.sol";
import "./lib/YulDeployer.sol";
import {ERC1155TokenReceiver} from "../tokens/ERC1155.sol";

interface ERC1155Yul {
    function taehwa() external returns (uint256); // <- for test purpose. 
    function mint(address,uint256,uint256) external;
    function balanceOf(address,uint256) external returns (uint256);
    function batchMint(address,uint256[] memory,uint256[] memory) external;
    function dataCheck(address,uint256[] memory,uint256[] memory) external returns(uint256);
    function isApprovedForAll(address,address) external returns (bool);
    function setApprovalForAll(address,bool) external;
    function safeTransferFrom(address,address,uint256,uint256) external;
    function safeBatchTransferFrom(address,address,uint256[] memory,uint256[] memory) external;
    function uri(uint256) external returns(string memory);
}

contract TestContract {
    address public addrA;
    uint256 public uintA;
    bytes public bytesA;
    bytes32 public bytes32A;

    function runBytesArgAndPrint(uint256 _n, bytes calldata _d) public {
    // function runBytesArgAndPrint(uint256 _n) public {
        // console.log("testBytesArg is CALLED!!!!!!!!!!");
        // console.log('_n:::::::::', _n);
        // console.log('print bytes....');
        // console.logBytes(_d);
    }

    // function testFunction(address _addrA, address _addrB, uint256 _uintA, uint256 _uintB) public {
    //     addrA = _addrA;
    //     uintA = _uintA;

    //     console.log("testFunction is called");
    //     console.log("_addrA:", _addrA);
    //     console.log("_addrB:", _addrB);
    //     console.log("_uintA:", _uintA);
    //     console.log("_uintB:", _uintB);
    //     console.logBytes(msg.data);
    // }

    // function testFunctionWithBytes32(address _addrA, address _addrB, uint256 _uintA, uint256 _uintB, bytes32 _bytes32) public {
    //     addrA = _addrA;
    //     uintA = _uintA;
    //     bytes32A = _bytes32;

    //     console.log("testFunctionWithBytes32 is called @@@@@@");
    //     console.log("_addrA:", _addrA);
    //     console.log("_addrB:", _addrB);
    //     console.log("_uintA:", _uintA);
    //     console.log("_uintB:", _uintB);
    //     console.log("--------------------- _bytes32 ---------------------");
    //     console.logBytes32(_bytes32);
    //     console.log("--------------------- msg.data ---------------------");
    //     console.logBytes(msg.data);
    // }

    // function testFunctionWithBytes(address _addrA, address _addrB, uint256 _uintA, uint256 _uintB, bytes memory _bytes) public {
    //     addrA = _addrA;
    //     uintA = _uintA;
    //     bytesA = _bytes;

    //     console.log("testFunctionWithBytes is called !!!");
    //     console.log("_addrA:", _addrA);
    //     console.log("_addrB:", _addrB);
    //     console.log("_uintA:", _uintA);
    //     console.log("_uintB:", _uintB);
    //     // console.log("_bytes:", _bytes);
    //     console.logBytes(msg.data);
    // }

    // function testFunctionWithBytes(address _addrA, address _addrB, uint256 _uintA, uint256 _uintB) public {
    //     addrA = _addrA;
    //     uintA = _uintA;

    //     console.log("testFunctionWithBytes is called !!!");
    //     console.log("_addrA:", _addrA);
    //     console.log("_addrB:", _addrB);
    //     console.log("_uintA:", _uintA);
    //     console.log("_uintB:", _uintB);
    //     console.logBytes(msg.data);
    // }
}

contract ERC1155Recipient is ERC1155TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    uint256 public amount;
    bytes public mintData;

    // fallback function can be useful for debugging
    // call non-exist function and see the data
    // Use console.logBytes(msg.data); for debugging
    // fallback(bytes calldata _data) external returns(bytes memory) {
    //     console.log("fallback:::::::::%%%%%");
    //     console.logBytes(msg.data);
    // }

    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _amount,
        bytes calldata _data
    ) external override returns (bytes4) {
        operator = _operator;  // <- it stores data in the storage thus cannot use 'staticcall' on yul but 'call' because staticcall cannot update anything but view
        from = _from;
        id = _id;
        amount = _amount;
        mintData = _data;

        console.log("onERC1155Received is called!");

        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    address public batchOperator;
    address public batchFrom;
    uint256[] internal _batchIds;
    uint256[] internal _batchAmounts;
    bytes public batchData;

    function batchIds() external view returns (uint256[] memory) {
        return _batchIds;
    }

    function batchAmounts() external view returns (uint256[] memory) {
        return _batchAmounts;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external override returns (bytes4) {
        batchOperator = _operator;
        batchFrom = _from;
        _batchIds = _ids;
        _batchAmounts = _amounts;
        batchData = _data;

        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }    
}

/**** 
** By Taehwa
** Not sure what's the cause but 'owner' and  'caller' have different address sometimes thus calledByOwner() never works
** I solved by inheriting or implement deployContract() inside each test contract 
****/
// contract ERC1155YulTest is Test {
// TODO: Don't inherite YulDeployer and use vm.spank // YulDeployer
contract ERC1155YulTest is Test {
    YulDeployer yulDeployer = new YulDeployer();
    ERC1155Yul erc1155YulContract;

    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 amount
    );

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] amounts
    );

    event ApprovalForAll(
        address indexed owner, 
        address indexed operator, 
        bool approved
    );

    function setUp() public {
        erc1155YulContract = ERC1155Yul(yulDeployer.deployContract("ERC1155Yul"));
    }

    function testMintToEOA() public {
        address _address = address(0xBEEF);
        uint256 _id = 100;
        uint256 _tokenAmount = 1;
        
        vm.prank(address(yulDeployer));

        //TODO: original mint() has 'bytes' arg. Implement it.
        erc1155YulContract.mint(_address, _id, _tokenAmount);

        assertEq(erc1155YulContract.balanceOf(_address, _id), 1, "it has to have the same amount of token as minted.");
    }

    function testMintToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        vm.prank(address(yulDeployer));
        
        erc1155YulContract.mint(address(to), 1337, 1);

        assertEq(erc1155YulContract.balanceOf(address(to), 1337), 1);

        uint256 balance = erc1155YulContract.balanceOf(address(to), 1337);
        assertEq(balance, 1);

        // TODO: check _checkSafeTransfer()'s TODO comment
        assertEq(to.operator(), address(yulDeployer));
        assertEq(to.from(), address(0));
        assertEq(to.id(), 1337);
        // assertBytesEq(to.mintData(), "testing 123");
    }

    function testEmitTransferSingle() public {
        vm.prank(address(yulDeployer));
        // Testing event emit
        // It needs 3 steps
        // #0 make sure to declare event TransferSingle(...)
        // #1 call expectEmit. First 3 'true's are the 'indexed' topics. In Solidity/Yul, Only 3 indexed topics can be added per event
        vm.expectEmit(true, true, true, true);
        
        address _address = address(0xBEEF);
        uint256 _id = 100;
        uint256 _tokenAmount = 1;
        
        // #2 Then emit event. This is going to be compared with the "real" event. Basically this is an expected event
        emit TransferSingle(address(yulDeployer), address(yulDeployer), address(0xBEEF), 100, 1);

        erc1155YulContract.mint(_address, _id, _tokenAmount);           
    }

    function testBatchMintToEOA() public {
        vm.prank(address(yulDeployer));

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;
        amounts[3] = 400;
        amounts[4] = 500;

        erc1155YulContract.batchMint(address(0xBEEF), ids, amounts);

        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1337), 100);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1338), 200);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1339), 300);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1340), 400);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1341), 500);
    }

    function testTransferBatch() public {
        vm.prank(address(yulDeployer));

        // Testing event emit
        // It needs 2 steps
        // #1 call expectEmit. First 3 'true's are the 'indexed' topics. In Solidity/Yul, Only 3 indexed topics can be added per event
        vm.expectEmit(true, true, true, true);
        
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 100;
        amounts[1] = 200;
        amounts[2] = 300;

        // #2 Then emit event. This is going to be compared with the "real" event.
        emit TransferBatch(address(yulDeployer), address(yulDeployer), address(0xBEEF), ids, amounts);

        erc1155YulContract.batchMint(address(0xBEEF), ids, amounts);
    }

    function testIsApprovedForAllShouldBeFalseByDefault() public {
        address owner = address(this);
        address operator = address(0xBEEF);
        bool isFalse = erc1155YulContract.isApprovedForAll(owner, operator);

        assertEq(isFalse, false);
    }

    function testIsApprovedForAllShouldBeTrue() public {
        address owner = address(this);
        address operator = address(0xBEEF);

        erc1155YulContract.setApprovalForAll(operator, true);   // Set operator as approved
        bool isTrue = erc1155YulContract.isApprovedForAll(owner, operator);

        assertTrue(isTrue);
    }

    function testIsApprovedForAllShouldBeFalse() public {
        address owner = address(this);
        address operator = address(0xBEEF);

        erc1155YulContract.setApprovalForAll(operator, true);   // Set operator as approved
        bool isTrue = erc1155YulContract.isApprovedForAll(owner, operator); // First, make it true

        assertTrue(isTrue);

        erc1155YulContract.setApprovalForAll(operator, false);
        bool isFalse = erc1155YulContract.isApprovedForAll(owner, operator); // Then make it false

        assertFalse(isFalse);
    }

    function testApprovalForAllEvent() public {
        // Testing event emit
        vm.expectEmit(true, true, false, true);
        
        address owner = address(this);
        address operator = address(0xBEEF);

        emit ApprovalForAll(owner, operator, true);

        erc1155YulContract.setApprovalForAll(operator, true);
    }

    function testSafeTransferFromToEOA() public {
        vm.prank(address(yulDeployer));

        address from = address(0xABCD);
        address to = address(0xFFFF);

        erc1155YulContract.mint(from, 1337, 100);

        vm.prank(from);
        erc1155YulContract.setApprovalForAll(address(from), true);

        assertEq(erc1155YulContract.balanceOf(to, 1337), 0);
        vm.prank(from);
        erc1155YulContract.safeTransferFrom(from, to, 1337, 70);

        assertEq(erc1155YulContract.balanceOf(to, 1337), 70);
        assertEq(erc1155YulContract.balanceOf(from, 1337), 30);
    }

    function testEmitTransferSingleAfterSafeTransferFrom() public {
        vm.prank(address(yulDeployer));
        // this tests 2 events.
        // 1 is 'TransferSingle' after mint function
        // 2 is 'TransferSingle' after setApprovalForAll function
        // The ordering matters. It should be followed the order: first, set 'expectEmit' and 'emit' all expected events. Check (A)
        address from = address(0xABCD);
        address to = address(0xFFFF);
        // Testing event emit
        // It needs 2 steps
        // #1 call expectEmit. First 3 'true's are the 'indexed' topics. In Solidity/Yul, Only 3 indexed topics can be added per event
        // (A): setting 2 expectEmits and emits
        vm.expectEmit(true, true, true, true);  // <- the first vm.expectEmit (mint())
        emit TransferSingle(address(yulDeployer), address(yulDeployer), from, 1337, 100);

        vm.expectEmit(true, true, true, true); // <- the second vm.expectEmit (setApprovalForAll())
        emit TransferSingle(address(from), from, to, 1337, 70);

        // (B) this will evaluate the first vm.expectEmit
        erc1155YulContract.mint(from, 1337, 100);

        vm.prank(from);
        erc1155YulContract.setApprovalForAll(address(this), true);
        
        // #2 Then emit event. This is going to be compared with the "real" event. Basically this is an expected event
        // (C) this will evaluate the second vm.expectEmit
        vm.prank(from);
        erc1155YulContract.safeTransferFrom(from, to, 1337, 70);
    }

    function testSafeTransferFromToERC1155Recipient() public {
        ERC1155Recipient to = new ERC1155Recipient();

        address from = address(0xABCD);

        vm.prank(address(yulDeployer));
        erc1155YulContract.mint(from, 1337, 100);

        vm.prank(from);
        erc1155YulContract.setApprovalForAll(address(from), true);

        vm.prank(from);
        erc1155YulContract.safeTransferFrom(from, address(to), 1337, 70);

        assertEq(to.operator(), address(from));
        assertEq(to.from(), from);
        assertEq(to.id(), 1337);
        // // assertBytesEq(to.mintData(), "testing 123"); // TODO: Implement. Update _checkSafeTransfer (bytes area)

        assertEq(erc1155YulContract.balanceOf(address(to), 1337), 70);
        assertEq(erc1155YulContract.balanceOf(from, 1337), 30);
    }

    function testSafeBatchTransferFromToEOA() public {
        address from = address(0xABCD);

        uint256[] memory ids = new uint256[](5);
        ids[0] = 1337;
        ids[1] = 1338;
        ids[2] = 1339;
        ids[3] = 1340;
        ids[4] = 1341;

        uint256[] memory mintAmounts = new uint256[](5);
        mintAmounts[0] = 100;
        mintAmounts[1] = 200;
        mintAmounts[2] = 300;
        mintAmounts[3] = 400;
        mintAmounts[4] = 500;

        uint256[] memory transferAmounts = new uint256[](5);
        transferAmounts[0] = 50;
        transferAmounts[1] = 100;
        transferAmounts[2] = 150;
        transferAmounts[3] = 200;
        transferAmounts[4] = 250;

        vm.prank(address(yulDeployer));
        erc1155YulContract.batchMint(from, ids, mintAmounts);

        vm.prank(from);
        erc1155YulContract.setApprovalForAll(address(from), true);

        vm.prank(from);
        erc1155YulContract.safeBatchTransferFrom(from, address(0xBEEF), ids, transferAmounts);

        assertEq(erc1155YulContract.balanceOf(from, 1337), 50);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1337), 50);

        assertEq(erc1155YulContract.balanceOf(from, 1338), 100);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1338), 100);

        assertEq(erc1155YulContract.balanceOf(from, 1339), 150);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1339), 150);

        assertEq(erc1155YulContract.balanceOf(from, 1340), 200);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1340), 200);

        assertEq(erc1155YulContract.balanceOf(from, 1341), 250);
        assertEq(erc1155YulContract.balanceOf(address(0xBEEF), 1341), 250);
    }

    function testSafeBatchTransferFromToERC1155Recipient() public {
        address from = address(0xABCD);

        ERC1155Recipient to = new ERC1155Recipient();

        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;

        uint256[] memory mintAmounts = new uint256[](3);
        mintAmounts[0] = 10;
        mintAmounts[1] = 20;
        mintAmounts[2] = 20;

        uint256[] memory transferAmounts = new uint256[](3);
        transferAmounts[0] = 4;
        transferAmounts[1] = 5;
        transferAmounts[2] = 5;

        vm.prank(address(yulDeployer));
        erc1155YulContract.batchMint(from, ids, mintAmounts);

        vm.prank(from);
        erc1155YulContract.setApprovalForAll(address(from), true);
        vm.prank(from);
        erc1155YulContract.safeBatchTransferFrom(from, address(to), ids, transferAmounts);

        assertEq(to.batchOperator(), address(from));
        assertEq(to.batchFrom(), from);
        
        uint256[] memory resultIds = to.batchIds();

        assertEq(resultIds[0], ids[0]);
        assertEq(resultIds[1], ids[1]);
        assertEq(resultIds[2], ids[2]);

        uint256[] memory resultAmounts = to.batchAmounts();

        assertEq(resultAmounts[0], transferAmounts[0]);
        assertEq(resultAmounts[1], transferAmounts[1]);
        assertEq(resultAmounts[2], transferAmounts[2]);

        // assertUintArrayEq(to.batchIds(), ids);   // TODO: Find a way to use "DSTestPlus"
        // assertUintArrayEq(to.batchAmounts(), transferAmounts);
        // assertBytesEq(to.batchData(), "testing 123");

        assertEq(erc1155YulContract.balanceOf(from, 1), 6); // 10 - 4
        assertEq(erc1155YulContract.balanceOf(address(to), 1), 4); // 0 + 4

        assertEq(erc1155YulContract.balanceOf(from, 2), 15);    // 20 -5
        assertEq(erc1155YulContract.balanceOf(address(to), 2), 5);  // 0 + 5
        
        assertEq(erc1155YulContract.balanceOf(from, 3), 15);    // 20 -5
        assertEq(erc1155YulContract.balanceOf(address(to), 3), 5);  // 0 + 5
    }

    function testUri() public {
        string memory uri = "ipfs://QmUT14TBgCSYjpXUfVLAsEsehxzZKgw1kiKXHpZ3WjPUqL/";
        string memory result = erc1155YulContract.uri(1);   // whatever pram urin256, it's not used

        assertEq(uri, result);
    }
}
