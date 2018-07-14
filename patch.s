; AS configuration and original binary file to patch over
	CPU 68000
	PADDING OFF
	ORG		$000000
	BINCLUDE	"prg.orig"

; Port definitions and useful RAM values
INPUT_P1 = $101254
INPUT_P2 = $101256
INPUT_P1_HW = $D00000
INPUT_P2_HW = $D00002
CRED_COUNT = $101226
CRED_PREV = $101228
COINAGE_CFG = $101299



; Some locations of interest
FREE_REGION = $07A300
DRAW_CREDTEXT_LOC = $04F448
CONTINUE_LOC = $004AB0
STARTFREE_LOC = $0041FA
SPINNING_START_LOC = $00546A
TITLE_INSCOIN_LOC = $00400C
INSCOIN_BOTTOM_LOC = $050564
TITLE_START_INIT_LOC = $0040F0
WAIT_VBL_LOC = $04F152

PLAY_SOUND_LOC = $064EBE ; TODO: Adjust for J
STOP_SOUND_LOC = $065408 ; TODO: Adjust for J


; Unused RAM we're going to use to count how long the start button(s) are held
CHARSEL_WDOG = $10FC00
RESET_TIMER = $10FC02
LICENSE_SKIP_MARKER = $10FC08
START_TRANSITION_COUNT = $101ECE
DEMO_TIMER = $100EC6
VBL_HIT_FLAG = $100F04

; The how-to-play screen tends to end on 8A9, but if a player joins on the last
; frame, the counter is reset to 10 seconds, letting it end on BE1.
; $C0D gives a little overhead, and it's a kind of fish, so it was chosen.
CHARSEL_WDOG_MAX = $C0D
RESET_TIMER_MAX = 180
DEMO_EXPIRE_NUM = $09E0

; Screen state machine
SC_STATE = $10240A
TRANSITION_LOC = $1025B4

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

; Set the "3 coins 1 play" text to read FREE PLAY instead
; ============================================================================
	ORG	$064341
	DC.B	"     FREE PLAY      "
	ORG	$06441D
	DC.B	"     FREE PLAY      "

; Change the version string on the legal notice screen
; ============================================================================
	ORG	$06401E
;	DC.B	"    1998 4/21  MASTER VER.    \\"
	DC.B	"      180714 MOFFITT VER.     \\"

; Make pressing a start button during attract go to the game start screen
; ============================================================================
	ORG	DRAW_CREDTEXT_LOC
	; Replacement hook
	jmp start_hook		; move.w #$1C0, d1
post_starthook:
	nop			; tst.w ($1025AC).l
	nop

; Make game-starting free, and not subtract from the credit count
;=============================================================================
	ORG	STARTFREE_LOC
	jmp	startfree_hook
post_startfreehook:

; Make in-game join-in / continue free, and not subtract from the credit count
; ============================================================================
	ORG	CONTINUE_LOC
	jmp	continue_hook
post_continuehook:

; Make the title screen show the spinning "press start" text if on free play
; ============================================================================
	ORG	TITLE_INSCOIN_LOC
	jmp	title_inscoin_hook
post_inscoinhook:

; Hide "insert credit" sprite on the bottom if in free play
; ============================================================================
	ORG	INSCOIN_BOTTOM_LOC
	jmp	inscoin_bottom_hook
post_inscoin_bottomhook:

; If start isn't held on the "press-start" title screen, revert to normal
; ============================================================================
	ORG	TITLE_START_INIT_LOC
	jmp	title_start_exit_hook
post_title_start_exithook:

; Patch the wait-for-vblank routine to do the holding-start check for reset
; ============================================================================
	ORG	WAIT_VBL_LOC
	jmp	wait_vbl_hook
	nop
	nop
	nop
	nop
post_wait_vblhook:

; Subroutines stuffed into empty ROM space
; ============================================================================
	ORG	FREE_REGION

wait_vbl_hook:
.wait_for_vbl:
; Now do the normal VBL wait bit
	addq.b #1, ($1011F9).l
	tst.w	(VBL_HIT_FLAG).l
	beq.s	.wait_for_vbl

	move.l	d1, -(sp)
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en
	bra	.end

