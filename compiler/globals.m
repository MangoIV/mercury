%-----------------------------------------------------------------------------%
% Copyright (C) 1994-2000 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%

:- module globals.

% Main author: fjh.

% This module exports the `globals' type and associated access predicates.
% The globals type is used to collect together all the various data
% that would be global variables in an imperative language.
% This global data is stored in the io__state.

%-----------------------------------------------------------------------------%

:- interface.
:- import_module options.
:- import_module bool, getopt, list.

:- type globals.

:- type compilation_target
	--->	c	% Generate C code
	;	il	% Generate IL assembler code
			% IL is the Microsoft .NET Intermediate Language
	;	java.	% Generate Java
			% (this target is not yet implemented)

:- type gc_method
	--->	none
	;	conservative
	;	accurate.

:- type tags_method
	--->	none
	;	low
	;	high.

:- type prolog_dialect
	--->	default
	;	nu
	;	sicstus.

:- type termination_norm
	--->	simple
	;	total
	;	num_data_elems
	;	size_data_elems.

:- type trace_level.

:- pred convert_target(string::in, compilation_target::out) is semidet.
:- pred convert_gc_method(string::in, gc_method::out) is semidet.
:- pred convert_tags_method(string::in, tags_method::out) is semidet.
:- pred convert_prolog_dialect(string::in, prolog_dialect::out) is semidet.
:- pred convert_termination_norm(string::in, termination_norm::out) is semidet.
:- pred convert_trace_level(string::in, bool::in, trace_level::out) is semidet.
	% the bool should be the setting of the `require_tracing' option.

	% These functions check for various properties of the trace level.
:- func trace_level_is_none(trace_level) = bool.
:- func trace_level_needs_fixed_slots(trace_level) = bool.
:- func trace_level_needs_from_full_slot(trace_level) = bool.
:- func trace_level_needs_decl_debug_slots(trace_level) = bool.
:- func trace_level_needs_interface_events(trace_level) = bool.
:- func trace_level_needs_internal_events(trace_level) = bool.
:- func trace_level_needs_neg_context_events(trace_level) = bool.
:- func trace_level_needs_all_var_names(trace_level) = bool.
:- func trace_level_needs_proc_body_reps(trace_level) = bool.

%-----------------------------------------------------------------------------%

	% Access predicates for the `globals' structure.

:- pred globals__init(option_table::di, compilation_target::di, gc_method::di,
	tags_method::di, prolog_dialect::di, termination_norm::di,
	trace_level::di, globals::uo) is det.

:- pred globals__get_options(globals::in, option_table::out) is det.
:- pred globals__get_target(globals::in, compilation_target::out) is det.
:- pred globals__get_gc_method(globals::in, gc_method::out) is det.
:- pred globals__get_tags_method(globals::in, tags_method::out) is det.
:- pred globals__get_prolog_dialect(globals::in, prolog_dialect::out) is det.
:- pred globals__get_termination_norm(globals::in, termination_norm::out) 
	is det.
:- pred globals__get_trace_level(globals::in, trace_level::out) is det.

:- pred globals__set_options(globals::in, option_table::in, globals::out)
	is det.

:- pred globals__set_trace_level(globals::in, trace_level::in, globals::out)
	is det.
:- pred globals__set_trace_level_none(globals::in, globals::out) is det.

:- pred globals__lookup_option(globals::in, option::in, option_data::out)
	is det.

:- pred globals__lookup_bool_option(globals, option, bool).
:- mode globals__lookup_bool_option(in, in, out) is det.
:- mode globals__lookup_bool_option(in, in, in) is semidet. % implied
:- pred globals__lookup_int_option(globals::in, option::in, int::out) is det.
:- pred globals__lookup_string_option(globals::in, option::in, string::out)
	is det.
:- pred globals__lookup_accumulating_option(globals::in, option::in,
	list(string)::out) is det.

%-----------------------------------------------------------------------------%

	% More complex options

	% Check if static code addresses are available in the
	% current grade of compilation.

:- pred globals__have_static_code_addresses(globals::in, bool::out) is det.

	% Check if we should include variable information in the layout
	% structures of call return sites.

:- pred globals__want_return_var_layouts(globals::in, bool::out) is det.

%-----------------------------------------------------------------------------%

	% Access predicates for storing a `globals' structure in the
	% io__state using io__set_globals and io__get_globals.

