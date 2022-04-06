// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

/// @notice Nascent, ugly, gas inefficient (but improving!) Merkle proof generator and verifier
/// @author dmfxyz
/// @dev Note that all each piece of data must be no more than 32 bytes.
contract Merkle {
    /***************
    * CONSTRUCTOR *
    ***************/
    constructor() {}

    /********************
    * HASING FUNCTIONS *
    ********************/

    function hashLeafPairs(bytes32 left, bytes32 right) public pure returns (bytes32 _hash) {
        // saves a few gas lol
        assembly {
            mstore(0x0, xor(left,right))
           _hash := keccak256(0x0, 0x20)
        }
        //return keccak256(abi.encode(left ^ right));
    }


    function hashLevel(bytes32[] memory data) public pure returns (bytes32[] memory) {
        require(data.length > 0, "cannot hash empty level");
        bytes32[] memory result;

        if (data.length % 2 == 1){
            result = new bytes32[](data.length / 2 + 1);
            result[result.length - 1] = hashLeafPairs(data[data.length - 1], bytes32(0));
        } else {
            result = new bytes32[](data.length / 2);
        }

        // pos is upper bounded by data.length / 2, so safe even if array is at max size
        unchecked {
            uint256 pos = 0;
            for (uint256 i = 0; i < data.length-1; i+=2){
                result[pos] = hashLeafPairs(data[i], data[i+1]);
                ++pos;
            }
        }
        return result;
    }

    /********************
    * PROOF GENERATION *
    ********************/

    function getRoot(bytes32[] memory data) public pure returns (bytes32) {
        while(data.length > 1) {
            data = hashLevel(data);
        }
        return data[0];
    }

    function getProof(bytes32[] memory data, uint256 node) public pure returns (bytes32[] memory) {
        // The size of the proof is equal to the ceiling of log2(numLeaves) 
        uint256 proofsize = log2ceil_naive(data.length);
        bytes32[] memory result = new bytes32[](proofsize);
        uint256 pos = 0;

        while(data.length > 1) {
            if(node % 2 == 1) {
                result[pos] = data[node - 1];
            } 
            else if (node + 1 == data.length) {
                result[pos] = bytes32(0);  
            } 
            else {
                result[pos] = data[node + 1];
            }
            unchecked {
                ++pos;
                node = node / 2;
            }
            
            data = hashLevel(data);
        }
        return result;
    }

    /**********************
    * PROOF VERIFICATION *
    **********************/

    function verifyProof(bytes32 root, bytes32[] memory proof, bytes32 valueToProve) public pure returns (bool) {
        // proof length must be less than max array size
        unchecked {
            for(uint i = 0; i < proof.length; ++i){
                valueToProve = hashLeafPairs(valueToProve, proof[i]);
            }
        }
        return root == valueToProve;
    }

    /******************
    * MATH "LIBRARY" *
    ******************/
    
    /// @dev  Note that x is assumed > 0
    function log2ceil_naive(uint256 x) public pure returns (uint256) {
        uint256 ceil = 0;
        uint256 lsb = (~x + 1) & x;
        bool powerOf2 = x == lsb;
        
        // if x == type(uint256).max, than ceil is capped at 256
        // if x == 0, then (~x + 1) & x == 0, so ceil won't underflow
        unchecked {
            while( x > 0) {
                x >>= 1;
                ceil++;
            }
            if (powerOf2) {
                ceil--;
            }
        }
        return ceil;
    }

    /// Original bitmagic adapted from https://github.com/paulrberg/prb-math/blob/main/contracts/PRBMath.sol
    /// @dev Note that x assumed > 1
    function log2ceil_bitmagic(uint256 x) public pure returns (uint256){
        if (x <= 1) {
            return 0;
        }
        uint256 msb;
        uint256 _x = x;
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            msb += 1;
        }

        uint256 lsb = (~_x + 1) & _x;
        if ((lsb == _x) && (msb > 0)) {
            return msb;
        } else {
            return msb + 1;
        }
    }
}