.freeplay_en:

.user_reset:
	; P1 and P2 buttons both held?
	; Read P1 and P2 inputs together
	move.w	(INPUT_P1).l, d1
	or.w	(INPUT_P2).l, d1
	andi.b	#$80, d1
	beq	.no_user_reset

	; Buttons held; increment reset timer
	addi	#1, (RESET_TIMER).l
	cmpi.w	#RESET_TIMER_MAX, (RESET_TIMER).l
	bcs	.charsel_watchdog

	; Buttons held for (charsel_wdog_max), do a hot crash
	clr.w	(RESET_TIMER).l
	jmp	reset

.no_user_reset:
	clr.w	(RESET_TIMER).l

.charsel_watchdog:
	; Are we in how to play?
	move.w	(SC_STATE).l, d1
	cmpi.w	#S_HOWTOPLAY, d1
	bne	.no_wdog_reset

	; KIND OF GROSS HACK ALERT
	; There is a bug that is extremely hard to reproduce. Only twice I
	; have hit start, gotten through character select, the transition
	; animation begins, and... the screen stays covered in the transition
	; squares indefinitely. The BGM is still of the how to play / char
	; select screen, so for some reason the transition to state $5 is
	; not made. This is a soft watchdog to ensure that the character
	; select screen is stuck for too long. This is for if the game is run
	; in a semi-public setting.
	;
	; This hack is in the wait for vblank routine as the same mechanism is
	; used to allow you to hold P1 & P2 start to reset the machine.
	; Increment the counter
	addi	#1, (CHARSEL_WDOG).l
	cmpi.w	#CHARSEL_WDOG_MAX, (CHARSEL_WDOG).l
	bcs	.end

	; We have been on this screen longer than we should.
	; Crash the game into a reset
	clr.w	(CHARSEL_WDOG).l
	jmp	reset

.no_wdog_reset:
	clr.w	(CHARSEL_WDOG).l

.end:
	move.l	(sp)+, d1
	jmp	post_wait_vblhook


; Hook in
; Hook during title ($4)'s init that'll revert to the normal title ($1) if the
; player isn't holding start.
; This is to eliminate situations where start is held for exactly one frame,
; so we aren't stuck on the title $4 forever.
; ============================================================================
title_start_exit_hook:
	move.l	d1, -(sp)
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en

	; Free play isn't enabled; do the normal stuff and get out
	move.l	(sp)+, d1
	tst.b	($102409).l
	jmp	post_title_start_exithook

.freeplay_en:
	move.l	(sp)+, d1
	; If screen transition has started, don't bother with the rest of this
	tst.b	($100ECC).l
	beq	.continue
	jmp	post_title_start_exithook

.continue
	; Read P1 and P2 inputs together
	move.w	(INPUT_P1).l, d1
	or.w	INPUT_P2, d1
	andi.b	#$80, d1

	; If start is not held, redirect to regular title
	beq	.finish

	; Else, continue like normal
	tst.b	($102409).l
	jmp post_title_start_exithook
.finish:

	; Change the state to the title screen
	clr.w	($100EC4).l
	move.w	#S_TITLE, (SC_STATE).l
	jmp	post_title_start_exithook

; Remove the "insert coin!" scroller in-game if free play is enabled.
; ============================================================================
inscoin_bottom_hook:
	move.l	d1, -(sp)
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en

	; Free play is not enabled; resume normal logic
	move.l	(sp)+, d1
	cmp.w	(CRED_COUNT).l, d4
	jmp	post_inscoin_bottomhook

.freeplay_en:
	; Jump past the check to drawing the normal empty bottom bar
	move.l	(sp)+, d1
	jmp	$50582

; Place the spinning "press start" text on the title if in free play instead
; of showing the credit count.
; ============================================================================
title_inscoin_hook:
	
	move.l	d1, -(sp)
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en

	; Go back to showing the normal "CREDIT n" stuff
	jsr	$04FAAC
	bra	.post

.freeplay_en:
	; Call the routine to place the press start animation
	jsr	SPINNING_START_LOC

