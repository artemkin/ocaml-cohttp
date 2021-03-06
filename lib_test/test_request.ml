open OUnit
open Printf
open Cohttp

module StringRequest = Request.Make(String_io.M)

let uri_userinfo = Uri.of_string "http://foo:bar@ocaml.org"

let header_auth =
  let h = Header.init () in
  let h = Header.add_authorization h (`Basic ("qux", "qwerty")) in
  h

let is_some = function
  | None -> false
  | Some _ -> true

let header_has_auth _ =
  assert_bool "Test header has auth"
    (header_auth |> Header.get_authorization |> is_some)

let uri_has_userinfo _ =
  assert_bool "Uri has user info" (uri_userinfo |> Uri.userinfo |> is_some)

let auth_uri_no_override _ =
  let r = Request.make ~headers:header_auth uri_userinfo in
  assert_equal
    (r |> Request.headers |> Header.get_authorization )
    (Header.get_authorization header_auth)

let auth_uri _ =
  let r = Request.make uri_userinfo in
  assert_equal
    (r |> Request.headers |> Header.get_authorization)
    (Some (`Basic ("foo", "bar")))

let opt_default default = function
  | None -> default
  | Some v -> v

let parse_request_uri_ r expected name =
  String_io.M.(
    StringRequest.read (String_io.open_in r)
    >>= fun result -> match result, expected with
    | `Ok { Request.uri = ruri }, `Ok uri ->
      let msg = Uri.(Printf.sprintf "expected %s %d %s %s\ngot %s %d %s %s"
                       (opt_default "_" (host uri))
                       (opt_default (-1) (port uri))
                       (path uri) (encoded_of_query (query uri))
                       (opt_default "_" (host ruri))
                       (opt_default (-1) (port ruri))
                       (path ruri) (encoded_of_query (query ruri))
                    )
      in
      assert_equal ~msg uri ruri
    | `Invalid rmsg, `Invalid msg ->
      assert_equal rmsg msg
    | _ -> assert_failure (name^" unexpected request parse result")
  )

let bad_request = `Invalid "bad request URI"

let parse_request_uri _ =
  let r = "GET / HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.of_string "/") in
  parse_request_uri_ r uri "parse_request_uri"

let parse_request_uri_host _ =
  let r = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com/") in
  parse_request_uri_ r uri "parse_request_uri_host"

let parse_request_uri_host_port _ =
  let r = "GET / HTTP/1.1\r\nHost: example.com:8080\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com:8080/") in
  parse_request_uri_ r uri "parse_request_uri_host_port"

let parse_request_uri_double_slash _ =
  let r = "GET // HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.with_path (Uri.of_string "") "//") in
  parse_request_uri_ r uri "parse_request_uri_double_slash"

let parse_request_uri_host_double_slash _ =
  let r = "GET // HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com//") in
  parse_request_uri_ r uri "parse_request_uri_host_double_slash"

let parse_request_uri_triple_slash _ =
  let r = "GET /// HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.with_path (Uri.of_string "") "///") in
  parse_request_uri_ r uri "parse_request_uri_triple_slash"

let parse_request_uri_host_triple_slash _ =
  let r = "GET /// HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com///") in
  parse_request_uri_ r uri "parse_request_uri_host_triple_slash"

let parse_request_uri_no_slash _ =
  let r = "GET foo HTTP/1.1\r\n\r\n" in
  parse_request_uri_ r bad_request "parse_request_uri_no_slash"

let parse_request_uri_host_no_slash _ =
  let r = "GET foo HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  parse_request_uri_ r bad_request "parse_request_uri_host_no_slash"

let parse_request_uri_empty _ =
  let r = "GET  HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.of_string "/") in
  parse_request_uri_ r uri "parse_request_uri_empty"

let parse_request_uri_host_empty _ =
  let r = "GET  HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com/") in
  parse_request_uri_ r uri "parse_request_uri_host_empty"

let parse_request_uri_path_like_scheme _ =
  let r = "GET http://example.net HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.of_string "http://example.net/") in
  parse_request_uri_ r uri "parse_request_uri_path_like_scheme"

let parse_request_uri_host_path_like_scheme _ =
  let r = "GET http://example.net HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string "http://example.net/") in
  parse_request_uri_ r uri "parse_request_uri_host_path_like_scheme"

let parse_request_uri_path_like_host_port _ =
  let path = "//example.net:8080" in
  let r = "GET "^path^" HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.with_path (Uri.of_string "") path) in
  parse_request_uri_ r uri "parse_request_uri_path_like_host_port"

let parse_request_uri_host_path_like_host_port _ =
  let path = "//example.net:8080" in
  let r = "GET "^path^" HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.with_path (Uri.of_string "//example.com") path) in
  parse_request_uri_ r uri "parse_request_uri_host_path_like_host_port"

let parse_request_uri_query _ =
  let pqs = "/?foo" in
  let r = "GET "^pqs^" HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.of_string pqs) in
  parse_request_uri_ r uri "parse_request_uri_query"

let parse_request_uri_host_query _ =
  let pqs = "/?foo" in
  let r = "GET "^pqs^" HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string ("//example.com"^pqs)) in
  parse_request_uri_ r uri "parse_request_uri_host_query"

let parse_request_uri_query_no_slash _ =
  let r = "GET ?foo HTTP/1.1\r\n\r\n" in
  parse_request_uri_ r bad_request "parse_request_uri_query_no_slash"

let parse_request_uri_host_query_no_slash _ =
  let r = "GET ?foo HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  parse_request_uri_ r bad_request "parse_request_uri_host_query_no_slash"

let parse_request_connect _ =
  let r = "CONNECT vpn.example.net:443 HTTP/1.1\r\n" in
  let uri = `Ok (Uri.of_string "//vpn.example.net:443") in
  parse_request_uri_ r uri "parse_request_connect"

