;-------------------------------------------------------------------------------
; MSP430 Assembler Code Template for use with TI Code Composer Studio
;-------------------------------------------------------------------------------
            .cdecls C, LIST, "msp430g2553.h"       		; Include device header file

            .def    RESET
            .text
            .retain
            .retainrefs


;-------------------------------------------------------------------------------
; Definitions
;-------------------------------------------------------------------------------
RXD			.equ	BIT1								; MSP430G2553 Rx Pin on Port 1
TXD			.equ	BIT2								; MSP430G2553 Tx Pin on Port 1
ADCtemp		.equ	R4									; Temporary storage for ADC result


;-------------------------------------------------------------------------------
; Setup
;-------------------------------------------------------------------------------
RESET       mov.w   #__STACK_END, SP         			; Initialize stackpointer
StopWDT     mov.w   #WDTPW | WDTHOLD, &WDTCTL  			; Stop watchdog timer

ClockSetup	mov.b	CALBC1_1MHZ, BCSCTL1				; Calibrate MCLK for 1 MHz using TLV
			mov.b	CALDCO_1MHZ, DCOCTL
			bis.b	#XT2OFF, BCSCTL1		 			; Turn off external crystal osc.
			bis.b	#LFXT1S_2, BCSCTL3 					; Select VLOCLK for ACLK

PortSetup	bis.b	#RXD + TXD, P1SEL					; Setup up Tx and Rx for UART
			bis.b	#RXD + TXD, P1SEL2

SetupUART0 	mov.b 	#UCPEN + UCSPB, &UCA0CTL0 			; Sets odd parity and two stop bits
			mov.b 	#UCSSEL1 + UCSSEL0, &UCA0CTL1		; UCLK = SMCLK ~1 MHz
			clr.b 	&UCA0STAT
			mov.b 	#109, &UCA0BR0 						; Baud Rate = ?
			mov.b 	#0, &UCA0BR1 						; UCBRx = ?
			mov.b 	#002h, &UCA0MCTL 					; UCBRFx = 0, UCBRSx = 1, UCOS16 = 0
			bic.b 	#UCSWRST, &UCA0CTL1 				; **Initialize USI state machine**

TimerSetup	bis.w	#TASSEL_1 + MC_1 + TACLR, TA0CTL	; Select ACLK, up mode, and clear counter
			bis.w	#OUTMOD_3, TA0CCTL0					; Setup to trigger ADC10
			mov.w	#50000, TA0CCR0						; Approximatly 1 sec duration

ADCSetup	mov.w	#SREF_1 + ADC10SHT_3 + ADC10SR + REFBURST + REFON + ADC10IE, ADC10CTL0	; Make ADC very low power
			mov.w	#INCH_10 + SHS_2 + ISSH + ADC10SSEL_1, ADC10CTL1						; Select temperature measurment
			bis.w	#ADC10ON + ENC + ADC10SC, ADC10CTL0										; Start first conversion

			bis.b	#LPM3 + GIE, SR						; Enable interrupts and low power
			nop
			nop


;-------------------------------------------------------------------------------
; Waits until UART state machine is ready
;-------------------------------------------------------------------------------
UartReady:	bit.b	#UCA0TXIFG, &IFG2
			jz		UartReady
			ret


;-------------------------------------------------------------------------------
; ADC10 Done Interrupt
;-------------------------------------------------------------------------------
Acquire:	bic.b	#LPM3 + GIE, SR						; Disable interrupts and low power
			bic.w	#ADC10IFG, ADC10CTL0				; Clear ADC10 interrupt flag

			mov.w	ADC10MEM, ADCtemp					; Move ADC result into temporary register
			call	#UartReady							; Note the text will not be human readable in a terminal
			mov.b	ADCtemp, UCA0TXBUF					; Load first "lower" byte of adc result into UART
			call	#UartReady							; Wait until UART is done
			swpb	ADCtemp								; Swap upper and lower bytes
			mov.b	ADCtemp, UCA0TXBUF					; Load second "upper" byte of adc result into UART

			bis.b	#LPM3 + GIE, SR						; Enable interrupts and low power
			reti


;-------------------------------------------------------------------------------
; Resets MSP430 if ISR trap occurs
;-------------------------------------------------------------------------------
__TI_ISR_TRAP:
			jmp 	RESET


;-------------------------------------------------------------------------------
; Interrupt Vectors & Stack Pointer definition
;-------------------------------------------------------------------------------
			.global __STACK_END
            .sect   .stack

            .sect   ".reset"                			; MSP430 RESET Vector
            .short  RESET

			.sect   ".int05"                			; ADC10 Interrupt
            .short  Acquire

            .sect	".text:_isr:__TI_ISR_TRAP"			; ISR Trap Interrupt
			.align	2
			.global	__TI_ISR_TRAP
            .end
