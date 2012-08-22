(*
 * Copyright (c) 2012 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

module IO = struct

  type 'a t = 'a Lwt.t
  let (>>=) = Lwt.bind
  let return = Lwt.return

  type ic = Lwt_io.input_channel
  type oc = Lwt_io.output_channel

  let iter fn x = Lwt_list.iter_s fn x

  let read_line ic = Lwt_io.read_line_opt ic
  let read ic count = 
   try_lwt Lwt_io.read ~count ic
   with End_of_file -> return ""

  let read_exactly ic buf off len =
    try_lwt Lwt_io.read_into_exactly ic buf off len >> return true
    with End_of_file -> return false

  let write oc buf = Lwt_io.write oc buf
  let write_line oc buf = Lwt_io.write_line oc buf
end

module Body  = Transfer.Make(IO)
module Request = Request.Make(IO)
module Response = Response.Make(IO)