let parse_request_connect_host _ =
  let r =
    "CONNECT vpn.example.net:443 HTTP/1.1\r\nHost: vpn.example.com:443\r\n\r\n"
  in
  let uri = `Ok (Uri.of_string "//vpn.example.net:443") in
  parse_request_uri_ r uri "parse_request_connect_host"

let parse_request_options _ =
  let r = "OPTIONS * HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.of_string "") in
  parse_request_uri_ r uri "parse_request_options"

let parse_request_options_host _ =
  let r = "OPTIONS * HTTP/1.1\r\nHost: example.com:443\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com:443") in
  parse_request_uri_ r uri "parse_request_options_host"

let parse_request_uri_traversal _ =
  let r = "GET /../../../../etc/shadow HTTP/1.1\r\n\r\n" in
  let uri = `Ok (Uri.of_string "/etc/shadow") in
  parse_request_uri_ r uri "parse_request_uri_traversal"

let parse_request_uri_host_traversal _ =
  let r = "GET /../../../../etc/shadow HTTP/1.1\r\nHost: example.com\r\n\r\n" in
  let uri = `Ok (Uri.of_string "//example.com/etc/shadow") in
  parse_request_uri_ r uri "parse_request_uri_host_traversal"

let _ =
  ("Request" >:::
   [ "Test header has auth" >:: header_has_auth
   ; "Test uri has user info" >:: uri_has_userinfo
   ; "Auth from Uri - do not override" >:: auth_uri_no_override
   ; "Auth from Uri" >:: auth_uri
   ; "Parse simple request URI" >:: parse_request_uri
   ; "Parse request URI with host" >:: parse_request_uri_host
   ; "Parse request URI with host and port" >:: parse_request_uri_host_port
   ; "Parse request URI double slash" >:: parse_request_uri_double_slash
   ; "Parse request URI double slash with host"
     >:: parse_request_uri_host_double_slash
   ; "Parse request URI triple slash" >:: parse_request_uri_triple_slash
   ; "Parse request URI triple slash with host"
     >:: parse_request_uri_host_triple_slash
   ; "Parse request URI no slash" >:: parse_request_uri_no_slash
   ; "Parse request URI no slash with host" >:: parse_request_uri_host_no_slash
   ; "Parse request URI empty" >:: parse_request_uri_empty
   ; "Parse request URI empty with host" >:: parse_request_uri_host_empty
   ; "Parse request URI path like scheme" >:: parse_request_uri_path_like_scheme
   ; "Parse request URI path like scheme with host"
     >:: parse_request_uri_host_path_like_scheme
   ; "Parse request URI path like host:port"
     >:: parse_request_uri_path_like_host_port
   ; "Parse request URI path like host:port with host"
     >:: parse_request_uri_host_path_like_host_port
   ; "Parse request URI with query string" >:: parse_request_uri_query
   ; "Parse request URI with query with host" >:: parse_request_uri_host_query
   ; "Parse request URI no slash with query string"
     >:: parse_request_uri_query_no_slash
   ; "Parse request URI no slash with query with host"
     >:: parse_request_uri_host_query_no_slash
   ; "Parse CONNECT request URI" >:: parse_request_connect
   ; "Parse CONNECT request URI with host" >:: parse_request_connect_host
   ; "Parse OPTIONS request URI" >:: parse_request_options
   ; "Parse OPTIONS request URI with host" >:: parse_request_options_host
   ; "Parse request URI parent traversal" >:: parse_request_uri_traversal
   ; "Parse request URI parent traversal with host"
     >:: parse_request_uri_host_traversal
   ]) |> run_test_tt_main
