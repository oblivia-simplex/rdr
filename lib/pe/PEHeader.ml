open Binary
       
type dos_header =
  {
    signature: int [@size 2]; (* 5a4d *)
    pe_pointer: int [@size 4];  (* at offset 0x3c *)
  }

let pp_dos_header ppf dos =
  Format.fprintf ppf "@[DOS@ %x@ PE -> 0x%x@]"
    dos.signature
    dos.pe_pointer

let kDOS_MAGIC = 0x5a4d
let kDOS_CIGAM = 0x4d5a
let kPE_POINTER_OFFSET = 0x3c

(* COFF Header *)
type coff_header =
  {
    signature: int [@size 4, be]; (* 0x50450000 *)
    machine: int [@size 2];
    number_of_sections: int [@size 2];
    time_date_stamp: int [@size 4];
    pointer_to_symbol_table: int [@size 4];
    number_of_symbol_table: int [@size 4];
    size_of_optional_header: int [@size 2];
    characteristics: int [@size 2];
  }

let sizeof_coff_header = 24     (* bytes *)
let kCOFF_MAGIC = 0x50450000

let pp_coff_header ppf coff =
  Format.fprintf ppf
    "@[<v 2>@[<h>COFF@ 0x%x@]@ Machine: 0x%x@ NumberOfSections: %d@ TimeDateStamp: %d@ PointerToSymbolTable: 0x%x@ NumberOfSymbolTable: %d@ SizeOfOptionalHeader: 0x%x@ Characteristics: 0x%x@]"
    coff.signature
    coff.machine
    coff.number_of_sections
    coff.time_date_stamp
    coff.pointer_to_symbol_table
    coff.number_of_symbol_table
    coff.size_of_optional_header
    coff.characteristics

type t = {
    dos_header: dos_header;
    coff_header: coff_header;
    optional_header: PEOptionalHeader.t option;
  }

let pp ppf t =
  Format.fprintf ppf "@[<v 2>@ ";
  pp_dos_header ppf t.dos_header;
  Format.fprintf ppf "@ ";
  pp_coff_header ppf t.coff_header;
  begin
    match t.optional_header with
    | Some header ->
      PEOptionalHeader.pp ppf header;
    | None ->
      Format.fprintf ppf "@ **No Optional Headers**"
  end;
  Format.fprintf ppf "@]"

let show t =
  pp Format.str_formatter t;
  Format.flush_str_formatter()

let print t =
  pp Format.std_formatter t;
  Format.print_newline()

let get_dos_header binary offset :dos_header =
  let signature,o = Binary.u16o binary offset in
  let pe_pointer = Binary.u32 binary (offset+kPE_POINTER_OFFSET) in
  {signature;pe_pointer;}

let get_coff_header binary offset :coff_header =
  let signature,o = Binary.u32o binary offset in
  let machine,o = Binary.u16o binary o in
  let number_of_sections,o = Binary.u16o binary o in
  let time_date_stamp,o = Binary.u32o binary o in
  let pointer_to_symbol_table,o = Binary.u32o binary o in
  let number_of_symbol_table,o = Binary.u32o binary o in
  let size_of_optional_header,o = Binary.u16o binary o in
  let characteristics = Binary.u16 binary o in
  {signature;machine;number_of_sections;time_date_stamp;pointer_to_symbol_table;number_of_symbol_table;size_of_optional_header;characteristics;}

let get_header binary =
  let dos_header = get_dos_header binary 0 in
  let coff_header_offset = dos_header.pe_pointer in
  let coff_header = get_coff_header binary coff_header_offset in
  let optional_offset = sizeof_coff_header + coff_header_offset in
  let optional_header =
    if (coff_header.size_of_optional_header > 0) then
      Some (PEOptionalHeader.get binary optional_offset)
    else
      None
  in
  {dos_header; coff_header;optional_header;}

