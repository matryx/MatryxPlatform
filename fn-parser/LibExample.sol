pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

library LibStructs {
    struct StaticData1 {
        address a;
    }

    struct StaticData2 {
        bool b;
    }

    struct StaticData3 {
        bytes32 b;
    }

    struct DynamicData1 {
        bytes b;
    }

    struct DynamicData2 {
        string s;
    }

    struct DynamicData3 {
        int[] i;
    }
}

library LibExample {
    struct StaticData {
        address a;
        bool b;
        int i;
    }

    struct DynamicData {
        string s;
    }

    function empty() public;
    function inject1empty(LibExample.StaticData storage _s) public;

    function inject0dynamic0(address _a, bool _b, int _i) public;
    function inject0dynamic1(address _a, bool[] _b, int _i) public;
    function inject0dynamic2(address _a, bool[] _b, LibStructs.DynamicData3 _d3) public;

    function inject1dynamic0(LibStructs.StaticData1 storage _s1, LibExample.StaticData _s) public;
    function inject1dynamic1(LibStructs.DynamicData1 storage _d1, LibExample.DynamicData _d) public;

    function inject2dynamic0(LibStructs.StaticData1 storage _s1, LibStructs.DynamicData1 storage _d1, LibStructs.StaticData2 _s2, LibExample.StaticData _s) public;
    function inject2dynamic2(LibStructs.StaticData1 storage _s1, LibStructs.DynamicData1 storage _d1, LibStructs.DynamicData2 _d2, LibExample.DynamicData _d) public;
}


library LibTournament {
    struct Data {
        uint256[] u;
    }

    function test(LibTournament.Data storage data, LibTournament.Data _newData) public {
        data.u = _newData.u;
    }
}
