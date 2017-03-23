(module
  ;; import 1 page of memory from env.memory
  ;; 0x00 ~ 0x3f will be used as input chunk
  ;; 0x40 ~ 0x43 will be used to store `message_len`
  ;; 0x44 ~ 0x47 will be used to store `h0`
  ;; 0x48 ~ 0x4b will be used to store `h1`
  ;; 0x4c ~ 0x4f will be used to store `h2`
  ;; 0x50 ~ 0x53 will be used to store `h3`
  ;; 0x54 ~ 0x57 will be used to store `h4`
  (import "env" "memory" (memory 1))

  ;; functions to export
  (export "sha1_init" (func $sha1_init))
  (export "sha1_update" (func $sha1_update))
  (export "sha1_end" (func $sha1_end))

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

  ;; helper function `flip_endian`
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

  ;; function `sha1_init`
  ;; initialize memory
  (func $sha1_init
    (i64.store (i32.const 0x00) (i64.const 0))
    (i64.store (i32.const 0x08) (i64.const 0))
    (i64.store (i32.const 0x10) (i64.const 0))
    (i64.store (i32.const 0x18) (i64.const 0))
    (i64.store (i32.const 0x20) (i64.const 0))
    (i64.store (i32.const 0x28) (i64.const 0))
    (i64.store (i32.const 0x30) (i64.const 0))
    (i64.store (i32.const 0x38) (i64.const 0))

    (i32.store (i32.const 0x40) (i32.const 0x00000000))
    (i32.store (i32.const 0x44) (i32.const 0x67452301))
    (i32.store (i32.const 0x48) (i32.const 0xefcdab89))
    (i32.store (i32.const 0x4c) (i32.const 0x98badcfe))
    (i32.store (i32.const 0x50) (i32.const 0x10325476))
    (i32.store (i32.const 0x54) (i32.const 0xc3d2e1f0))
  )

  ;; function `sha1_update`
  ;; process full block
  (func $sha1_update
    ;; word counter
    (local $w i32)

    ;; internal variables
    (local $a i32) (local $b i32) (local $c i32) (local $d i32) (local $e i32)
    (local $f i32) (local $k i32) (local $t i32)

    ;; message_len += 64 bytes (512 bits)
    (i32.store
      (i32.const 0x0040)
      (i32.add (i32.load (i32.const 0x0040)) (i32.const 64))
    )

    ;; load h0 ~ h4
    (set_local $a (i32.load (i32.const 0x44)))
    (set_local $b (i32.load (i32.const 0x48)))
    (set_local $c (i32.load (i32.const 0x4c)))
    (set_local $d (i32.load (i32.const 0x50)))
    (set_local $e (i32.load (i32.const 0x54)))

    ;; loop
    (set_local $w (i32.const 0))
    (block $done
      (loop $loop
        ;; word 0 ~ 15 will be used as-is on memory
        ;; word 16 ~ 79 will be calculated and replaced on memory
        (if
          ;; if 16 <= $w
          (i32.ge_s (get_local $w) (i32.const 16))

          ;; calculate word to use
          (call $set_word
            (get_local $w)
            ;; value = (words[w-3] ^ words[w-8] ^ words[w-14] ^ words[w-16]) rotl 1
            (i32.rotl
              (i32.xor
                (i32.xor
                  (call $get_word (i32.sub (get_local $w) (i32.const  3)))
                  (call $get_word (i32.sub (get_local $w) (i32.const  8)))
                )
                (i32.xor
                  (call $get_word (i32.sub (get_local $w) (i32.const 14)))
                  (call $get_word (i32.sub (get_local $w) (i32.const 16)))
                )
              )
              (i32.const 1)
            )
          )
        )

        ;; calculate f and determine k
        (block $get_key
          (if (i32.lt_s (get_local $w) (i32.const 20))
            (block
              ;; f = (b & c) | (~b & d)
              (set_local $f
                (i32.or
                  (i32.and (get_local $b) (get_local $c))
                  ;; ~a == a ^ 0xffffffff
                  (i32.and (i32.xor (get_local $b) (i32.const 0xffffffff)) (get_local $d))
                )
              )
              (set_local $k (i32.const 0x5a827999))
              (br $get_key)
            )
          )
          (if (i32.lt_s (get_local $w) (i32.const 40))
            (block
              ;; f = b ^ c ^ d
              (set_local $f
                (i32.xor
                  (i32.xor (get_local $b) (get_local $c))
                  (get_local $d)
                )
              )
              (set_local $k (i32.const 0x6ed9eba1))
              (br $get_key)
            )
          )
          (if (i32.lt_s (get_local $w) (i32.const 60))
            (block
              ;; f = (b & c) | (b & d) | (c & d)
              (set_local $f
                (i32.or
                  (i32.or
                    (i32.and (get_local $b) (get_local $c))
                    (i32.and (get_local $b) (get_local $d))
                  )
                  (i32.and (get_local $c) (get_local $d))
                )
              )
              (set_local $k (i32.const 0x8f1bbcdc))
              (br $get_key)
            )
          )
          (if (i32.lt_s (get_local $w) (i32.const 80))
            (block
              ;; f = b ^ c ^ d
              (set_local $f
                (i32.xor
                  (i32.xor (get_local $b) (get_local $c))
                  (get_local $d)
                )
              )
              (set_local $k (i32.const 0xca62c1d6))
              (br $get_key)
            )
          )
        )

        ;; t = a rotl 5 + f + e + k + words[w]
        (set_local $t
          (i32.add
            (i32.add
              (i32.add
                (i32.rotl (get_local $a) (i32.const 5))
                (get_local $f)
              )
              (i32.add
                (get_local $e)
                (get_local $k)
              )
            )
            (call $get_word (get_local $w))
          )
        )

        ;; rotate variables
        (set_local $e (get_local $d))
        (set_local $d (get_local $c))
        (set_local $c (i32.rotl (get_local $b) (i32.const 30)))
        (set_local $b (get_local $a))
        (set_local $a (get_local $t))

        ;; w += 1
        (set_local $w (i32.add (get_local $w) (i32.const 1)))

        ;; if 80 <= w, break
        (br_if $done (i32.ge_s (get_local $w) (i32.const 80)))

        ;; else, continue
        (br $loop)
      )
    )

    ;; feed to h0 ~ h4
    (i32.store
      (i32.const 0x44)
      (i32.add (get_local $a) (i32.load (i32.const 0x44)))
    )
    (i32.store
      (i32.const 0x48)
      (i32.add (get_local $b) (i32.load (i32.const 0x48)))
    )
    (i32.store
      (i32.const 0x4c)
      (i32.add (get_local $c) (i32.load (i32.const 0x4c)))
    )
    (i32.store
      (i32.const 0x50)
      (i32.add (get_local $d) (i32.load (i32.const 0x50)))
    )
    (i32.store
      (i32.const 0x54)
      (i32.add (get_local $e) (i32.load (i32.const 0x54)))
    )
  )

  ;; function `sha1_end`
  ;; input  - length of final chunk
  (func $sha1_end (param $final_len i32)
    (local $total_len i32)
    (local $i i32)

    ;; total_len = message_len + final_len
    (set_local $total_len (i32.add
      (i32.load (i32.const 0x0040))
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
        (call $sha1_update)

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
    (call $sha1_update)
  )
)