let csrss_header = get_header @@ list_to_bytes [0x4d; 0x5a; 0x90; 0x00; 0x03; 0x00; 0x00; 0x00; 0x04; 0x00; 0x00; 0x00; 0xff; 0xff; 0x00; 0x00;
0xb8; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0xd0; 0x00; 0x00; 0x00;
0x0e; 0x1f; 0xba; 0x0e; 0x00; 0xb4; 0x09; 0xcd; 0x21; 0xb8; 0x01; 0x4c; 0xcd; 0x21; 0x54; 0x68;
0x69; 0x73; 0x20; 0x70; 0x72; 0x6f; 0x67; 0x72; 0x61; 0x6d; 0x20; 0x63; 0x61; 0x6e; 0x6e; 0x6f;
0x74; 0x20; 0x62; 0x65; 0x20; 0x72; 0x75; 0x6e; 0x20; 0x69; 0x6e; 0x20; 0x44; 0x4f; 0x53; 0x20;
0x6d; 0x6f; 0x64; 0x65; 0x2e; 0x0d; 0x0d; 0x0a; 0x24; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0xaa; 0x4a; 0xc3; 0xeb; 0xee; 0x2b; 0xad; 0xb8; 0xee; 0x2b; 0xad; 0xb8; 0xee; 0x2b; 0xad; 0xb8;
0xee; 0x2b; 0xac; 0xb8; 0xfe; 0x2b; 0xad; 0xb8; 0x33; 0xd4; 0x66; 0xb8; 0xeb; 0x2b; 0xad; 0xb8;
0x33; 0xd4; 0x63; 0xb8; 0xea; 0x2b; 0xad; 0xb8; 0x33; 0xd4; 0x7a; 0xb8; 0xed; 0x2b; 0xad; 0xb8;
0x33; 0xd4; 0x64; 0xb8; 0xef; 0x2b; 0xad; 0xb8; 0x33; 0xd4; 0x61; 0xb8; 0xef; 0x2b; 0xad; 0xb8;
0x52; 0x69; 0x63; 0x68; 0xee; 0x2b; 0xad; 0xb8; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x50; 0x45; 0x00; 0x00; 0x4c; 0x01; 0x05; 0x00; 0xd9; 0x8f; 0x15; 0x52; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0xe0; 0x00; 0x02; 0x01; 0x0b; 0x01; 0x0b; 0x00; 0x00; 0x08; 0x00; 0x00;
0x00; 0x10; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x10; 0x11; 0x00; 0x00; 0x00; 0x10; 0x00; 0x00;
0x00; 0x20; 0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0x10; 0x00; 0x00; 0x00; 0x02; 0x00; 0x00;
0x06; 0x00; 0x03; 0x00; 0x06; 0x00; 0x03; 0x00; 0x06; 0x00; 0x03; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x60; 0x00; 0x00; 0x00; 0x04; 0x00; 0x00; 0xe4; 0xab; 0x00; 0x00; 0x01; 0x00; 0x40; 0x05;
0x00; 0x00; 0x04; 0x00; 0x00; 0x30; 0x00; 0x00; 0x00; 0x00; 0x10; 0x00; 0x00; 0x10; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x10; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x3c; 0x30; 0x00; 0x00; 0x3c; 0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0x00; 0x08; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x1a; 0x00; 0x00; 0xb8; 0x22; 0x00; 0x00;
0x00; 0x50; 0x00; 0x00; 0x38; 0x00; 0x00; 0x00; 0x10; 0x10; 0x00; 0x00; 0x38; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x68; 0x10; 0x00; 0x00; 0x5c; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x30; 0x00; 0x00; 0x3c; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x2e; 0x74; 0x65; 0x78; 0x74; 0x00; 0x00; 0x00;
0x24; 0x06; 0x00; 0x00; 0x00; 0x10; 0x00; 0x00; 0x00; 0x08; 0x00; 0x00; 0x00; 0x04; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x20; 0x00; 0x00; 0x60;
0x2e; 0x64; 0x61; 0x74; 0x61; 0x00; 0x00; 0x00; 0x3c; 0x03; 0x00; 0x00; 0x00; 0x20; 0x00; 0x00;
0x00; 0x02; 0x00; 0x00; 0x00; 0x0c; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0xc0; 0x2e; 0x69; 0x64; 0x61; 0x74; 0x61; 0x00; 0x00;
0xf8; 0x01; 0x00; 0x00; 0x00; 0x30; 0x00; 0x00; 0x00; 0x02; 0x00; 0x00; 0x00; 0x0e; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0x40;
0x2e; 0x72; 0x73; 0x72; 0x63; 0x00; 0x00; 0x00; 0x00; 0x08; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00;
0x00; 0x08; 0x00; 0x00; 0x00; 0x10; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0x42; 0x2e; 0x72; 0x65; 0x6c; 0x6f; 0x63; 0x00; 0x00;
0x86; 0x01; 0x00; 0x00; 0x00; 0x50; 0x00; 0x00; 0x00; 0x02; 0x00; 0x00; 0x00; 0x18; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x40; 0x00; 0x00; 0x42;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;
0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00; 0x00;]

let to_hex hex = Printf.printf "0x%x\n" hex
