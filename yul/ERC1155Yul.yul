object "ERC1155Yul but it seems like object does NOT matter. Compile works as long as file name matched with yulDeployer.deployContract()" {
    code {
      // set caller address on storage slot 0 => e.g. owner
      
      
      function uriPos() -> p { p := 3 }
      
      sstore(0, caller())
      
      ////////////////////////////////////////////////////////////////////////////////
      // Set URI
      ////////////////////////////////////////////////////////////////////////////////
      sstore(uriPos(), 0x36)  // 0x36 is length of hex converted (54)
      // "ipfs://QmUT14TBgCSYjpXUfVLAsEsehxzZKgw1kiKXHpZ3WjPUqL/" -> hex
      sstore(add(uriPos(), 1), 0x697066733a2f2f516d555431345442674353596a70585566564c417345736568)
      sstore(add(uriPos(), 2), 0x787a5a4b6777316b694b5848705a33576a5055714c2f00000000000000000000)

      ////////////////////////////////////////////////////////////////////////////////
      // Deploy contract
      ////////////////////////////////////////////////////////////////////////////////
      datacopy(0, dataoffset("Runtime"), datasize("Runtime"))
      return(0, datasize("Runtime"))
    }
    object "Runtime" {
      // Return the calldata
      code {
        ////////////////////////////////////////////////////////////////////////////////
        // Protection against sending Ether
        ////////////////////////////////////////////////////////////////////////////////
        require(iszero(callvalue()))

        ////////////////////////////////////////////////////////////////////////////////
        // Storage layout
        ////////////////////////////////////////////////////////////////////////////////
        function ownerPos() -> p { p := 0 }
        function balancePos() -> p { p := 1 }      
        function approvalPos() -> p { p := 2 }      
        function uriPos() -> p { p := 3 }   
        
        ////////////////////////////////////////////////////////////////////////////////
        // Free Memory Pointer
        ////////////////////////////////////////////////////////////////////////////////
        setMemPtr(0x80) // 0x80 is standard EVM position. It's up to you how to manage memory in 100% Yul.

        // functions to expose. i.e. external functions
        switch getSelector()

        case 0x00fdd58e /* balanceOf(address,uint256) */ {
          let _account := decodeAsAddress(0)
          let _tokenId := decodeAsUint(1)

          returnUint(getBalanceOf(_account, _tokenId))
        }

        case 0xe985e9c5 /* isApprovedForAll(address,address) */ {
          let _owner := decodeAsAddress(0)
          let _operator := decodeAsUint(1)
          let isApproved := _isApprovedForAll(_owner, _operator)

          returnUint(isApproved)
        }

        case 0xa22cb465 /* setApprovalForAll(address,bool) */ {
          let _operator := decodeAsAddress(0)
          let _approved := decodeAsAddress(1)

          setApproval(_operator, _approved)
          emitApprovalForAll(caller(), _operator, _approved)
        }

        case 0x156e29f6 /* mint(address,uint256,uint256) */ {
          require(calledByOwner())

          let _to := decodeAsAddress(0)
          let _tokenId := decodeAsUint(1)
          let _tokenAmount := decodeAsUint(2)
          
          _mint(_to, _tokenId, _tokenAmount)

          _checkSafeTransfer(0x0, _to, _tokenId, _tokenAmount)
          emitTransferSingle(caller(), owner(), _to, _tokenId, _tokenAmount)
        }

        case 0x0ca83480 /* batchMint(address,uint256[],uint256[]) */ {
          require(calledByOwner())

          let _to := decodeAsAddress(0)          

          _mintBatch(_to, 1, 2)
        }

        case 0x0febdd49 /* safeTransferFrom(address,address,uint256,uint256) */ {
          let _from := decodeAsAddress(0)
          let _caller := caller()

          require(or(eq(_caller, _from), _isApprovedForAll(_from, _caller)))

          let _to := decodeAsAddress(1)
          let _id := decodeAsUint(2)
          let _amount := decodeAsUint(3)

          _safeTransferFrom(_from, _to, _id, _amount)
          _checkSafeTransfer(_from, _to, _id, _amount)
          emitTransferSingle(_caller, _from, _to, _id, _amount)
        }

        case 0xfba0ee64 /* safeBatchTransferFrom(address,address,uint256[],uint256[]) */ {
          let _from := decodeAsAddress(0)
          let _to := decodeAsAddress(1)

          _safeBatchTransferFrom(_from, _to, 2, 3)
          _checkSafeBatchTransfer(_from, _to, 2, 3)
        }

        case 0x0e89341c /* uri(uint256 id) */ {
          // note: the id is not used here, see this function's docstring
          let from, to := _getURI()

          return(from, to)
        }

        default /* don't allow fallback or receive */ {
          revert(0, 0)
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Storage access
        ////////////////////////////////////////////////////////////////////////////////
        function owner() -> o {
          o := sload(ownerPos())
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Memory
        ////////////////////////////////////////////////////////////////////////////////
        function getMemPtrPos() -> p { p := 0x60 }
        function getMemPtr() -> p { p := mload(getMemPtrPos()) }
        function setMemPtr(value) { mstore(getMemPtrPos(), value) }
        function increasePointer() {
          let value := safeAdd(getMemPtr(), 0x20) // ++32bytes

          mstore(getMemPtrPos(), value)
        }        

        // arrayOffset: where the array starts
        // arrayLength: length of array
        function copyArrayToMemory(arrayOffset, arrayLength) {
          let range := mul(add(arrayLength, 1), 0x20) // + 1 because it needs to add 'length' position and array items
          let newMemPtr := add(getMemPtr(), range)
          
          calldatacopy(getMemPtr(), arrayOffset, range)
          
          setMemPtr(newMemPtr)
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Call data helpers
        ////////////////////////////////////////////////////////////////////////////////

        // Picks up external function's name (hex)
        function getSelector() -> selector {
          // cut out everything but the first 4 bytes via integer division
          selector := div(calldataload(0), 0x100000000000000000000000000000000000000000000000000000000)
        }

        // Picks up 32 bytes data at 'offset' position from call data
        // Then check if the data has 'address' format which should be 20 bytes.
        function decodeAsAddress(offset) -> v {
          v := decodeAsUint(offset) // picks up 32 bytes from offset position. 
          // then make sure the format is as expected (20 bytes in length): (address is 20 bytes)
          if iszero(iszero(and(v, not(0xffffffffffffffffffffffffffffffffffffffff)))) {
              revert(0, 0)
          }
          // TODO: find a way to test different between above 'if' and require(v)
          // require(v)  // check if v is just 0 which is not valid address. Not sure if it's needed since the above 'if' logic 
        }

        // 'offset' is the n-th param (몇번째)
        // for example, you want to select 3th param like function abc(1, 2, 3) external {...}
        // 0x123456_aa*32_bb*32_cc*32 <- call data
        // When you want to select the 3rd param which is 'cc', then the 'offset' should be 2
        function decodeAsUint(offset) -> v {
          let pos := add(4, mul(offset, 0x20))    // '4' is because to avoid function selector (4 bytes). 
          if lt(calldatasize(), add(pos, 0x20)) { // check if call data isn't long enough compare to the target's offset (ex: searching for 5th param which doesn't exist)
              revert(0, 0)
          }
          v := calldataload(pos)
        }

        // Returns target array item
        // offset: position of data from calldata. e.g. argument index
        // index: index of item should be returned from array
        function decodeAsArrayItem(offset, index) -> v {
          let arrPos := decodeAsUint(offset)   // returns data position of target array
          let targetIndex := add(1, index)  // add 1 in order to avoid returning the length of array // TODO: change as safeAxdd from add
          let arrayItemPos := add(add(4, arrPos), mul(targetIndex, 0x20)) // array data position + item index

          v := calldataload(arrayItemPos)
        }

        // Return target array length
        // offset: position of data from calldata. e.g. argument index
        function decodeAsArrayLength(offset) -> len {
          let arrPos := decodeAsUint(offset)   // returns data position of target array
          let arrayLengthPos := add(4, arrPos) // array data position. e.g. array length data position

          len := calldataload(arrayLengthPos)
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Mapping & Array helpers
        ////////////////////////////////////////////////////////////////////////////////
        function getBalanceSlot(account, tokenId) -> slot {
          mstore(0x00, balancePos()) // use scratch space for hashing // <- TODO: why balance slot is needed for keccak256? [account, tokenId] wouldn't be enough? -> For the safety reason in case there is the same function that uses [account, tokenId]
          mstore(0x20, account)
          mstore(0x40, tokenId) // <- TODO: Ask: normally 0x40 is place for Free Memory Pointer. How can I not use 0x40 in this case?
          slot := keccak256(0x00, 0x60)
        }

        function getApprovalSlot(_owner, _operator) -> slot {
          mstore(0x00, approvalPos())
          mstore(0x20, _owner)
          mstore(0x40, _operator)
          
          slot := keccak256(0x00, 0x60)
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Return data helpers
        ////////////////////////////////////////////////////////////////////////////////
        
        // return value from current memory pointer
        function returnUint(v) {
          let ptr := getMemPtr()

          mstore(ptr, v)
          return(ptr, safeAdd(ptr, 0x20))
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Events
        ////////////////////////////////////////////////////////////////////////////////
        function emitTransferSingle(_operator, _from, _to, _id, _value) {
          // signature is converted of keccak256 from TransferSingle(address,address,address,uint256,uint256)
          // The last (_id, _value) 2 args are "NON-indexed" which means they have to be put in the memory
          let _signature := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62

          mstore(0x00, _id)
          mstore(0x20, _value)

          log4(0x00, 0x40, _signature, _operator, _from, _to)
        }

        function emitTransferBatch(_operator, _from, _to, _idsOffset, _valuesOffset) {
          // TransferBatch(address,address,address,uint256[],uint256[]) is converted into the below signature
          let _signature := 0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb

          // check offset & size of ids
          let idsPos := add(4, decodeAsUint(_idsOffset)) // where to start (ex: 0x60) 
          let idsLen := decodeAsArrayLength(_idsOffset) // length of id, e.g. how many 0x20s
          
          // check offset & size of amounts
          let amountsPos := add(4, decodeAsUint(_valuesOffset)) // where to start (ex: 0x60) 
          let amountsLen := decodeAsArrayLength(_valuesOffset) 

          // This is where unindexed emit data will be stored. i.g. ids & amounts
          let unindexedValueStartPoint := getMemPtr()

          // '2' because there are 2 unindexed data (arrays) to emit 
          // store unindexed data position. e.g. 'ids' array
          mstore(unindexedValueStartPoint, mul(2, 0x20))
          increasePointer() // to store next unindexed data position
          // '3' because 
          // 1. there is offset of id array (0x00)
          // 2. there is offset of amount array (0x20)
          // 3. there is length of id array (0x40)
          // It's to calculate offset of 'amounts' start point
          mstore(add(unindexedValueStartPoint, 0x20), mul(add(idsLen, 3), 0x20))
          increasePointer()

          copyArrayToMemory(idsPos, idsLen)
          copyArrayToMemory(amountsPos, amountsLen)

          // Example of target
          // mstore(unindexedValueStartPoint, 0x0000000000000000000000000000000000000000000000000000000000000040)
          // mstore(add(unindexedValueStartPoint, 0x20), 0x00000000000000000000000000000000000000000000000000000000000000a0)
          // mstore(add(unindexedValueStartPoint, 0x40), 0x0000000000000000000000000000000000000000000000000000000000000002)
          // mstore(add(unindexedValueStartPoint, 0x60), 0x0000000000000000000000000000000000000000000000000000000000000001)
          // mstore(add(unindexedValueStartPoint, 0x80), 0x0000000000000000000000000000000000000000000000000000000000000002)
          // mstore(add(unindexedValueStartPoint, 0xa0), 0x0000000000000000000000000000000000000000000000000000000000000002)
          // mstore(add(unindexedValueStartPoint, 0xc0), 0x0000000000000000000000000000000000000000000000000000000000000064)
          // mstore(add(unindexedValueStartPoint, 0xe0), 0x00000000000000000000000000000000000000000000000000000000000000c8)
          
          // add 2 per each 'len' because: 
          // 1. there are 2 array positions needed for ids on 0x00 and 0x20 on emit data
          // 2. each array length positions needed
          let totalLen := add(mul(add(idsLen, 2), 0x20), mul(add(amountsLen, 2), 0x20))

          log4(unindexedValueStartPoint, totalLen, _signature, _operator, _from, _to)
        }

        function emitApprovalForAll(_owner, _operator, _approved) {
          let _signature := 0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31

          mstore(0x00, _approved)

          log3(0x00, 0x20, _signature, _owner, _operator)
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Core 
        ////////////////////////////////////////////////////////////////////////////////

        function getBalanceOf(account, tokenId) -> bal {
          bal := sload(getBalanceSlot(account, tokenId))
        }

        function _mint(_to, _tokenId, _tokenAmount) {
          let _slot := getBalanceSlot(_to, _tokenId)
          let _oldVal := sload(_slot)
          let _newVal := safeAdd(_oldVal, _tokenAmount)

          sstore(_slot, _newVal)
        }

        function _mintBatch(_to, _tokenIdsOffset, _tokenAmountsOffset) {
          let idsLen := decodeAsArrayLength(_tokenIdsOffset)
          let amountsLen := decodeAsArrayLength(_tokenAmountsOffset)

          require(eq(idsLen, amountsLen))

          for { let i := 0 } lt(i, idsLen) {i := add(i, 1)} {
            let tokenId := decodeAsArrayItem(_tokenIdsOffset, i)
            let tokenAmount := decodeAsArrayItem(_tokenAmountsOffset, i)

            _mint(_to, tokenId, tokenAmount)
          }

          emitTransferBatch(caller(), owner(), _to, _tokenIdsOffset, _tokenAmountsOffset)
        }

        function _safeBatchTransferFrom(_from, _to, _tokenIdsOffset, _tokenAmountsOffset) {
          let idsLen := decodeAsArrayLength(_tokenIdsOffset)
          let amountsLen := decodeAsArrayLength(_tokenAmountsOffset)
          let _caller := caller()

          require(eq(idsLen, amountsLen))
          require(or(eq(_caller, _from), _isApprovedForAll(_from, _caller)))

          for { let i := 0} lt(i, idsLen) { i := add(i, 1) } {
            let tokenId := decodeAsArrayItem(_tokenIdsOffset, i)
            let tokenAmount := decodeAsArrayItem(_tokenAmountsOffset, i)

            _safeTransferFrom(_from, _to, tokenId, tokenAmount)
          }

          //TODO: Implement event emit
        }

        function _isApprovedForAll(_owner, _operator) -> slot {
          slot := sload(getApprovalSlot(_owner, _operator))
        }

        function setApproval(operator, isApproved) {
          let slot := getApprovalSlot(caller(), operator)

          sstore(slot, isApproved)
        }

        function _safeTransferFrom(_from, _to, _id, _amount) {
          let _fromSlot := getBalanceSlot(_from, _id)
          let _toSlot := getBalanceSlot(_to, _id)
          
          // 'from' operation (from - amount)
          let _fromOldVal := sload(_fromSlot)
          let _fromNewVal := safeSub(_fromOldVal, _amount)
          sstore(_fromSlot, _fromNewVal) // set subtracted value
          
          // 'to' operation (to + amount)
          let _toOldVal := sload(_toSlot)
          let _toNewVal := safeAdd(_toOldVal, _amount)
          sstore(_toSlot, _toNewVal) // set added value
        }

        function _getURI() -> startsAt, endsAt {
          startsAt := getMemPtr()
          let uriLength := sload(uriPos())

          mstore(startsAt, 0x20) // <store beginning of the string - pos 0x20 relative in the returndata>

          // then its length
          mstore(safeAdd(startsAt, 0x20), uriLength) // <pointer to beginning><length>
          setMemPtr(safeAdd(startsAt, 0x40))
          
          // load the URI data from storage into memory
          for { let i := 0 } lt(i, uriLength) { i := add(i, 1) }
          {
              let slot_i := safeAdd(uriPos(), add(i, 1))

              // <pointer to beginning><length><first chunk of data><second chunk of data>...
              //                                        ^ we are here in the first iteration
              // load it from our storage trie:
              let chunk_i := sload(slot_i)
              let memorySlot_i := getMemPtr()

              mstore(memorySlot_i, chunk_i) // let's put it into memory
              increasePointer() // ptr++
          }
          endsAt := getMemPtr()
      }


        ////////////////////////////////////////////////////////////////////////////////
        // Security check
        ////////////////////////////////////////////////////////////////////////////////
        
        // TODO: implement the onERC1155Received's last param which is 'bytes data'
        // bytes !== bytes32. Check the below link
        // https://ethereum.stackexchange.com/questions/11770/what-is-the-difference-between-bytes-and-bytes32
        // Since the bytes is an array, implementation of mstore would be different. Probably similar to array?
        function _checkSafeTransfer(_from, _to, _id, _amount) {
          // check if 'to' is just 0s. Equivalent to "to != address(0)"
          // if extcodesize of '_to' is 0, it means it's an account
          // if extcodesize of '_to' is NOT 0, it's a contract thus continue the the below checking process
          // 'leave' is like 'return'
          if eq(extcodesize(_to), 0) { leave }

          // first zero-out return data location in scratch space
          mstore(0x00, 0x00)

          // keccak256 version of onERC1155Received(address,address,uint256,uint256,bytes)
          let onERC1155Received := 0xf23a6e6100000000000000000000000000000000000000000000000000000000  // selector
          let memPtr := getMemPtr()

          // onERC1155Received(address sender, address from, uint256 id, uint256 amount, bytes data)
          mstore(memPtr, onERC1155Received) // selector
          mstore(add(memPtr, 0x04), caller()) // sender (operator)
          mstore(add(memPtr, 0x24), _from)  // from
          mstore(add(memPtr, 0x44), _id)  // id
          mstore(add(memPtr, 0x64), _amount)  // amount
          mstore(add(memPtr, 0x84), 0xa0)  // bytes // 0xa0 because it is the offset of bytes
          mstore(add(memPtr, 0xa4), 0x00)  // bytes // place for length of bytes
          mstore(add(memPtr, 0xc4), 0x00)  // bytes // actual byte code
          
          let success := call(gas(), _to, 0, memPtr, 0xe4, 0x00, 0x20) // 0x120 is because the last param 0x100 + 0x20. 
          // Also the response will be stored in 0x00 in memory
          // TODO: it seems like the response data should contain the selector (0xf23a6e61). Verify if it's true
          require(success)

          let response := decodeAsSelector(mload(0x00)) // it's from call's return data
          let onERC1155ReceivedSelector := decodeAsSelector(onERC1155Received)

          require(eq(response, onERC1155ReceivedSelector))
        }

        function _checkSafeBatchTransfer(_from, _to, _idsOffset, _amountsOffset) {
          // check if 'to' is just 0s. Equivalent to "to != address(0)"
          // if extcodesize of '_to' is 0, it means it's an account
          // if extcodesize of '_to' is NOT 0, it's a contract thus continue the the below checking process
          // 'leave' is like 'return'
          if eq(extcodesize(_to), 0) { leave }

          // first zero-out return data location in scratch space
          mstore(0x00, 0x00)

          // keccak256 version of onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
          let onERC1155BatchReceived := 0xbc197c8100000000000000000000000000000000000000000000000000000000  // selector
          let memPtr := getMemPtr()

          // onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _amounts, bytes calldata _data)
          mstore(memPtr, onERC1155BatchReceived)  // selector
          mstore(add(memPtr, 0x04), caller())     // sender (operator)
          mstore(add(memPtr, 0x24), _from)        // from

          // set in memory arrays (ids, amounts, bytes)
          // a new function is created because not more than 10 variables allowed in one function in Yul
          let totalLen := _setSafeBatchTransferArraysInMemory(memPtr, _idsOffset, _amountsOffset)

          let success := call(gas(), _to, 0, memPtr, totalLen, 0x00, 0x20)

          // Also the response will be stored in 0x00 in memory
          // TODO: it seems like the response data should contain the selector (0xf23a6e61). Verify if it's true
          require(success)
          
          let response := decodeAsSelector(mload(0x00)) // it's from call's return data
          let onERC1155BatchReceivedSelector := decodeAsSelector(onERC1155BatchReceived)

          require(eq(response, onERC1155BatchReceivedSelector))

          //////////////// 
          // EXAMPLE: It shows manaual way of stacking memory. Check how arrays are made (ids, amounts, bytes)
          ////////////////

          // let onERC1155BatchReceived := 0xbc197c8100000000000000000000000000000000000000000000000000000000  // selector
          // let memPtr := getMemPtr()

          // mstore(memPtr, onERC1155BatchReceived) // selector

          // Memory structure rule
          // 1. the memory order is the same as order of params
          // 2. but if there is arrays, it should point the position of each array first (see idsPos, amountsPos, bytesPos)
          // 3. 'bytes' is treated same as array

          // <--  Working example
          // let idsPos := 0xa0  // <- note that it's 0xa0 and not 0x04. It's because the selector (first 4 bytes) won't be taken into account.
          // let amountsPos := 0x120
          // let bytesPos := 0x1a0

          // mstore(add(memPtr, 0x04), caller()) // sender (operator)
          // mstore(add(memPtr, 0x24), _from)  // from

          // mstore(add(memPtr, 0x44), idsPos) // pos ids array
          // mstore(add(memPtr, 0x64), amountsPos) // pos amounts array
          // mstore(add(memPtr, 0x84), bytesPos) // pos bytes array

          // mstore(add(memPtr, 0xa4), 0x0000000000000000000000000000000000000000000000000000000000000003) // len ids array
          // mstore(add(memPtr, 0xc4), 0x0000000000000000000000000000000000000000000000000000000000000001) // id item 1
          // mstore(add(memPtr, 0xe4), 0x0000000000000000000000000000000000000000000000000000000000000002) // id item 2
          // mstore(add(memPtr, 0x104), 0x0000000000000000000000000000000000000000000000000000000000000002) // id item 3
          
          // mstore(add(memPtr, 0x124), 0x0000000000000000000000000000000000000000000000000000000000000003) // len amounts array
          // mstore(add(memPtr, 0x144), 0x0000000000000000000000000000000000000000000000000000000000000004) // amounts item 1
          // mstore(add(memPtr, 0x164), 0x0000000000000000000000000000000000000000000000000000000000000005) // amounts item 2
          // mstore(add(memPtr, 0x184), 0x0000000000000000000000000000000000000000000000000000000000000005) // amounts item 3
          
          // mstore(add(memPtr, 0x1a4), add(memPtr, 0x1c4)) // bytes len

          // let success := call(gas(), _to, 0, memPtr, add(memPtr, 0x1c4), 0x00, 0x20)
          // // End Working example -->
          // require(success)

          // let response := decodeAsSelector(mload(0x00)) // it's from call's return data
          // let onERC1155BatchReceivedSelector := decodeAsSelector(onERC1155BatchReceived)

          // require(eq(response, onERC1155BatchReceivedSelector))
        }

        // This function is created due to this error <StackTooDeepError>
        // Apparently in yul, you can't create variables more than 10 in a single function
        function _setSafeBatchTransferArraysInMemory(_memPtr, _idsOffset, _amountsOffset) -> totalLen {
          let idsPosFromParam := add(4, decodeAsUint(_idsOffset)) // where to start (ex: 0x60) 
          let idsLen := decodeAsArrayLength(_idsOffset) // length of id, e.g. how many 0x20s
          let amountsPosFromParam := add(4, decodeAsUint(_amountsOffset)) // where to start (ex: 0x60) 
          let amountsLen := decodeAsArrayLength(_amountsOffset) // length of id, e.g. how many 0x20s

          // here store ids array starting point
          // ids position = memPtr + ((caller + _from + idsPos + amountsPos + bytePos) * 0x20) = 0xa0
          let idsStartingOffset := 0xa0 // Note: it's NOT adding '_memPtr' because it's the offset of param that will return to a contract (ERC1155Recipient contract). When the contract recieves the param, the 0x00 would be 'form' address. It doesn't have to start from 0x80.
          mstore(add(_memPtr, 0x44), idsStartingOffset) // +4 is for selector (4 bytes)

          // amounts position
          let idsTotalSpace := mul(add(idsLen, 1), 0x20) // space taken in memory of ids length (that's why +1) + ids items 
          let amountsStartingOffset := add(idsTotalSpace, idsStartingOffset) // memPtr + idsTotalSpace + idsStartingOffset = amounts starting point
          mstore(add(_memPtr, 0x64), amountsStartingOffset)

          // bytes position
          let amountsTotalSpace := mul(add(amountsLen, 1), 0x20) // space taken in memory of amounts length + amounts items 
          let bytesStartingOffset := add(amountsTotalSpace, amountsStartingOffset)
          mstore(add(_memPtr, 0x84), bytesStartingOffset)

          // update how much memory is used so far
          // (sender + from + idsPos + amountsPos + bytesPos) => 5*0x20 == memPtr + 0xa0 + selector (4 bytes)
          setMemPtr(add(_memPtr, 0xa4))

          copyArrayToMemory(idsPosFromParam, idsLen) // ids
          copyArrayToMemory(amountsPosFromParam, amountsLen) // amounts

          // bytes
          // mstore(currentMemPtr, add(currentMemPtr, 0x20))
          // TODO: implement proper bytes data handling

          totalLen := add(getMemPtr(), 0x20)
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Helpers
        ////////////////////////////////////////////////////////////////////////////////

        function require(condition) {
          if iszero(condition) {
            revert(0, 0)
          }
        }
        
        // whether a caller is the owner or not
        function calledByOwner() -> cbo {
          cbo := eq(owner(), caller())
        }
        
        // overflow checking
        function safeAdd(a, b) -> r {
          r := add(a, b)
          
          if or(lt(r, a), lt(r, b)) {
             revert(0, 0) 
          }
        }

        // underflow checking
        function safeSub(a, b) -> r {
          r := sub(a, b)
          
          if gt(r, a) { 
            revert(0, 0) 
          }
        }

        function decodeAsSelector(value) -> selector {
          selector := div(value, 0x100000000000000000000000000000000000000000000000000000000)
        }
      }
    }
  }