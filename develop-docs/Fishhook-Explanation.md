# Explanation of how a Fishhook works

> [!NOTE]
> This is copied from https://github.com/facebook/fishhook in case the repository gets removed.

## How it works

`dyld` binds lazy and non-lazy symbols by updating pointers in particular sections of the `__DATA` segment of a Mach-O binary. **fishhook** re-binds these symbols by determining the locations to update for each of the symbol names passed to `rebind_symbols` and then writing out the corresponding replacements.

For a given image, the `__DATA` segment may contain two sections that are relevant for dynamic symbol bindings: `__nl_symbol_ptr` and `__la_symbol_ptr`. `__nl_symbol_ptr` is an array of pointers to non-lazily bound data (these are bound at the time a library is loaded) and `__la_symbol_ptr` is an array of pointers to imported functions that is generally filled by a routine called `dyld_stub_binder` during the first call to that symbol (it's also possible to tell `dyld` to bind these at launch). In order to find the name of the symbol that corresponds to a particular location in one of these sections, we have to jump through several layers of indirection. For the two relevant sections, the section headers (`struct section`s from `<mach-o/loader.h>`) provide an offset (in the `reserved1` field) into what is known as the indirect symbol table. The indirect symbol table, which is located in the `__LINKEDIT` segment of the binary, is just an array of indexes into the symbol table (also in `__LINKEDIT`) whose order is identical to that of the pointers in the non-lazy and lazy symbol sections. So, given `struct section nl_symbol_ptr`, the corresponding index in the symbol table of the first address in that section is `indirect_symbol_table[nl_symbol_ptr->reserved1]`. The symbol table itself is an array of `struct nlist`s (see `<mach-o/nlist.h>`), and each `nlist` contains an index into the string table in `__LINKEDIT` which where the actual symbol names are stored. So, for each pointer `__nl_symbol_ptr` and `__la_symbol_ptr`, we are able to find the corresponding symbol and then the corresponding string to compare against the requested symbol names, and if there is a match, we replace the pointer in the section with the replacement.

The process of looking up the name of a given entry in the lazy or non-lazy pointer tables looks like this:
![Visual explanation](./fishhook-symbol-tables.png)
