; AS configuration and original binary file to patch over
	CPU 68000
	PADDING OFF
	ORG		$000000
	BINCLUDE	"prg.orig"

ROM_FREE = $07A300

; Port definitions and useful RAM values
InputP1 = $101254
InputP2 = $101256
InputP1_HW = $D00000
InputP2_HW = $D00002
CredCount = $101226
CredPrev = $101228
CoinageCfg = $101299
InputsStart = $1013A8
InputSpecial = $1013A9

; RAM locations already used by the game.
LicenseSkipFlag = $10FC08
StartTransitionCount = $101ECE
ScState = $10240A
ScSquares = $1025B4

; Routines already defined by the game.
DRAW_CREDTEXT_LOC = $04F448
CONTINUE_LOC = $004AB0
STARTFREE_LOC = $0041FA
SPINNING_START_LOC = $00546A
TITLE_INSCOIN_LOC = $00400C
INSCOIN_BOTTOM_LOC = $050564
TITLE_START_INIT_LOC = $0040F0

WAIT_VBL_FUNC = $04F134
WAIT_VBL_LOOP_TOP_LOC = $04F152

PLAY_SOUND_FUNC = $064EBE
STOP_SOUND_FUNC = $065408

; Unused RAM we're going to use to count how long the start button(s) are held
CHARSEL_WDOG = $10FC00
DemoTimer = $100EC6
VBL_HIT_FLAG = $100F04

; The how-to-play screen tends to end on 8A9, but if a player joins on the last
; frame, the counter is reset to 10 seconds, letting it end on BE1.
; $C0D gives a little overhead, and it's a kind of fish, so it was chosen.
DEMO_EXPIRE_NUM = $09E0

; Screen state machine enums.
S_INIT = $0
S_TITLE = $1
S_HISCORE = $2
S_DEMOSTART = $3
S_TITLE_START = $4
S_DEMO = $5
S_INGAME_P2 = $6
S_INGAME_P1 = $7
S_CONTINUE1 = $8
S_LOGO_DARK = $9
S_CONTINUE2 = $A
S_HOWTOPLAY = $B
S_CAVESC = $C
S_ATLUSSC = $D
S_UNK = $E

; Macro for checking free play ================================================
FREEPLAY macro
	move.l	d1, -(sp)
	move.b	(CoinageCfg).l, d1 ; Configuration byte.
	andi.b	#$F0, d1
	cmpi.b	#$30, d1 ; Check if 1P freeplay enabled
	beq	.freeplay_is_enabled
	cmpi.b	#$C0, d1 ; Check if 2P freeplay enabled
	beq	.freeplay_is_enabled
	cmpi.b	#$F0, d1 ; Check if both freeplay enabled
	beq	.freeplay_is_enabled
	bra	+

.freeplay_is_enabled:
	move.l	(sp)+, d1
	ENDM

POST macro
	move.l	(sp)+, d1
	ENDM

; Aesthetic changes ===========================================================

; Set the "3 coins 1 play" text to read FREE PLAY instead
	ORG	$064341
	DC.B	"     FREE PLAY      "
	ORG	$06441D
	DC.B	"     FREE PLAY      "

; Change the version string on the legal notice screen
	ORG	$06401E
;	DC.B	"    1998 4/21  MASTER VER.    \\"
	DC.B	" 2019 8/21  HATSUNE MIKE VER. \\"

; Make game-starting free, and not subtract from the credit count
	ORG	STARTFREE_LOC
	jmp	startfree_hook
post_startfreehook:

; Make in-game join-in / continue free, and not subtract from the credit count
	ORG	CONTINUE_LOC
	jmp	continue_hook
post_continuehook:

; Make the title screen show the spinning "press start" text if on free play
	ORG	TITLE_INSCOIN_LOC
	jmp	title_inscoin_hook
post_inscoinhook:

	; Allow the screen state to proceed even with coins.
	ORG	$4006
	bra	$4012

; Hide "insert credit" sprite on the bottom if in free play
	ORG	INSCOIN_BOTTOM_LOC
	jmp	inscoin_bottom_hook
post_inscoin_bottomhook:

	ORG	DRAW_CREDTEXT_LOC
	jmp	draw_credtext_hook

; Intrusive changes ===========================================================

; Allow title screen to time out and move to next screen like regular title
	ORG	$004166
	jmp	title_start_timeout_hook

; Disable credit management / input servicing in free play
	ORG	$0413A2
	jmp	credit_management_hook

; Don't let game start on first two frames of title screen, so that the B
; button is latched to enable the counter display.
	ORG	$004186
	jmp	start_stopper_hook

; Subroutines stuffed into empty ROM space
; ============================================================================
	ORG	ROM_FREE

start_stopper_hook:
	cmpi.w	#2, 2(a5)
	ble	.getout


.normalcy:
	and.w	(InputsStart).l, d7
	bne	.start_pressed
.getout:
	jmp	$418E

.start_pressed:
	jmp	$4198

title_start_timeout_hook:
	jsr	$579C  ; Title screen BG setup.
	addq.w	#1, 2(a5)

	; Has start already been pressed? (game start transition in progress)
	tst.b	$A(a5)
	beq	.start_not_pressed
	; If so, early exit.
	bra	.not_frame_632

.start_not_pressed:

	cmpi.w	#600, 2(a5)
	bne	.not_frame_600

	; On frame 600 of the screen!
	move.w	#$8000, (ScSquares).l
	jmp	$416C ; Resume normalcy

.not_frame_600:

	cmpi.w	#632, 2(a5)
	bne	.not_frame_632

	clr.w	2(a5)
	move.w	#3, (ScState).l

.not_frame_632:

	jmp	$416C ; Resume normalcy

credit_management_hook:
	FREEPLAY
	move.w	#1, (CredCount).l
	move.w	#1, (CredPrev).l
	rts

/	POST

	move.l	d0, -(sp)
	btst	#5, (InputSpecial).l
	jmp	($0413AC).l

; Don't print the credit count if in free play
draw_credtext_hook:
	FREEPLAY
	rts

/	POST

	move.w	#$1C0, d1
	tst.w	($1025AC).l
	jmp	($04F452).l

; Remove the "insert coin!" scroller in-game if free play is enabled.
inscoin_bottom_hook:
	FREEPLAY

	; Jump past the check to drawing the normal empty bottom bar
	jmp	$50582

/	POST
	cmp.w	(CredCount).l, d4
	jmp	($05056A).l

; Place the spinning "press start" text on the title if in free play instead
; of showing the credit count.
title_inscoin_hook:
	FREEPLAY
	; Call the routine to place the press start animation
	jsr	SPINNING_START_LOC

.no_problem:

	jmp	post_inscoinhook

/	POST

	; Go back to showing the normal "CREDIT n" stuff
	jsr	$04FAAC
	jmp	post_inscoinhook

; Hook in the title screen ($4) code that subtracts credits on start
startfree_hook
	move.w	d6, ($10240C).l
	FREEPLAY
	jmp	$004216

/	POST
	jmp	post_startfreehook

retf:
	rts

; Hook in the code that checks for # credits when player tries to continue
continue_hook:
	FREEPLAY

	jsr	$505BE
	and.w	($1013A8).l, d6
	beq	retf
	; Jump past the part of the routine that checks # credits and subtracts
	; them when the player presses start
	jmp	$004ACE

/	POST
	cmp.w	(a1), d3
	bhi	retf
	jmp	post_continuehook
