open Yocaml

let pp_act ppf s =
  Format.fprintf
    ppf
    "%s"
    (match s with
    | `Need_creation -> "`Need_creation"
    | `Need_update -> "`Need_update"
    | `Up_to_date -> "`Up_to_date")
;;

let eq_act a b =
  match a, b with
  | `Need_update, `Need_update
  | `Need_creation, `Need_creation
  | `Up_to_date, `Up_to_date -> true
  | _ -> false
;;

let testable_act = Alcotest.testable pp_act eq_act

let need_update_no_deps_file_not_present =
  let open Alcotest in
  test_case "When the file has no dependencies but does not exists" `Quick
  $ fun () ->
  let dummy = Dummy.make () in
  let deps = Deps.empty in
  let target = "my-file.txt" in
  let expected = Try.ok `Need_creation in
  let computed = Dummy.handle dummy $ Deps.need_update deps target in
  check
    (result testable_act (testable Error.pp Error.equal))
    "since the filesystem is empty, the file need to be updated"
    expected
    computed
;;

let need_update_no_deps_file_present =
  let open Alcotest in
  test_case "When the file has no dependencies but does exists" `Quick
  $ fun () ->
  let dummy =
    Dummy.(
      make
        ~filesystem:[ file ~mtime:1 ~content:"my-content" "my-file.txt" ]
        ())
  in
  let deps = Deps.empty in
  let target = "my-file.txt" in
  let expected = Try.ok `Up_to_date in
  let computed = Dummy.handle dummy $ Deps.need_update deps target in
  check
    (result testable_act (testable Error.pp Error.equal))
    "The target has no dependencies and exists in the file system, so it \
     does not need to be updated"
    expected
    computed
;;

let need_update_updated_deps_file_present =
  let open Alcotest in
  test_case "When the file has dependencies but they are up to date" `Quick
  $ fun () ->
  let dummy =
    Dummy.(
      make
        ~filesystem:
          [ file ~mtime:10 ~content:"my-content" "my-file.txt"
          ; file ~mtime:1 ~content:"content" "deps1.html"
          ; file ~mtime:2 ~content:"content" "deps2.html"
          ; file ~mtime:3 ~content:"content" "deps3.html"
          ]
        ())
  in
  let deps =
    Deps.(of_list [ file "deps1.html"; file "deps2.html"; file "deps3.html" ])
  in
  let target = "my-file.txt" in
  let expected = Try.ok `Up_to_date in
  let computed = Dummy.handle dummy $ Deps.need_update deps target in
  check
    (result testable_act (testable Error.pp Error.equal))
    "The target has dependencies but they are all up to date, so it should \
     not be updated"
    expected
    computed
;;

let need_update_outatded_deps_file_present =
  let open Alcotest in
  test_case "When the file has dependencies and they are out of date" `Quick
  $ fun () ->
  let dummy =
    Dummy.(
      make
        ~filesystem:
          [ file ~mtime:10 ~content:"my-content" "my-file.txt"
          ; file ~mtime:1 ~content:"content" "deps1.html"
          ; file ~mtime:12 ~content:"content" "deps2.html"
          ; file ~mtime:3 ~content:"content" "deps3.html"
          ]
        ())
  in
  let deps =
    Deps.(of_list [ file "deps1.html"; file "deps2.html"; file "deps3.html" ])
  in
  let target = "my-file.txt" in
  let expected = Try.ok `Need_update in
  let computed = Dummy.handle dummy $ Deps.need_update deps target in
  check
    (result testable_act (testable Error.pp Error.equal))
    "The target has dependencies but some are out of date, so it should not \
     be updated"
    expected
    computed
;;

let cases =
  ( "Deps"
  , [ need_update_no_deps_file_not_present
    ; need_update_no_deps_file_present
    ; need_update_updated_deps_file_present
    ; need_update_outatded_deps_file_present
    ] )
;;
