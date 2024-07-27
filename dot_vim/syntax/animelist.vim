" Vim syntax file
" Language: animelist
" Maintainer: Emi
" License: This file can be redistribued and/or modified under the same terms
"   as Vim itself.
" Filenames: animelist*.txt
" Last Change: 2018-07-23
"
" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

" Catch-all
syntax match animelistError ".*"

" Processed Wishlist Entry
syntax match animelistWPStatus "^ *" nextgroup=animelistWPEpisodes
syntax match animelistWPStatus "^>>\? \+" nextgroup=animelistWPEpisodes
syntax match animelistWPStatus "^%%\? \+" nextgroup=animelistWPEpisodes
syntax match animelistWPEpisodes "\d\+|"he=e-1 nextgroup=animelistWPDate contained
syntax match animelistWPDate "\(\d\|?\)\{2\}\.\(\d\|?\)\{2\}\.\(\d\|?\)\{4\}|"he=e-1 nextgroup=animelistWPTitle contained
syntax match animelistWPTitle "[^|]\+" nextgroup=animelistWPMessage contained
syntax match animelistWPMessage "|[^|]\+$" contained

" Wishlist Entry
syntax match animelistWStatus "^\*\?\t" nextgroup=animelistWTitle
syntax match animelistWTitle "[^\t]*\S\t\{3\}" nextgroup=animelistWOrderId contained
syntax match animelistWOrderId "\d\+\t" nextgroup=animelistWEpisodes contained
syntax match animelistWEpisodes "\d\+/\d\+" nextgroup=animelistWSpecials contained
syntax match animelistWEpisodes "\d\+/TBC" nextgroup=animelistWSpecials contained
syntax match animelistWSpecials "\(+\d\+\)\?\t" nextgroup=animelistWDate contained
syntax match animelistWDate "\(\d\|?\)\{2\}\.\(\d\|?\)\{2\}\.\(\d\|?\)\{4\}\t" nextgroup=animelistWRating contained
syntax match animelistWDate "-\t" nextgroup=animelistWRating contained
syntax match animelistWRating "\d\+\.\d\+\s\+(\d\+)\t" nextgroup=animelistWMessage contained
syntax match animelistWRating "N/A\s\+(\d\+)\t" nextgroup=animelistWMessage contained
syntax match animelistWMessage "[^\t]*" contained

" Normal Entry Preamble type 1
syntax match animelistType "^\.\t\?" nextgroup=animelistStatus2
syntax match animelistStatus2 "+\?\t\?" nextgroup=animelistTitle contained

" Normal Entry Preamble type 2
syntax match animelistType "^[+-]?\?" nextgroup=animelistStorage
syntax match animelistStorage "\(H\?\t\)\?" nextgroup=animelistPointer contained
syntax match animelistPointer ">*" nextgroup=animelistStatus contained
syntax match animelistStatus "\.\?\*\?\t\?" nextgroup=animelistTitle contained

" Normal Entry Common
syntax match animelistTitle "[^\t]*\S\t" nextgroup=animelistEpisodes contained

syntax match animelistEpisodes "\d\+/\d\+" nextgroup=animelistSpecials contained
syntax match animelistSpecials "\(+\d\+\)\?\t" nextgroup=animelistWatched contained
syntax match animelistWatched "\d\+/\d\+\t" nextgroup=animelistDate contained

syntax match animelistDate "\d\{2\}\.\d\{2\}\.\d\{4\}\t" nextgroup=animelistRating contained
syntax match animelistRating "\d\+\.\d\+\s\+(\d\+)" contained

" Comment
syntax match animelistCmnt "^\s*#.*" contains=@Spell

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link animelistType       Type
hi def link animelistStorage    Conditional
hi def link animelistPointer    Todo
hi def link animelistStatus     Statement
hi def link animelistStatus2    Statement
hi def link animelistWStatus    Statement
hi def link animelistWPStatus   Statement

hi def link animelistTitle      Macro
hi def link animelistWTitle     Macro
hi def link animelistWPTitle    Macro

hi def link animelistWOrderId   Debug

hi def link animelistEpisodes   Boolean
hi def link animelistWEpisodes  Boolean
hi def link animelistWPEpisodes Number
hi def link animelistSpecials   Float
hi def link animelistWSpecials  Float
hi def link animelistWatched    Number

hi def link animelistDate       String
hi def link animelistWDate      String
hi def link animelistWPDate     String

hi def link animelistRating     Function
hi def link animelistWRating    Function

hi def link animelistWMessage   SpecialComment
hi def link animelistWPMessage  SpecialComment

hi def link animelistCmnt       Comment
hi def link animelistError      Error

let b:current_syntax = "animelist"

" vim: ts=8

