.segment "ZEROPAGE"
nmi_lock:           .res 1  ; set to 1 to prevent nmi reentry
nmi_latch:          .res 1  ; throttles animation speed.


turret_move_cooldown: .res 1 ; this counts down to 0
                             ; when the user is holding down left/right
                             ; this will pace the movements


turret_move: .res 1 ; MOVE_OFF / MOVE_LEFT / MOVE_RIGHT
turret_position: .res 1 ; 0-31



