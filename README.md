# ERC1155 implementation by Yul + Foundry Forge tests

## Yul tips
* `array`, `bytes` and `string` are treated as following way

```
// if there is uint256[] memory ids = new uint256[](3);
// ids[0] = 1;
// ids[1] = 2;
// ids[2] = 3;
0x0000000000000000000000000000000000000000000000000000000000000020  // 0x00 : where the array starts
0x0000000000000000000000000000000000000000000000000000000000000003  // 0x20 : length of 'ids'
0x0000000000000000000000000000000000000000000000000000000000000001  // 0x40 : ids 1st item
0x0000000000000000000000000000000000000000000000000000000000000002  // 0x80 : ids 2nd item
0x0000000000000000000000000000000000000000000000000000000000000003  // 0xa0 : ids 3rd item
```
* But in case of `bytes` and `string` are slightly different.

```
// if there is bytes memory txt = "abc";
0x0000000000000000000000000000000000000000000000000000000000000020  // 0x00 : where the string starts
0x0000000000000000000000000000000000000000000000000000000000000003  // 0x20 : length of 'txt'
0x6162630000000000000000000000000000000000000000000000000000000001  // 0x40 : there is "abc" which is 61 62 63 and it's left aligned
```

* `mapping` is a function. Check `balanceOf`.



## Repository installation

1. Install Foundry
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Install solidity compiler
https://docs.soliditylang.org/en/latest/installing-solidity.html#installing-the-solidity-compiler

3. Build Yul contracts and check tests pass
```
forge test
```

## Running tests

Run tests (compiles yul then fetch resulting bytecode in test)
```
forge test
```

To see the console logs during tests
```
forge test -vvv
```
