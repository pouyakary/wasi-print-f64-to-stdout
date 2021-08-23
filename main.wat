
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
        (global $ALPHABET_OFFSET i32 (i32.const 100))
        (global $STDOUT_OFFSET i32 (i32.const 150))

        (global $MUT-STDOUT-MESSAGE-SIZE (mut i32)
                                         (i32.const 0))

        ;; In memory encoding of the alphabets
        ;; so that we can later copy from :)
        (data (global.get $ALPHABET_OFFSET) "0123456789\n ")

        ;; Finds the character we are looking
        ;; for from the encoded data.
        (func $get-alphabet-code (param $alphabet-index i32) (result i32)
            (i32.load (i32.add (global.get $ALPHABET_OFFSET)
                               (local.get $alphabet-index)))
        )

        ;; Copying digit data from from the
        ;; alphabet to the offset for stdout
        (func $encode-digit-to-string-at-offset (param $offset i32) (param $digit i32)
            (i32.store (i32.add (global.get $STDOUT_OFFSET)
                                (local.get $offset))
                       (call $get-alphabet-code (local.get $digit)))
        )

        ;; Set the STDOUT Message size
        (func $set-stdout-message-size (param $size i32)
            (global.set $MUT-STDOUT-MESSAGE-SIZE (local.get $size))
        )

        ;; Print to STDOUT
        (func $print-to-stdout
            (i32.store (i32.const 0)
                       (global.get $STDOUT_OFFSET))
            (i32.store (i32.const 4)
                       (global.get $MUT-STDOUT-MESSAGE-SIZE))
            (call $fd-write (i32.const 1)
                            (i32.const 0)
                            (i32.const 1)
                            (i32.const 20))
            (drop)
        )

    ;;
    ;; ─── PRINT 17 ───────────────────────────────────────────────────────────────────
    ;;

        (func $print-17
            ;; 1
            (call $encode-digit-to-string-at-offset (i32.const 0)
                                                    (i32.const 1))
            ;; 7
            (call $encode-digit-to-string-at-offset (i32.const 1)
                                                    (i32.const 7))
            ;; \n
            (call $encode-digit-to-string-at-offset (i32.const 2)
                                                    (i32.const 10))
            ;; "17\n".length == 3
            (call $set-stdout-message-size (i32.const 3))
        )

    ;;
    ;; ─── MAIN ───────────────────────────────────────────────────────────────────────
    ;;

        (func $main (export "_start")
            (call $print-17)
            (call $print-to-stdout)
        )

    ;; ────────────────────────────────────────────────────────────────────────────────
)