:- pred globals__io_init(option_table::di, compilation_target::in,
	gc_method::in, tags_method::in, prolog_dialect::in,
	termination_norm::in, trace_level::in,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_target(compilation_target::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_gc_method(gc_method::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_tags_method(tags_method::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_prolog_dialect(prolog_dialect::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_termination_norm(termination_norm::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_trace_level(trace_level::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_get_globals(globals::out, io__state::di, io__state::uo)
	is det.

:- pred globals__io_set_globals(globals::di, io__state::di, io__state::uo)
	is det.

:- pred globals__io_set_option(option::in, option_data::in,
	io__state::di, io__state::uo) is det.

:- pred globals__io_set_trace_level(trace_level::in,
	io__state::di, io__state::uo) is det.

:- pred globals__io_set_trace_level_none(io__state::di, io__state::uo) is det.

:- pred globals__io_lookup_option(option::in, option_data::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_lookup_bool_option(option, bool, io__state, io__state).
:- mode globals__io_lookup_bool_option(in, out, di, uo) is det.
:- mode globals__io_lookup_bool_option(in, in, di, uo) is semidet. % implied

:- pred globals__io_lookup_int_option(option::in, int::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_lookup_string_option(option::in, string::out,
	io__state::di, io__state::uo) is det.

:- pred globals__io_lookup_accumulating_option(option::in, list(string)::out,
	io__state::di, io__state::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module exprn_aux.
:- import_module map, std_util, io, require.

	% XXX this should use the same language specification
	% strings as parse_foreign_language.
	% Also, we should probably just convert to lower case and then
	% test against known strings.
convert_target("java", java).
convert_target("Java", java).
convert_target("il", il).
convert_target("IL", il).
convert_target("c", c).
convert_target("C", c).

convert_gc_method("none", none).
convert_gc_method("conservative", conservative).
convert_gc_method("accurate", accurate).

convert_tags_method("none", none).
convert_tags_method("low", low).
convert_tags_method("high", high).

convert_prolog_dialect("default", default).
convert_prolog_dialect("nu", nu).
convert_prolog_dialect("NU", nu).
convert_prolog_dialect("nuprolog", nu).
convert_prolog_dialect("NUprolog", nu).
convert_prolog_dialect("nu-prolog", nu).
convert_prolog_dialect("NU-Prolog", nu).
convert_prolog_dialect("sicstus", sicstus).
convert_prolog_dialect("Sicstus", sicstus).
convert_prolog_dialect("SICStus", sicstus).
convert_prolog_dialect("sicstus-prolog", sicstus).
convert_prolog_dialect("Sicstus-Prolog", sicstus).
convert_prolog_dialect("SICStus-Prolog", sicstus).

convert_termination_norm("simple", simple).
convert_termination_norm("total", total).
convert_termination_norm("num-data-elems", num_data_elems).
convert_termination_norm("size-data-elems", size_data_elems).

convert_trace_level("minimum", no, none).
convert_trace_level("minimum", yes, shallow).
convert_trace_level("shallow", _, shallow).
convert_trace_level("deep", _, deep).
convert_trace_level("decl", _, decl).
convert_trace_level("rep", _, decl_rep).
convert_trace_level("default", no, none).
convert_trace_level("default", yes, deep).

:- type trace_level
	--->	none
	;	shallow
	;	deep
	;	decl
	;	decl_rep.

trace_level_is_none(none) = yes.
trace_level_is_none(shallow) = no.
trace_level_is_none(deep) = no.
trace_level_is_none(decl) = no.
trace_level_is_none(decl_rep) = no.

trace_level_needs_fixed_slots(none) = no.
trace_level_needs_fixed_slots(shallow) = yes.
trace_level_needs_fixed_slots(deep) = yes.
trace_level_needs_fixed_slots(decl) = yes.
trace_level_needs_fixed_slots(decl_rep) = yes.

trace_level_needs_from_full_slot(none) = no.
trace_level_needs_from_full_slot(shallow) = yes.
trace_level_needs_from_full_slot(deep) = no.
trace_level_needs_from_full_slot(decl) = no.
trace_level_needs_from_full_slot(decl_rep) = no.

trace_level_needs_decl_debug_slots(none) = no.
trace_level_needs_decl_debug_slots(shallow) = no.
trace_level_needs_decl_debug_slots(deep) = no.
trace_level_needs_decl_debug_slots(decl) = yes.
trace_level_needs_decl_debug_slots(decl_rep) = yes.

trace_level_needs_interface_events(none) = no.
trace_level_needs_interface_events(shallow) = yes.
trace_level_needs_interface_events(deep) = yes.
trace_level_needs_interface_events(decl) = yes.
trace_level_needs_interface_events(decl_rep) = yes.

trace_level_needs_internal_events(none) = no.
trace_level_needs_internal_events(shallow) = no.
trace_level_needs_internal_events(deep) = yes.
trace_level_needs_internal_events(decl) = yes.
trace_level_needs_internal_events(decl_rep) = yes.

trace_level_needs_neg_context_events(none) = no.
trace_level_needs_neg_context_events(shallow) = no.
trace_level_needs_neg_context_events(deep) = no.
trace_level_needs_neg_context_events(decl) = yes.
trace_level_needs_neg_context_events(decl_rep) = yes.

trace_level_needs_all_var_names(none) = no.
trace_level_needs_all_var_names(shallow) = no.
trace_level_needs_all_var_names(deep) = no.
trace_level_needs_all_var_names(decl) = yes.
trace_level_needs_all_var_names(decl_rep) = yes.

trace_level_needs_proc_body_reps(none) = no.
trace_level_needs_proc_body_reps(shallow) = no.
trace_level_needs_proc_body_reps(deep) = no.
trace_level_needs_proc_body_reps(decl) = no.
trace_level_needs_proc_body_reps(decl_rep) = yes.

%-----------------------------------------------------------------------------%

:- type globals
	--->	globals(
			options 		:: option_table,
			target 			:: compilation_target,
			gc_method 		:: gc_method,
			tags_method 		:: tags_method,
			prolog_dialect 		:: prolog_dialect,
			termination_norm 	:: termination_norm,
			trace_level 		:: trace_level
		).

globals__init(Options, Target, GC_Method, TagsMethod,
		PrologDialect, TerminationNorm, TraceLevel,
	globals(Options, Target, GC_Method, TagsMethod,
		PrologDialect, TerminationNorm, TraceLevel)).

globals__get_options(Globals, Globals ^ options).
globals__get_target(Globals, Globals ^ target).
globals__get_gc_method(Globals, Globals ^ gc_method).
globals__get_tags_method(Globals, Globals ^ tags_method).
globals__get_prolog_dialect(Globals, Globals ^ prolog_dialect).
globals__get_termination_norm(Globals, Globals ^ termination_norm).
globals__get_trace_level(Globals, Globals ^ trace_level).

globals__set_options(Globals, Options, Globals ^ options := Options).

globals__set_trace_level(Globals, TraceLevel,
	Globals ^ trace_level := TraceLevel).
globals__set_trace_level_none(Globals, Globals ^ trace_level := none).

globals__lookup_option(Globals, Option, OptionData) :-
	globals__get_options(Globals, OptionTable),
	map__lookup(OptionTable, Option, OptionData).

%-----------------------------------------------------------------------------%

globals__lookup_bool_option(Globals, Option, Value) :-
	globals__lookup_option(Globals, Option, OptionData),
	( OptionData = bool(Bool) ->
		Value = Bool
	;
		error("globals__lookup_bool_option: invalid bool option")
	).

globals__lookup_string_option(Globals, Option, Value) :-
	globals__lookup_option(Globals, Option, OptionData),
	( OptionData = string(String) ->
		Value = String
	;
		error("globals__lookup_string_option: invalid string option")
	).

globals__lookup_int_option(Globals, Option, Value) :-
	globals__lookup_option(Globals, Option, OptionData),
	( OptionData = int(Int) ->
		Value = Int
	;
		error("globals__lookup_int_option: invalid int option")
	).

globals__lookup_accumulating_option(Globals, Option, Value) :-
	globals__lookup_option(Globals, Option, OptionData),
	( OptionData = accumulating(Accumulating) ->
		Value = Accumulating
	;
		error("globals__lookup_accumulating_option: invalid accumulating option")
	).

%-----------------------------------------------------------------------------%

globals__have_static_code_addresses(Globals, IsConst) :-
	globals__get_options(Globals, OptionTable),
	globals__have_static_code_addresses_2(OptionTable, IsConst).

:- pred globals__have_static_code_addresses_2(option_table::in, 
	bool::out) is det.

globals__have_static_code_addresses_2(OptionTable, IsConst) :-
	getopt__lookup_bool_option(OptionTable, gcc_non_local_gotos,
		NonLocalGotos),
	getopt__lookup_bool_option(OptionTable, asm_labels, AsmLabels),
	exprn_aux__imported_is_constant(NonLocalGotos, AsmLabels, IsConst).

globals__want_return_var_layouts(Globals, WantReturnLayouts) :-
	% We need to generate layout info for call return labels
	% if we are using accurate gc or if the user wants uplevel printing.
	(
		(
			globals__get_gc_method(Globals, GC_Method),
			GC_Method = accurate
		;
			globals__lookup_bool_option(Globals, trace_return,
				TraceReturn),
			TraceReturn = yes,
			globals__get_trace_level(Globals, TraceLevel),
			TraceLevel \= none
		)
	->
		WantReturnLayouts = yes
	;
		WantReturnLayouts = no
	).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

globals__io_init(Options, Target, GC_Method, TagsMethod,
		PrologDialect, TerminationNorm, TraceLevel) -->
	{ copy(Target, Target1) },
	{ copy(GC_Method, GC_Method1) },
	{ copy(TagsMethod, TagsMethod1) },
	{ copy(PrologDialect, PrologDialect1) },
	{ copy(TerminationNorm, TerminationNorm1) },
	{ copy(TraceLevel, TraceLevel1) },
	{ globals__init(Options, Target1, GC_Method1, TagsMethod1,
		PrologDialect1, TerminationNorm1, TraceLevel1, Globals) },
	globals__io_set_globals(Globals).

globals__io_get_target(Target) -->
	globals__io_get_globals(Globals),
	{ globals__get_target(Globals, Target) }.

globals__io_get_gc_method(GC_Method) -->
	globals__io_get_globals(Globals),
	{ globals__get_gc_method(Globals, GC_Method) }.

globals__io_get_tags_method(Tags_Method) -->
	globals__io_get_globals(Globals),
	{ globals__get_tags_method(Globals, Tags_Method) }.

globals__io_get_prolog_dialect(PrologDIalect) -->
	globals__io_get_globals(Globals),
	{ globals__get_prolog_dialect(Globals, PrologDIalect) }.

globals__io_get_termination_norm(TerminationNorm) -->
	globals__io_get_globals(Globals),
	{ globals__get_termination_norm(Globals, TerminationNorm) }.

globals__io_get_trace_level(TraceLevel) -->
	globals__io_get_globals(Globals),
	{ globals__get_trace_level(Globals, TraceLevel) }.

globals__io_get_globals(Globals) -->
	io__get_globals(UnivGlobals),
	{
		univ_to_type(UnivGlobals, Globals0)
	->
		Globals = Globals0
	;
		error("globals__io_get_globals: univ_to_type failed")
	}.

globals__io_set_globals(Globals) -->
	{ type_to_univ(Globals, UnivGlobals) },
	io__set_globals(UnivGlobals).

%-----------------------------------------------------------------------------%

globals__io_lookup_option(Option, OptionData) -->
	globals__io_get_globals(Globals),
	{ globals__get_options(Globals, OptionTable) },
	{ map__lookup(OptionTable, Option, OptionData) }.

globals__io_set_option(Option, OptionData) -->
	globals__io_get_globals(Globals0),
	{ globals__get_options(Globals0, OptionTable0) },
	{ map__set(OptionTable0, Option, OptionData, OptionTable) },
	{ globals__set_options(Globals0, OptionTable, Globals1) },
		% XXX there is a bit of a design flaw with regard to
		% uniqueness and io__set_globals
	{ unsafe_promise_unique(Globals1, Globals) },
	globals__io_set_globals(Globals).

globals__io_set_trace_level(TraceLevel) -->
	globals__io_get_globals(Globals0),
	{ globals__set_trace_level(Globals0, TraceLevel, Globals1) },
	{ unsafe_promise_unique(Globals1, Globals) },
		% XXX there is a bit of a design flaw with regard to
		% uniqueness and io__set_globals
	globals__io_set_globals(Globals).

	% This predicate is needed because mercury_compile.m doesn't know
	% anything about type trace_level.
globals__io_set_trace_level_none -->
	globals__io_set_trace_level(none).

%-----------------------------------------------------------------------------%

globals__io_lookup_bool_option(Option, Value) -->
	globals__io_get_globals(Globals),
	{ globals__lookup_bool_option(Globals, Option, Value) }.

globals__io_lookup_int_option(Option, Value) -->
	globals__io_get_globals(Globals),
	{ globals__lookup_int_option(Globals, Option, Value) }.

globals__io_lookup_string_option(Option, Value) -->
	globals__io_get_globals(Globals),
	{ globals__lookup_string_option(Globals, Option, Value) }.

globals__io_lookup_accumulating_option(Option, Value) -->
	globals__io_get_globals(Globals),
	{ globals__lookup_accumulating_option(Globals, Option, Value) }.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
