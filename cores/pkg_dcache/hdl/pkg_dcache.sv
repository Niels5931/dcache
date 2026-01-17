
package pkg_dcache;
endpackage : pkg_dcache

`define DCACHE_TAG_T(TAG_WIDTH) \
  struct packed { \
    logic                   valid; \
    logic [TAG_WIDTH-1:0]   tag; \
  }
