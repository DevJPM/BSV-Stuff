package PropertyBasedTesting;

import BlueCheck :: *;

typedef Int#(4) T;

module [BlueCheck] mkArithSpec(Empty);

    function Bool addComm(T l, T r) = 
        l + r == r + l;

    function Bool addAssoc(T l, T m, T r) =
        (l + m) + r == l + (m + r);

    function Bool subInv(T l) =
        l - l == 0;

    function Bool mulComm(T l, T r) =
        l * r == r * l;
    
    function Bool mulAssoc(T l, T m, T r) =
        l*(m*r) == (l*m)*r;

    function Bool mulDist(T l, T m, T r) = 
        l*(m+r) == l*m + l*r;

    function Bool divInv(T l) =
        l / l == 1;

    prop("addComm",addComm);
    prop("addAssoc",addAssoc);
    prop("subInv",subInv);
    prop("mulComm",mulComm);
    prop("mulAssoc",mulAssoc);
    prop("mulDist",mulDist);
    prop("divInv",divInv);
endmodule

(*synthesize*)
module [Module] mkArithChecker(Empty);
    blueCheck(mkArithSpec);
endmodule

endpackage