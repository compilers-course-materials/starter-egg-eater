open Compile
open Runner
open Printf
open OUnit2

let t name program expected = name>::test_run program name expected;;
let tvg name program expected = name>::test_run_valgrind program name expected;;
let terr name program expected = name>::test_err program name expected;;


let suite =
"suite">:::[]



let () =
  run_test_tt_main suite
;;

