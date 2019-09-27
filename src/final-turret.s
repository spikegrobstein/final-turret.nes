;
; iNES header
;

; constants
OFFSCREEN     = $ef ; offscreen Y coordinate

; convenience constants
WIDTH_TILES = 32
HEIGHT_TILES = 30

; PPU addresses
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014

; Nametable Addresses
NAMETABLE1 = $2000
NAMETABLE2 = $2400

.segment "HEADER"

INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 1 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID
.byte $02 ; 16k PRG bank count
.byte $01 ; 8k CHR bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding

.include "tiles.inc"

; vectors placed at top 6 bytes of memory area
;

.segment "VECTORS"
.word nmi
.word reset
.word irq

.include "zeropage.inc"

.segment "BSS"
; nmt_update: .res 256 ; nametable update entry buffer for PPU update
; palette:    .res 32  ; palette buffer for PPU update

.segment "OAM"
oam: .res 256        ; sprite OAM data to be uploaded by DMA

.include "rodata.inc"
;
; reset routine
;

.segment "CODE"
reset:
  sei       ; disable IRQs
  cld       ; disable decimal mode
  ldx #$40
  stx $4017 ; disable APU frame IRQ
  ldx #$FF
  txs       ;set up stack
  inx       ;now X = 0 (255 + 1). we're gonna write $00 to several memory addresses
  stx PPUCTRL ; disable NMI
  stx PPUMASK ; disable rendering
  stx $4010 ; disable DMC IRQs

  jsr vblankwait

  ldx #$00 ; init x
: ; loop over and reset memory
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne :-

  ; place all sprites offscreen at Y=255
  lda #255
  ldx #0
:
  sta oam, X
  inx
  inx
  inx
  inx
  bne :-

  jsr vblankwait

  ; ok, we can start the program
  jmp init

vblankwait:
  bit PPUSTATUS
  bpl vblankwait
  rts

.include "main.inc"

irq:
  rti

nmi:
  ; save registers
	pha
	txa
	pha
	tya
	pha

  ; prevent nmi reentry
  lda nmi_lock
  bne @nmi_bail ; bail if we're in nmi still

  inc nmi_lock

  ; why am I doing this again?
  lda #$00
  sta OAMADDR ; set low byte of ram address
  lda #$02
  sta OAMDMA ; set the high byte of ram address

  ; code

@nmi_end:
  ; jsr enable_rendering
  dec nmi_lock ; free up nmi lock

@nmi_bail:
  ; restore registers and stuff
	pla
	tay
	pla
	tax
	pla

  inc nmi_latch

  rti

