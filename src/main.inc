init:
  jsr load_palette
  jsr init_bg
	jsr init_reticle
  jsr init_bullets
  jsr enable_rendering
  jsr init_turret
  jsr init_scroll

forever:
  jsr read_controller

  ; wait for nmi to complete a cycle
  ; the NMI will increment nmi_latch when it completes
  ; so don't do anything until we've rendered a frame
  :
  lda nmi_latch
  cmp #0
  beq :-

  jmp forever

init_scroll:
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  rts

start_sprite_dma:
	lda #$00
  sta OAMADDR  ; set the low byte (00) of the RAM address
  lda #$02
  sta OAMDMA  ; set the high byte (02) of the RAM address, start the transfer

  rts

init_turret:
  lda #MOVE_OFF
  sta turret_move

  lda #15
  sta turret_position

  rts

init_reticle:
  jsr start_sprite_dma

  ; create the reticle sprite
  lda #15 ; 2 rows down
  sta $0200 ; write y
  lda #RETICLE_SPRITE_INDEX
  sta $0201 ; write tile index
  lda #%00000000
  sta $0202 ; write attributes
  lda #64
  sta $0203 ; write x

	rts

init_bullets:
  jsr start_sprite_dma

  lda #15 ; a couple rows down
  sta $0204 ; y coord
  lda #BULLET_SPRITE_INDEX
  sta $0205 ; tile index
  lda #%00000000
  sta $0206 ; attributes
  lda #64
  sta $0207 ; x coord

  lda #20; a couple rows down
  sta $0208 ; y coord
  lda #BULLET_SPRITE_INDEX
  sta $0209 ; tile index
  lda #%00000000
  sta $020a ; attributes
  lda #64
  sta $020b ; x coord

  lda #30 ; a couple rows down
  sta $020c ; y coord
  lda #BULLET_SPRITE_INDEX
  sta $020d ; tile index
  lda #%00000000
  sta $020e ; attributes
  lda #64
  sta $020f ; x coord

  ; set up default bullet settings
  lda #08 ; angle 8
  sta bullet_states + 1
  lda #%10000000 ; live bullet at start of animation
  sta bullet_states

  lda #00 ; angle 0
  sta bullet_states + 3
  lda #%10000000 ; live bullet at start of animation
  sta bullet_states + 2

  lda #18 ; angle 18
  sta bullet_states + 5
  lda #%10000000 ; live bullet at start of animation
  sta bullet_states + 4

  rts

read_controller:
  lda #$01
  sta CTRL_LATCH
  lda #$00
  sta CTRL_LATCH

  lda CTRL_READ1 ; a
  lda CTRL_READ1 ; b
  lda CTRL_READ1 ; select
  lda CTRL_READ1 ; start
  lda CTRL_READ1 ; up
  lda CTRL_READ1 ; down
  
  lda CTRL_READ1 ; left
  and #%00000001 ; check if it's held
  beq @read_right ; if not, then skip to checking right
  
  ; now we want to set the direction being held to left
  ; but before we do this, we want to check if it's new
  ; if it was not already moving left, then
  ; set the current move direction to left,
  ; move the turret position left one notch
  ; reset the move cooldown

  ; check the current movement setting
  ; if we're already set to LEFT then we are done here
  lda turret_move
  cmp #MOVE_LEFT
  beq @done

  ; reset the cooldown
  lda #0
  sta turret_move_cooldown

  ; set to move direction to left
  lda #MOVE_LEFT
  sta turret_move

  jmp @done

  @read_right:
    lda CTRL_READ1 ; right
    and #%00000001
    beq @unset_move ; neither right nor left is pressed, so set it to OFF

    ; check if the move is changing setting
    lda turret_move
    cmp #MOVE_RIGHT
    beq @done ; if it's not changing, then done

    ; it is changing, so reset cooldown and adjust position
    lda #0
    sta turret_move_cooldown

    lda #MOVE_RIGHT
    sta turret_move

    jmp @done

  @unset_move:
    ; nothing is being held, set MOVE_OFF
    lda #MOVE_OFF
    sta turret_move

  @done:
    rts