.post:
	move.l	(sp)+, d1
	; Jump past the point of drawing the credit message on screen
	jmp	post_inscoinhook

; Hook in the title screen ($4) code that subtracts credits on start
; ============================================================================
startfree_hook
	move.w	d6, ($10240C).l
	move.l	d1, -(sp)
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en

	move.l	(sp)+, d1
	jmp	post_startfreehook

.freeplay_en:
	move.l	(sp)+, d1
	; Skip right past the credit subtraction
	jmp	$004216

; Hook in the code that checks for # credits when player tries to continue
; ============================================================================
continue_hook:
	move.l	d1, -(sp)
	; Is free play enabled?
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en

	; if not, reproduce the original credit check sequence and get back
	move.l	(sp)+, d1
	cmp.w	(a1), d3
	bhi.w	.locret
	jmp	post_continuehook

.freeplay_en
	move.l	(sp)+, d1
	; Show "press start" graphic(s)
	jsr	$505BE
	and.w	($1013A8).l, d6
	beq.w	.locret
	; Jump past the part of the routine that checks # credits and subtracts
	; them when the player presses start
	jmp	$004ACE
.locret: 
	rts

; Hook placed in "drawing credit" routine that pushes the screen state machine
; to $4 (title, waiting for start button) if free play is on, and start is hit
; ============================================================================
start_hook:
	; Is free play enabled?
	move.b	(COINAGE_CFG).l, d1
	andi.b	#$F0, d1
	cmpi.b	#$30, d1			; Check if 1P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$C0, d1			; Check if 2P freeplay enabled
	beq	.freeplay_en
	cmpi.b	#$F0, d1			; Check if both freeplay enabled
	beq	.freeplay_en

	; Not in free play; do normal credit drawing operations and resume
	; from where the original code did.
	move.w	#$1C0, d1
	tst.w	($1025AC).l
	jmp	post_starthook

.freeplay_en:
	; Zero out the credit count just in case
	clr.w	(CRED_COUNT).l
	clr.w	(CRED_PREV).l

	move.w	(SC_STATE).l, d1
	; We don't want to be able to start (at least not this way) from
	; the continue screen or the how to play screen
	cmpi.w	#S_CONTINUE1, d1
	beq	.finish
	cmpi.w	#S_CONTINUE2, d1
	beq	.finish
	cmpi.w	#S_HOWTOPLAY, d1
	beq	.howtoplay

	; Read P1 and P2 inputs together
	move.w	(INPUT_P1).l, d1
	or.w	INPUT_P2, d1
	andi.b	#$80, d1

	; If start is not held, get out of here
	beq	.finish

	; If the transition animation is playing, abort
	; This is to avoid an edge case where start is pressed briefly on the
	; title --> demo transition, where the transition effect will be stuck
	; until the demo starts the next time. This is cleaner than forcing
	; the animation to exit prematurely.
	tst.w	(TRANSITION_LOC).l
	bne	.finish

	; This is a hack-on-a-hack to let the demo exit cleanly. It sets the
	; demo duration counter to the expiry value instead of manipulating
	; the state machine.
	move.w	(SC_STATE).l, d1
	cmpi.w	#S_DEMO, d1
	beq	.demo
	cmpi.w	#S_DEMOSTART, d1
	beq	.demo
	
	; If we're not on the demo screen, just change the state to the title.
	clr.w	($100EC4).l
	move.w	#S_TITLE_START, (SC_STATE).l
	rts

.demo:
	; Kill the demo.
	move.w	#DEMO_EXPIRE_NUM, (DEMO_TIMER).l
.finish:
	rts

.howtoplay:
	; The how-to-play screen has a little hack to set the credits to a
	; high amount so the "insert coin" doesn't show
	move.w	#9, (CRED_COUNT).l
	rts

; Yells "esprade" and resets the machine
; ============================================================================
reset:
	jsr	(STOP_SOUND_LOC).l
	move.w	#$51, d0
	move.w	#$3, d1
	jsr	(PLAY_SOUND_LOC).l
	movea.l	#$69110000, sp
	move	#$2700, sr
	jmp	$005972
