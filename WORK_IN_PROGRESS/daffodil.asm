
@Cold            ; Firmware for Sonne micro-controller rev. Daffodil
   na >End EXIT  ; Dec 2023 Michael Mangelsdorf <mim@ok-schalter.de>
CLOSE            ; See https://github.com/Dosflange/Sonne

; CLOSE is
; an assembler directive, that object code goes into the next 256 byte bank

; ----------------------------- mul8 ----------------------------------------

@mul8 ; Multiply A * B, result in A and B 
ENTER

   aL1                     ; Initialize copy multiplicand (low order)
   bL0                     ; Save multiplier

         nb C8h fm         ; Save return address

   na 0 aL2                ; Clear high-order
   na 8 aL3                ; Initialize loop counter, 8 bits

loop@
   nb 1, L1a AND,
   ne >skip
   L0a, L2b ADD           ; Add multiplier if low order lsb set
   fL2

skip@
   nb 1, L2a AND 
   fG0                     ; Check if high order lsb set
   L1a SRA, fL1           ; Shift low order byte right
   L2a SRA, fL2           ; Shift high order byte right
   
   G0a IDA, ne >done
   na 80h, L1b IOR,
   fL1

done@
   L3a IDA f1- fL3
   nt <loop
   L1a
   L2b

nb C8h mf
LEAVE RET
CLOSE

; ----------------------------- divmod8 -------------------------------------

@divmod8 ; Divide A by B, division result in A, remainder in B
ENTER

aL0                       ; Dividend
bL1                       ; Divisor

      nb C8h fm           ; Save return address

na 1, aL2                 ; Shift counter
na 0, aL3                 ; Initialise quotient to zero

L1a IDA ne >ELOOP         ; Skip if divisor zero

na 80h.                    ; MSB mask
MSB_SHIFT@                 ; Shift divisor left so that first 1 bit is at MSB
 L1b                      ; Load divisor
 AND nt >DIVIDE            ; Skip when MSB set
 SLB fL1                  ; Shift divisor left and update
 
 L2b
 IDB f1+ fL2              ; Increment shift counter and update
 nj <MSB_SHIFT

DIVIDE@
 L3b SLB fL3             ; Shift quotient left and update
 L1a                      ; Divisor
 L0b                      ; Dividend
 OCA f1+ fa                ; Negate divisor
 CYF                       ; Check borrow bit
 ne >REP

 ADD fa                    ; Accept subtraction
 aL0                      ; Update dividend
 L3a IDA f1+ fL3         ; Increment quotient

REP@
 L1a SRA fL1             ; Shift divisor right for next subtraction
 L2a IDA ne >ELOOP        ; Check if counter value zero
 IDA f1- fL2
 nt <DIVIDE

ELOOP@ L3a, L0b

nb C8h mf
LEAVE RET
CLOSE

; ----------------------------- asc_to_num ----------------------------------

@asc_to_num ; Convert ASCII code in A to a number, result in A
ENTER
nb C8h fm

   aL1                    ; Save A
   nb 48                   ; ASCII code of letter '0'
   OCB f1+ fb              ; Subtract it from A
   ADD fb fL2

   na 10 AGB               ; Result must be smaller than 10, if decimal
   nt >done

   L1a                    ; Not a decimal, try hexadecimal
   nb 10 ADD fa            ; Add 10 (value of hex letter 'A')
   nb 65                   ; ASCII code of letter 'A'
   OCB f1+ fb              ; Substract it from A
   ADD fL2

   done@ L2a

nb C8h mf
LEAVE RET
CLOSE

; ----------------------------- num_to_asc ----------------------------------

@num_to_asc ; Convert number in A to ASCII code
ENTER
nb C8h fm

   nb 10                   ; Number must be <10 for ASCII range '0' - '9'
   ALB nt >is_deci

   nb -10
   ADD fa                  ; Subtract 10
   nb 65                   ; ASCII code of letter 'A'
   ADD fa
   nj >done

   is_deci@
   nb 48                   ; ASCII code of letter '0'
   ADD fa
   done@

nb C8h mf
LEAVE RET
CLOSE

; ----------------------------- num_to_string -------------------------------

@num_to_string ; Convert value in A to ASCII string in global
               ; Number base in B

ENTER aL1
na C8h fm, na C9h rm
   
   na 88h aL3                     ; Result string base address
   na 2
   AEB
   nt >is_bin
   na 10
   AEB
   nt >is_dec
   is_hex@ na >pow16 nj >join      ; Set base address of divisor table
   is_dec@ na >pow10 nj >join
   is_bin@ na >pow2

   join@ aL2
      nr <num_to_string            ; set table addr high
   rep@
      L1a
      L2b                         ; set table addr low
      mb                           ; get table entry
      IDB ne >done                 ; zero entry marks end of table
      *divmod8
      bL0
      *num_to_asc
      L3b IDA fm IDB f1+ fL3     ; Store, and increment strint ptr
      L0b bL1                    ; Remainder becomes new A
      L2b IDB f1+ fL2.           ; Point to next divisor
      nj <rep

   done@

na C8h mf, na C9h mr
LEAVE RET

pow2@ 128 64 32 16 8 4 2 1 0
pow10@ 100 10 1 0
pow16@ 16 1 0

CLOSE

; ----------------------------- string_to_num -------------------------------

@string_to_num   ; Convert ASCII string in global to value in B
                 ; Number base in B

ENTER
na C8h fm, na C9h rm

   na 0 aL3                       ; Conversion result, initialise to zero
   na 2 AEB                        ; Check which base it is
   nt >is_bin
   na 10
   AEB
   nt >is_dec
   is_hex@ na >pow16 nj >join      ; Set base address of mult table
   is_dec@ na >pow10 nj >join
   is_bin@ na >pow2

   join@
      aL1                         ; Points to first multiplier in table
      na 80h                       ; Addr of first ASCII digit (left-most)

   seek@                           ; Get address of str termination byte
      aL2 IDA f1+ fa
      mb
      IDB
      nt <seek

   nr <string_to_num               ; set table addr high
   rep@
      L2b ma                      ; Points to current digit
      *asc_to_num                  ; Convert to number in A
      L1b mb
       *mul8
      L3b ADD fL3                ; Add to result
      L1b IDB f1+ fL1
      L2f f1- L2a fL2
      nb 80h
      AEB ne <rep

   done@ L3b

na C8h mf, na C9h mr
LEAVE RET

pow2@ 1 2 4 8 16 32 64 128 0
pow10@ 1 10 100 0
pow16@ 1 16 0

CLOSE

; ---------------------------------------------------------------------------

@End
   nb 2
   *string_to_num
   SSI
   ns 0
   stop@ nj <stop
  ; f8- This causes the program to fail (no SSI output!)
CLOSE