move_turret:
  ; check the cooldown state
  ; if we have not hit zero, then move to done
  ; where we dec the cooldown and return
  lda turret_move_cooldown
  cmp #0
  bne @done

  ; cooldown hit zero. reset cooldown
  lda #TURRET_MOVE_COOLDOWN_RATE
  sta turret_move_cooldown
  
  ; now update the turret_position
  ; based on the direction that we should be moving

  ; check which way we're moving and adjust the position
  ; if MOVE_OFF, then just return
  lda turret_move
  cmp #MOVE_OFF
  beq @return

  ; check if we are moving left
  cmp #MOVE_LEFT
  bne @move_right

  ; move it left
  ; but not past the minimum position
  lda turret_position
  cmp #TURRET_MIN_POSITION
  beq @done

  dec turret_position
  jmp @done

  @move_right:
    lda turret_position
    cmp #TURRET_MAX_POSITION
    beq @done

    inc turret_position

  @done:
    lda turret_move
    cmp #MOVE_OFF
    beq @return

    dec turret_move_cooldown

  @return:
    rts

update_reticle:
	; read the current turret position
	; load the x/y of where the reticle should be
	; move the reticle sprite to there.

  lda turret_position
  tax
  lda turret_reticle_x, x
  sta $0203

  lda turret_reticle_y, x
  sta $0200
	
	rts

update_bullets:
  ; iterate over the bullet states
  ; move each bullet if it's alive

  ldx #0
  @bullet_state_loop:
    lda bullet_states, x
    and %10000000
    bne @update_bullet_state

    ; handle skipping this one
    inx ; skip the angle
    jmp @end_of_loop

  @update_bullet_state:
    ; a contains our bullet state
    ; read off the current animation frame number
    and #%00001111
    sta current_bullet_frame ; cache this
    inc current_bullet_frame ; increment

    ; check if we've overflowed
    lda current_bullet_frame
    cmp #%00010000
    bcc @skip_reset_bullet_frame ; branch if we haven't overflowed

      ; we overflowed, so reset and store
      lda #%00000000
      sta current_bullet_frame

  @skip_reset_bullet_frame:

    ; read angle
    inx
    lda bullet_states, x
    sta current_bullet_angle ; cache

    ; move cursor to the correct angle and frame, then increment by one
    ; then we can read the deltas

    ; now to figure out the delta
    ; set y to the offset of the angle
    ldy #0
    @move_anim_frame_cursor_loop:
      ; check if y is equal to our angle
      cpy current_bullet_angle
      beq :+

      ; add 8 to y
      tya
      adc 8
      tay

      jmp @move_anim_frame_cursor_loop

    @get_next_delta:
      ; y is now equal to how many offsets from shot_anim_frames we have to go
      ; we want to add n to y where n is the current frame
      tya
      adc current_bullet_angle
      tay

      ; now y is the offset in the angles we want
      lda shot_anim_frames, y
      sta current_bullet_angle ; store this value in our cache
                               ; we don't need angles anymore, so reuse

      ; now we read out the deltas and apply it to our bullet

  @end_of_loop:
    cpx #LAST_BULLET_STATE_INDEX
    beq @end ; we are done with the loop

    inx ; increment
    jmp @bullet_state_loop ; next iteration

  @end:
    rts

update_debug_cell:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$21
  sta PPUADDR

  lda turret_move
  sta PPUDATA

  lda turret_position
  sta PPUDATA

  jsr init_scroll

  rts

load_palette:
  lda PPUSTATUS ; read PPU status to reset the high/low latch to high
  lda #$3F
  sta PPUADDR  ; write the high byte of $3F10 address
  lda #$10
  sta PPUADDR    ; write the low byte of $3F10 address

  ldx #$00                ; start out at 0
:
  lda palette_data, x      ; load data from address (PaletteData + the value in x)
                          ; 1st time through loop it will load PaletteData+0
                          ; 2nd time through loop it will load PaletteData+1
                          ; 3rd time through loop it will load PaletteData+2
                          ; etc
  sta PPUDATA               ; write to PPU
  inx                     ; X = X + 1
  cpx #$20                ; Compare X to hex $20, decimal 32
  bne :-  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                          ; if compare was equal to 32, keep going down
  rts

init_bg:
  lda PPUSTATUS
  lda #$20
  sta PPUADDR
  lda #$00
  sta PPUADDR

  ldy #$00
  @bg_chunk:
    ldx #$00
    lda #40 ; the bg tile
  @bg_chunk_loop:
    sta PPUDATA
    inx
    cpx #$00
    bne @bg_chunk_loop

    iny
    cpy #$04
    bne @bg_chunk

  rts
