
(module

    ;;
    ;; ─── IMPORTS ────────────────────────────────────────────────────────────────────
    ;;

        (import "wasi_unstable" "fd_write"
            (func $fd-write (param i32 i32 i32 i32) (result i32)))

    ;;
    ;; ─── GLOBALS ────────────────────────────────────────────────────────────────────
    ;;

        (memory 1)
        (export "memory" (memory 0))

    ;;
    ;; ─── ALPHABET ───────────────────────────────────────────────────────────────────
    ;;

        ;; Some safe offsets so that our stuff
        ;; don't overlap in the momry.

        (global $STDOUT-RESULT-LENGTH-OFFSET i32 (i32.const 250))

        (global $ALPHABET-OFFSET i32 (i32.const 300))

        (global $STDOUT-OFFSET i32 (i32.const 350))

        (global $MUT-STDOUT-MESSAGE-SIZE (mut i32) (i32.const 0))

        (global $STDOUT-FILE-DISCRIPTOR i32 (i32.const 1))

        ;; In memory encoding of the alphabets
        ;; so that we can later copy from :)
        (data (global.get $ALPHABET-OFFSET) "0123456789\n ")

        ;; Compute UTF-8 offset for strings
        (func $compute-utf8-offset (param $index i32) (result i32)
            (i32.mul (i32.const 1) (local.get $index))
        )

        ;; Finds the character we are looking
        ;; for from the encoded data.
        (func $get-alphabet-code (param $alphabet-index i32) (result i32)
            (i32.load (call $compute-utf8-offset (i32.add (global.get $ALPHABET-OFFSET)
                                                          (local.get $alphabet-index))))
        )

        ;; Copying digit data from from the
        ;; alphabet to the offset for stdout
        (func $encode-digit-to-string-at-offset (param $offset i32) (param $digit i32)
            (i32.store (call $compute-utf8-offset (i32.add (global.get $STDOUT-OFFSET)
                                                           (local.get $offset)))
                       (call $get-alphabet-code (local.get $digit)))
        )

        ;; Set the STDOUT Message size
        (func $set-stdout-message-size (param $size i32)
            (global.set $MUT-STDOUT-MESSAGE-SIZE (local.get $size))
        )

        ;; Print to STDOUT
        (func $print-to-stdout
            ;; The expected I/O Vector
            (i32.store (i32.const 0) ;; Pointer to the start of the STDOUT message
                       (global.get $STDOUT-OFFSET))
            (i32.store (i32.const 4) ;; Length of the message
                       (global.get $MUT-STDOUT-MESSAGE-SIZE))
            ;; Writing
            (call $fd-write (i32.const 1)   ;; STDOUT
                            (i32.const 0)   ;; pointer to the I/O Vector where we stored the location of stdout offset
                            (i32.const 1)   ;; number of strings we are printing
                            (global.get $STDOUT-RESULT-LENGTH-OFFSET))
            ;; Memory stuff
            (drop)
        )

    ;;
    ;; ─── COMPUTE NUMBER SIZE ────────────────────────────────────────────────────────
    ;;

        ;; computes the length of integer
        ;; digits of given number. Example:
        ;; 12345 -> 5, 0 -> 1, 12345678 -> 8
        (func $get-number-digits (param $input f64) (result i32)
            (local $length i32)
            (local.set $length (i32.const 0))

            (block (result)
                (loop (result)
                    ;; whil input >= 0
                    (if (result) (f64.ge (local.get $input) (f64.const 1))
                        (then   ;; length++
                                (local.set $length (i32.add (local.get $length)
                                                            (i32.const 1)))
                                ;; input = input / 10
                                (local.set $input (f64.div (local.get $input)
                                                           (f64.const 10)))
                                ;; continue
                                (br 1)
                        )
                        (else   ;; break
                                (br 0)
                        )
                    )
                )
            )
            ;; return
            (local.get $length)
        )

    ;;
    ;; ─── GET DIGIT OF THE NUMBER ────────────────────────────────────────────────────
    ;;

        (func $compute-power-of-10 (param $power f64) (result f64)
            (local $result f64)
            (local $index f64)

            (local.set $result (f64.const 1))
            (local.set $index (f64.const 0))

            (block (result)
                (loop (result)
                    (if (result) (f64.lt (local.get $index) (local.get $power))
                        (then   ;; multiply by 10
                                (local.set $result (f64.mul (local.get $result)
                                                            (f64.const 10)))
                                ;; index++
                                (local.set $index (f64.add (local.get $index)
                                                           (f64.const 1)))
                                ;; continue
                                (br 1)
                        )
                        (else   ;; break
                                (br 0)
                        )
                    )
                )
            )

            ;; returning
            (local.get $result)
        )

        ;; Imagine reading the a character
        ;; at index $index from an string.
        ;; this is the same for number. So
        ;; 123456[3] shall be 4
        (func $get-digit-of-number (param $x f64) (param $size i32) (param $index i32) (result i32)
            ;; the way we are going to do this
            ;; is to implement this formula:
            ;;       s = 6
            ;;       i = 3
            ;;       x = 123456
            ;;
            ;;       y = x / (10 ^ (s - (i + 1)))
            ;;           => 1,234.56
            ;;
            ;;       z = floor( y - (floor(y / 10) * 10 ) )
            ;;           => 4

            (local $y f64)

            (local.set $y (f64.div (local.get $x)
                                   (call $compute-power-of-10 (f64.sub (f64.convert_i32_s (local.get $size))
                                                                       (f64.add (f64.convert_i32_s (local.get $index))
                                                                                (f64.const 1))))))
            (i32.trunc_f64_u (f64.floor (f64.sub (local.get $y)
                                                 (f64.mul (f64.floor (f64.div (local.get $y)
                                                                     (f64.const 10)))
                                                          (f64.const 10)))))
        )

    ;;
    ;; ─── PRINT NUMBER ───────────────────────────────────────────────────────────────
    ;;

        (func $print-number (param $printable f64)
            (local $size  i32)
            (local $index i32)

            (local.set $index (i32.const 0))
            (local.set $size  (call $get-number-digits (local.get $printable)))

            ;; set the size of what we are
            ;; going to print
            (call $set-stdout-message-size (i32.add (local.get $size)
                                                    (i32.const 1)))

            ;; for each digit, encode the digit
            ;; to the buffer memory
            (block (result)
                (loop (result)
                    (if (result) (i32.le_u (local.get $index) (local.get $size))
                        (then   ;; print a 7 there
                                (call $encode-digit-to-string-at-offset (local.get $index)
                                                                        (call $get-digit-of-number (local.get $printable)
                                                                                                   (local.get $size)
                                                                                                   (local.get $index)))
                                ;; index++
                                (local.set $index (i32.add (local.get $index)
                                                           (i32.const 1)))
                                ;; continue
                                (br 1)
                        )
                        (else   ;; break
                                (br 0)
                        )
                    )
                )
            )

            ;; encode EOL to buffer
            (call $encode-digit-to-string-at-offset (local.get $size)
                                                    (i32.const 10)) ;; \n
            ;; request WASI interface to
            ;; print the buffer to stdout.
            (call $print-to-stdout)
        )

    ;;
    ;; ─── FACTORIAL ──────────────────────────────────────────────────────────────────
    ;;

        ;; A simple factorial so that we
        ;; can test our awesome thing :)
        (func $factorial-recursive (param $n f64) (result f64)
            ;; is n == 1?
            (if (result f64) (f64.eq (local.get $n) (f64.const 1))
                (then   ;; if so, return: 1
                        f64.const 1
                )
                (else   ;; n - 1
                        local.get $n
                        f64.const 1
                        f64.sub
                        ;; fac(n - 1)
                        call $factorial-recursive
                        ;; n * fac(n - 1)
                        local.get $n
                        f64.mul
                )
            )
        )

    ;;
    ;; ─── MAIN ───────────────────────────────────────────────────────────────────────
    ;;

        (func $main (export "_start")
            (call $factorial-recursive (f64.const 5))
            (call $print-number)

            (call $factorial-recursive (f64.const 17))
            (call $print-number)

            (call $factorial-recursive (f64.const 18))
            (call $print-number)
        )

    ;; ────────────────────────────────────────────────────────────────────────────────
)
