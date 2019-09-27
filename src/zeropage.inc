.segment "ZEROPAGE"


nmi_lock:           .res 1  ; set to 1 to prevent nmi reentry
nmi_latch:          .res 1  ; throttles animation speed.
