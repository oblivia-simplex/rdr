(* TODO: implement a "byte accountant", which determines percent of known inert/or flagged bytes, and remainder is unknown data/code *)

module Header = ElfHeader
module ProgramHeader = ElfProgramHeader
module SectionHeader = ElfSectionHeader
module Reloc = ElfReloc
module Constants = ElfConstants
module Dynamic = ElfDynamic                        
module SymbolTable = ElfSymbolTable

open ByteCoverage

type t = {
  header: Header.t;
  program_headers: ProgramHeader.t;
  section_headers: SectionHeader.t;
  _dynamic: Dynamic.t;
  dynamic_symbols: SymbolTable.t;
  symbol_table: SymbolTable.t;
  relocations: Reloc.t;
  is_lib: bool;
  soname: string;
  interpreter: string;
  libraries: string list;
  size: int;
  raw_code: bytes;              (* list *)
}

let compute_byte_coverage h phs shs = 
  let leading_meta_size = 
    h.Header.e_ehsize + 
    (h.Header.e_phentsize * h.Header.e_phnum) 
  in
  let interp = if (not @@ ProgramHeader.is_empty phs) then
      match ProgramHeader.get_interpreter_header phs with
      | Some ph ->
        (
          fun m -> 
            let size = ph.ProgramHeader.p_filesz in
            let range_start = ph.ProgramHeader.p_offset in
            let range_end = size + range_start in
            ByteCoverage.Map.add range_start
              {size; kind = String; 
               range_start; range_end; 
               extra = "interp"} m
        )
      | None ->
        (fun m -> m)
    else
      (fun m -> m)
  in
  let section_headers = 
    if (not @@ SectionHeader.is_empty shs) then
      (
        fun m -> 
          let size = h.Header.e_shentsize * h.Header.e_shnum in
          let range_start = h.Header.e_shoff in
          let range_end = size + range_start in
          ByteCoverage.Map.add range_start
            {size; 
             kind = Meta; 
             range_start; range_end; 
             extra = "section headers"} m
      )
    else
      (fun m -> m)
  in
  let m =
    ByteCoverage.Map.add 0 
      {size = leading_meta_size; 
       kind = Meta; range_start = 0; 
       range_end = leading_meta_size; 
       extra = "header + program headers"} 
      ByteCoverage.Map.empty
  |>  interp |> section_headers in m

let get ?meta_only:(meta_only=false) binary =
  let header = Header.get_elf_header64 binary in
  let program_headers =
    ProgramHeader.get_program_headers
      binary
      header.Header.e_phoff
      header.Header.e_phentsize
      header.Header.e_phnum
  in
  let interpreter = ProgramHeader.get_interpreter binary program_headers in
  let slide_sectors =
    ProgramHeader.get_slide_sectors program_headers
  in
  let section_headers =
    SectionHeader.get_section_headers
      binary
      header.Header.e_shoff
      header.Header.e_shentsize
      header.Header.e_shnum
  in
  let size = Bytes.length binary in
  let is_lib = (Header.is_lib header) in
  let symbol_table = SymbolTable.get_symbol_table binary section_headers in
  let _dynamic = Dynamic.get_dynamic binary program_headers in
  let symtab_offset, strtab_offset, strtab_size =
    Dynamic.get_dynamic_symbol_offset_data _dynamic slide_sectors
  in
  let dynamic_strtab =
    Dynamic.get_dynamic_strtab binary strtab_offset strtab_size
  in
  let libraries = Dynamic.get_libraries _dynamic dynamic_strtab in
  let dynamic_symbols =
    Dynamic.get_dynamic_symbols
      binary
      slide_sectors
      symtab_offset
      strtab_offset
      strtab_size
  in
  let soname =
    try
      let offset = Dynamic.get_soname_offset _dynamic in
      Binary.string binary (strtab_offset + offset)
    with Not_found -> "" (* we're not a dylib *)
  in
  let relocations =
    Dynamic.get_reloc_data _dynamic slide_sectors
    |> Reloc.get_relocs64 binary
  in
  let byte_coverage = compute_byte_coverage header program_headers section_headers in 
  Printf.printf "Coverage: %d / %d = %f\n" (ByteCoverage.total_coverage byte_coverage) size @@ ByteCoverage.percent byte_coverage size;
  (* TODO: fix *)
  let raw_code = if (meta_only) then
      Bytes.create 0 
    else
      Bytes.create 0 in
  {
    header;
    program_headers;
    section_headers;
    size;
    _dynamic;
    dynamic_symbols;
    symbol_table;
    relocations;
    is_lib;
    soname;
    interpreter;
    libraries;
    raw_code;
  }

let print elf = 
  Header.print_elf_header64 ~verbose:true elf.header;
  ProgramHeader.print_program_headers elf.program_headers;
  SectionHeader.print_section_headers elf.section_headers;
  Dynamic.print_dynamic elf._dynamic;
  SymbolTable.print_symbol_table elf.dynamic_symbols;
  SymbolTable.print_symbol_table elf.symbol_table;
  Reloc.print_relocs64 elf.relocations
