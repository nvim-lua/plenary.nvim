# Popup tracking

[WIP] An implementation of the Popup API from vim in Neovim. Hope to upstream
when complete

## Goals

Provide an API that is compatible with the vim `popup_*` APIs. After
stablization and any required features are merged into Neovim, we can upstream
this and expose the API in vimL to create better compatibility.

## Notices
- **2024-09-19:** change `enter` default to false to follow Vim.
- **2021-09-19:** we now follow Vim's convention of the first line/column of the screen being indexed 1, so that 0 can be used for centering.
- **2021-08-19:** we now follow Vim's default to `noautocmd` on popup creation. This can be overriden with `vim_options.noautocmd=false`

## List of Neovim Features Required:

- [ ] Key handlers (used for `popup_filter`)
- [ ] scrollbar for floating windows
    - [ ] scrollbar
    - [ ] scrollbarhighlight
    - [ ] thumbhighlight

Optional:

- [ ] Add forced transparency to a floating window.
    - Apparently overrides text?
    - This is for the `mask` feature flag


Unlikely (due to technical difficulties):

- [ ] Add `textprop` wrappers?
    - textprop
    - textpropwin
    - textpropid

Unlikely (due to not sure if people are using):
- [ ] tabpage

## Progress

Suported Functions:

- [x] popup.create
- [x] popup.move
- [ ] popup.close
- [ ] popup.clear


Suported Features:

- [x] what
    - string
    - list of strings
    - bufnr
- [x] popup_create-arguments
    - [x] border
    - [x] borderchars
    - [x] col
    - [x] cursorline
    - [x] highlight
    - [x] line
    - [x] {max,min}{height,width}
    - [?] moved
        - [x] "any"
        - [ ] "word"
        - [ ] "WORD"
        - [ ] "expr"
        - [ ] (list options)
    - [x] padding
    - [?] pos
        - Somewhat implemented. Doesn't work with borders though.
    - [x] posinvert
    - [x] time
    - [x] title
    - [x] wrap
    - [x] zindex
    - [x] callback
    - [ ] mousemoved
        - [ ] "any"
        - [ ] "word"
        - [ ] "WORD"
        - [ ] "expr"
        - [ ] (list options)
    - [?] close
        - [ ] "button"
        - [ ] "click"
        - [x] "none"


Additional Features:

- [x] enter
- [x] focusable
- [x] noautocmd
- [x] finalize_callback

## All known unimplemented vim features at the moment

- firstline
- hidden
- ~ pos
- fixed
- filter
- filtermode
- mapping
- mouse:
    - drag
    - resize

- (not implemented in vim yet) flip
