(module
  ;; import 1 page of memory from env.memory
  ;; 0x00 ~ 0x3f will be used as input chunk
  ;; 0x40 ~ 0x5f will be used to store initial hash values (h0 ~ h7)
  ;; 0x60 ~ 0x63 will be used to store `message_len`
  ;; 0x100 ~ 0x1ff will be used to store round constants
  (import "env" "memory" (memory 1))

  ;; functions to export
  (export "sha256_init" (func $sha256_init))
  (export "sha256_update" (func $sha256_update))
  (export "sha256_end" (func $sha256_end))

  ;; data section for round constant
  ;; note: wasm stores numbers in little-endian
  (data (i32.const 0x100) "\98\2f\8a\42\91\44\37\71\cf\fb\c0\b5\a5\db\b5\e9\5b\c2\56\39\f1\11\f1\59\a4\82\3f\92\d5\5e\1c\ab\98\aa\07\d8\01\5b\83\12\be\85\31\24\c3\7d\0c\55\74\5d\be\72\fe\b1\de\80\a7\06\dc\9b\74\f1\9b\c1\c1\69\9b\e4\86\47\be\ef\c6\9d\c1\0f\cc\a1\0c\24\6f\2c\e9\2d\aa\84\74\4a\dc\a9\b0\5c\da\88\f9\76\52\51\3e\98\6d\c6\31\a8\c8\27\03\b0\c7\7f\59\bf\f3\0b\e0\c6\47\91\a7\d5\51\63\ca\06\67\29\29\14\85\0a\b7\27\38\21\1b\2e\fc\6d\2c\4d\13\0d\38\53\54\73\0a\65\bb\0a\6a\76\2e\c9\c2\81\85\2c\72\92\a1\e8\bf\a2\4b\66\1a\a8\70\8b\4b\c2\a3\51\6c\c7\19\e8\92\d1\24\06\99\d6\85\35\0e\f4\70\a0\6a\10\16\c1\a4\19\08\6c\37\1e\4c\77\48\27\b5\bc\b0\34\b3\0c\1c\39\4a\aa\d8\4e\4f\ca\9c\5b\f3\6f\2e\68\ee\82\8f\74\6f\63\a5\78\14\78\c8\84\08\02\c7\8c\fa\ff\be\90\eb\6c\50\a4\f7\a3\f9\be\f2\78\71\c6")

  ;; helper function `get_word`
  ;; input  - word index
  ;; output - offset
  (func $get_word (param $w i32) (result i32)
    ;; offset = ($w & 0xf) * 4
    (return (call $flip_endian (i32.load
      (i32.mul
        (i32.and (get_local $w) (i32.const 0xf))
        (i32.const 4)
      )
    )))
  )

  ;; helper function `set_word`
  ;; input  - word index, value
  (func $set_word (param $w i32) (param $v i32)
    ;; offset = ($w & 0xf) * 4
    (i32.store (call $flip_endian
      (i32.mul
        (i32.and (get_local $w) (i32.const 0xf))
        (i32.const 4)
      )
      (get_local $v)
    ))
  )

  ;; helper function `get_constant`
  ;; input  - round
  ;; output - constant
  (func $get_constant (param $w i32) (result i32)
    ;; offset = 0x100 + $w * 4
    (return (i32.load
      (i32.add (i32.const 0x100) (i32.mul (get_local $w) (i32.const 4)))
    ))
  )

  ;; helper function `flip_endian`
  ;; once `i32.bswap` is landed, this function is useless
  (func $flip_endian (param $w i32) (result i32)
    ;; (w & 0xff000000 >>> 24) |
    ;; (w & 0x00ff0000 >>>  8) |
    ;; (w & 0x0000ff00 <<   8) |
    ;; (w & 0x000000ff <<  24)
    (return (i32.or
      (i32.or
        (i32.shr_u (i32.and (get_local $w) (i32.const 0xff000000)) (i32.const 24))
        (i32.shr_u (i32.and (get_local $w) (i32.const 0x00ff0000)) (i32.const  8))
      )
      (i32.or
        (i32.shl   (i32.and (get_local $w) (i32.const 0x0000ff00)) (i32.const  8))
        (i32.shl   (i32.and (get_local $w) (i32.const 0x000000ff)) (i32.const 24))
      )
    ))
  )

  ;; function `sha256_init`
  ;; initialize memory
  (func $sha256_init
    (i64.store (i32.const 0x00) (i64.const 0))
    (i64.store (i32.const 0x08) (i64.const 0))
    (i64.store (i32.const 0x10) (i64.const 0))
    (i64.store (i32.const 0x18) (i64.const 0))
    (i64.store (i32.const 0x20) (i64.const 0))
    (i64.store (i32.const 0x28) (i64.const 0))
    (i64.store (i32.const 0x30) (i64.const 0))
    (i64.store (i32.const 0x38) (i64.const 0))

    (i32.store (i32.const 0x40) (i32.const 0x6a09e667))
    (i32.store (i32.const 0x44) (i32.const 0xbb67ae85))
    (i32.store (i32.const 0x48) (i32.const 0x3c6ef372))
    (i32.store (i32.const 0x4c) (i32.const 0xa54ff53a))
    (i32.store (i32.const 0x50) (i32.const 0x510e527f))
    (i32.store (i32.const 0x54) (i32.const 0x9b05688c))
    (i32.store (i32.const 0x58) (i32.const 0x1f83d9ab))
    (i32.store (i32.const 0x5c) (i32.const 0x5be0cd19))

    (i32.store (i32.const 0x60) (i32.const 0x00000000))
  )

  ;; function `sha256_update`
  ;; process full block
  (func $sha256_update
    ;; round counter
    (local $w i32)

    ;; internal variables
    (local $a i32) (local $b i32) (local $c i32) (local $d i32)
    (local $e i32) (local $f i32) (local $g i32) (local $h i32)

    (local $s0 i32) (local $s1 i32)
    (local $ch i32) (local $maj i32) (local $temp1 i32) (local $temp2 i32)

    ;; message_len += 64 bytes (512 bits)
    (i32.store
      (i32.const 0x60)
      (i32.add (i32.load (i32.const 0x60)) (i32.const 64))
    )

    ;; load h0 ~ h7
    (set_local $a (i32.load (i32.const 0x40)))
    (set_local $b (i32.load (i32.const 0x44)))
    (set_local $c (i32.load (i32.const 0x48)))
    (set_local $d (i32.load (i32.const 0x4c)))
    (set_local $e (i32.load (i32.const 0x50)))
    (set_local $f (i32.load (i32.const 0x54)))
    (set_local $g (i32.load (i32.const 0x58)))
    (set_local $h (i32.load (i32.const 0x5c)))

    ;; loop
    (set_local $w (i32.const 0))
    (block $done
      (loop $loop
        ;; word 0 ~ 15 will be used as-is on memory
        ;; word 16 ~ 63 will be calculated and replaced on memory
        (if
          ;; if 16 <= $w
          (i32.ge_s (get_local $w) (i32.const 16))

          ;; calculate word to use
          (block
            (set_local $s0 (call $get_word (i32.sub (get_local $w) (i32.const 15))))
            (set_local $s1 (call $get_word (i32.sub (get_local $w) (i32.const  2))))

            ;; s0 = s0 rotr 7 ^ s0 rotr 10 ^ s0 >> 3
            (set_local $s0
              (i32.xor (i32.xor
                (i32.rotr  (get_local $s0) (i32.const  7))
                (i32.rotr  (get_local $s0) (i32.const 18)) )
                (i32.shr_u (get_local $s0) (i32.const  3))
              )
            )

            ;; s1 = s1 rotr 17 ^ s1 rotr 19 ^ s1 >> 10
            (set_local $s1
              (i32.xor (i32.xor
                (i32.rotr  (get_local $s1) (i32.const 17))
                (i32.rotr  (get_local $s1) (i32.const 19)) )
                (i32.shr_u (get_local $s1) (i32.const 10))
              )
            )

            (call $set_word
              (get_local $w)
              ;; value = (words[w-16] + s0 + words[w-7] + s1)
              (i32.add
                (i32.add
                  (call $get_word (i32.sub (get_local $w) (i32.const 16)))
                  (get_local $s0)
                )
                (i32.add
                  (call $get_word (i32.sub (get_local $w) (i32.const  7)))
                  (get_local $s1)
                )
              )
            )
          )
        )

        ;; compress
        (set_local $s1
          ;; e rotr 6 ^ e rotr 11 ^ e rotr 25
          (i32.xor (i32.xor
            (i32.rotr (get_local $e) (i32.const  6))
            (i32.rotr (get_local $e) (i32.const 11)) )
            (i32.rotr (get_local $e) (i32.const 25))
          )
        )
        (set_local $ch
          ;; (e & f) ^ (~e & g)
          (i32.or
            (i32.and (get_local $e) (get_local $f))
            ;; ~a == a ^ 0xffffffff
            (i32.and (i32.xor (get_local $e) (i32.const 0xffffffff)) (get_local $g))
          )
        )
        (set_local $temp1
          ;; h + s1 + ch + constant[w] + words[w]
          (i32.add
            (i32.add (i32.add
              (get_local $h)
              (get_local $s1) )
              (get_local $ch)
            )
            (i32.add
              (call $get_constant (get_local $w))
              (call $get_word (get_local $w))
            )
          )
        )
        (set_local $s0
          ;; a rotr 2 ^ a rotr 13 ^ a rotr 22
          (i32.xor (i32.xor
            (i32.rotr (get_local $a) (i32.const  2))
            (i32.rotr (get_local $a) (i32.const 13)) )
            (i32.rotr (get_local $a) (i32.const 22))
          )
        )
        (set_local $maj
          ;; (a & b) ^ (a & c) ^ (b & c)
          (i32.xor (i32.xor
            (i32.and (get_local $a) (get_local $b))
            (i32.and (get_local $a) (get_local $c)) )
            (i32.and (get_local $b) (get_local $c))
          )
        )
        (set_local $temp2 (i32.add (get_local $s0) (get_local $maj)))

        ;; rotate variables
        (set_local $h (get_local $g))
        (set_local $g (get_local $f))
        (set_local $f (get_local $e))
        (set_local $e (i32.add (get_local $d) (get_local $temp1)))
        (set_local $d (get_local $c))
        (set_local $c (get_local $b))
        (set_local $b (get_local $a))
        (set_local $a (i32.add (get_local $temp1) (get_local $temp2)))

        ;; w += 1
        (set_local $w (i32.add (get_local $w) (i32.const 1)))

        ;; if 64 <= w, break
        (br_if $done (i32.ge_s (get_local $w) (i32.const 64)))

        ;; else, continue
        (br $loop)
      )
    )

    ;; feed to h0 ~ h7
    (i32.store (i32.const 0x40) (i32.add (get_local $a) (i32.load (i32.const 0x40))))
    (i32.store (i32.const 0x44) (i32.add (get_local $b) (i32.load (i32.const 0x44))))
    (i32.store (i32.const 0x48) (i32.add (get_local $c) (i32.load (i32.const 0x48))))
    (i32.store (i32.const 0x4c) (i32.add (get_local $d) (i32.load (i32.const 0x4c))))
    (i32.store (i32.const 0x50) (i32.add (get_local $e) (i32.load (i32.const 0x50))))
    (i32.store (i32.const 0x54) (i32.add (get_local $f) (i32.load (i32.const 0x54))))
    (i32.store (i32.const 0x58) (i32.add (get_local $g) (i32.load (i32.const 0x58))))
    (i32.store (i32.const 0x5c) (i32.add (get_local $h) (i32.load (i32.const 0x5c))))
  )

  ;; function `sha256_end`
  ;; input  - length of final chunk
  (func $sha256_end (param $final_len i32)
    (local $total_len i32)
    (local $i i32)

    ;; total_len = message_len + final_len
    (set_local $total_len (i32.add
      (i32.load (i32.const 0x60))
      (get_local $final_len)
    ))

    ;; append 0x80
    (i32.store8 (get_local $final_len) (i32.const 0x80))

    (set_local $i (i32.add (get_local $final_len) (i32.const 1)))

    (if (i32.gt_s (get_local $i) (i32.const 56))
      ;; if 56 < i
      (block
        (block $done_pad
          ;; zero pad
          (loop $loop
            (br_if $done_pad (i32.ge_s (get_local $i) (i32.const 64)))

            (i32.store8 (get_local $i) (i32.const 0))
            (set_local $i (i32.add (get_local $i) (i32.const 1)))
            (br $loop)
          )
        )

        ;; update
        (call $sha256_update)

        ;; fill 14 words with 0
        (i64.store (i32.const 0x00) (i64.const 0))
        (i64.store (i32.const 0x08) (i64.const 0))
        (i64.store (i32.const 0x10) (i64.const 0))
        (i64.store (i32.const 0x18) (i64.const 0))
        (i64.store (i32.const 0x20) (i64.const 0))
        (i64.store (i32.const 0x28) (i64.const 0))
        (i64.store (i32.const 0x30) (i64.const 0))
      )

      ;; else
      (block $done_pad
        ;; zero pad
        (loop $loop
          (br_if $done_pad (i32.ge_s (get_local $i) (i32.const 56)))

          (i32.store8 (get_local $i) (i32.const 0))
          (set_local $i (i32.add (get_local $i) (i32.const 1)))
          (br $loop)
        )
      )
    )

    ;; append length (in bits)
    (call $set_word (i32.const 14) (i32.const 0))
    (call $set_word (i32.const 15) (i32.mul (get_local $total_len) (i32.const 8)))

    ;; update final block
    (call $sha256_update)
  )
)
