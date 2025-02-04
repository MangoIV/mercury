%---------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%---------------------------------------------------------------------------%
%
% A test of uint16 to decimal string conversion.
%
%---------------------------------------------------------------------------%

:- module uint16_to_string.
:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- implementation.

:- import_module list.
:- import_module string.
:- import_module uint16.

%---------------------------------------------------------------------------%

main(!IO) :-
    P = (pred(U::in, !.IO::di, !:IO::uo) is det :-
        io.print_line(uint16_to_string(U), !IO)
    ),
    list.foldl(P, test_numbers, !IO).

:- func test_numbers = list(uint16).

test_numbers = [
    0u16,
    1u16,
    2u16,
    7u16,
    8u16,
    9u16,
    10u16,
    11u16,
    99u16,
    100u16,
    101u16,
    126u16,  % max_int8 - 1
    127u16,  % max_int8
    128u16,  % max_int8 + 1
    254u16,  % max_uint8 - 1
    255u16,  % max_uint8
    256u16,  % max_uint8 + 1
    999u16,
    1000u16,
    1001u16,
    9999u16,
    10000u16,
    10001u16,
    32766u16, % max_int16 - 1
    32767u16, % max_int16
    32768u16, % max_int16 + 1,
    65534u16, % max_uint16 - 1
    65535u16  % max_uint16
].

%---------------------------------------------------------------------------%
:- end_module uint16_to_string.
%---------------------------------------------------------------------------%
