.segment "ZEROPAGE"
nmi_lock:           .res 1  ; set to 1 to prevent nmi reentry
nmi_latch:          .res 1  ; throttles animation speed.


turret_move_cooldown: .res 1 ; this counts down to 0
                             ; when the user is holding down left/right
                             ; this will pace the movements


turret_move: .res 1 ; MOVE_OFF / MOVE_LEFT / MOVE_RIGHT
turret_position: .res 1 ; 0-31

; for bullets in-flight, we need to store some info about them
; the current frame of trajectory (counter from 0-7)

bullet_states:
  .res 2 ; first byte is angle, second byte is state
         ; state is %X___DDDD
         ; X: alive or not
         ; D: delta frame
         ; _: unused (so far)
