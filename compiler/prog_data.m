%-----------------------------------------------------------------------------%
% Copyright (C) 1995 University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: prog_data.m.
% Main author: fjh.
%
% This module defines a data structure for representing Mercury programs.
%
% This data structure specifies basically the same information as is
% contained in the source code, but in a parse tree rather than a flat file.
% Simplifications are done only by make_hlds.m, which transforms
% the parse tree which we built here into the HLDS.

:- module prog_data.
:- interface.
:- import_module hlds_pred.
:- import_module string, int, list, varset, term, std_util, require.

%-----------------------------------------------------------------------------%

	% This is how programs (and parse errors) are represented.

:- type message_list	==	list(pair(string, term)).
				% the error/warning message, and the
				% term to which it relates

:- type program		--->	module(
					module_name,
					item_list
				).

:- type item_list	==	list(item_and_context).

:- type item_and_context ==	pair(item, term__context).

:- type item		--->	pred_clause(varset, sym_name, list(term), goal)
				%      VarNames, PredName, HeadArgs, ClauseBody
			;	func_clause(varset, sym_name, list(term), term,
						goal)
				%      VarNames, PredName, HeadArgs, Result,
				%      ClauseBody
			; 	type_defn(varset, type_defn, condition)
			; 	inst_defn(varset, inst_defn, condition)
			; 	mode_defn(varset, mode_defn, condition)
			; 	module_defn(varset, module_defn)
			; 	pred(varset, sym_name, list(type_and_mode),
					maybe(determinism), condition)
				%       VarNames, PredName, ArgTypes,
				%	Deterministicness, Cond
			; 	func(varset, sym_name, list(type_and_mode),
					type_and_mode,
					maybe(determinism), condition)
				%       VarNames, PredName, ArgTypes,
				%	ReturnType,
				%	Deterministicness, Cond
			; 	pred_mode(varset, sym_name, list(mode),
					maybe(determinism), condition)
				%       VarNames, PredName, ArgModes,
				%	Deterministicness, Cond
			; 	func_mode(varset, sym_name, list(mode), mode,
					maybe(determinism), condition)
				%       VarNames, PredName, ArgModes,
				%	ReturnValueMode,
				%	Deterministicness, Cond
			;	pragma(pragma_type)
			;	nothing.
				% used for items that should be ignored
				% (currently only NU-Prolog `when' declarations,
				% which are silently ignored for backwards
				% compatibility).

:- type type_and_mode	--->	type_only(type)
			;	type_and_mode(type, mode).

:- type pragma_type --->	c_header_code(string)
			;	c_code(string)
			;	c_code(sym_name, 
					list(pragma_var), varset, string)
				% PredName, Vars/Mode, VarNames, C Code
			;	memo(sym_name, int)
				% Predname, Arity
			;	inline(sym_name, int)
				% Predname, Arity
			;	obsolete(sym_name, int)
				% Predname, Arity
			;	export(sym_name, list(mode), string).
				% Predname, Modes, C Function

:- type pragma_var    --->	pragma_var(var, string, mode).
			  	% variable, name, mode
				% we explicitly store the name because we
				% need the real name in code_gen

%-----------------------------------------------------------------------------%

	% Here's how clauses and goals are represented.
	% a => b --> implies(a, b)
	% a <= b --> implies(b, a) [just flips the goals around!]
	% a <=> b --> equivalent(a, b)

% clause/4 defined above

:- type goal		==	pair(goal_expr, term__context).
:- type goal_expr	--->	(goal,goal)
			;	true	
					% could use conj(goals) instead 
			;	{goal;goal}	% {...} quotes ';'/2.
			;	fail	
					% could use disj(goals) instead
			;	not(goal)
			;	some(vars,goal)
			;	all(vars,goal)
			;	implies(goal,goal)
			;	equivalent(goal,goal)
			;	if_then(vars,goal,goal)
			;	if_then_else(vars,goal,goal,goal)
			;	call(sym_name, list(term))
			;	unify(term, term).

:- type goals		==	list(goal).
:- type vars		==	list(var).

%-----------------------------------------------------------------------------%

	% This is how types are represented.

			% one day we might allow types to take
			% value parameters as well as type parameters.

% type_defn/3 define above

:- type type_defn	--->	du_type(sym_name, list(type_param),
						list(constructor))
			;	uu_type(sym_name, list(type_param), list(type))
			;	eqv_type(sym_name, list(type_param), type)
			;	abstract_type(sym_name, list(type_param)).

:- type constructor	==	pair(sym_name, list(type)).

	% probably type parameters should be variables not terms.
:- type type_param	==	term.

:- type (type)		==	term.

:- type tvar		==	var.	% used for type variables
:- type tvarset		==	varset. % used for sets of type variables
:- type tsubst		==	map(tvar, type). % used for type substitutions

	% Types may have arbitrary assertions associated with them
	% (eg. you can define a type which represents sorted lists).
	% Similarly, pred declarations can have assertions attached.
	% The compiler will ignore these assertions - they are intended
	% to be used by other tools, such as the debugger.

:- type condition	--->	true
			;	where(term).

%-----------------------------------------------------------------------------%

	% This is how instantiatednesses and modes are represented.
	% Note that while we use the normal term data structure to represent 
	% type terms (see above), we need a separate data structure for inst 
	% terms.

% inst_defn/3 defined above

:- type inst_defn	--->	eqv_inst(sym_name, list(inst_param), inst)
			;	abstract_inst(sym_name, list(inst_param)).

	% probably inst parameters should be variables not terms
:- type inst_param	==	term.

:- type (inst)		--->	any(uniqueness)
			;	free
			;	free(type)
			;	bound(uniqueness, list(bound_inst))
					% The list(bound_inst) must be sorted
			;	ground(uniqueness, maybe(pred_inst_info))
					% The pred_inst_info is used for
					% higher-order pred modes
			;	not_reached
			;	inst_var(var)
			;	defined_inst(inst_name)
				% An abstract inst is a defined inst which
				% has been declared but not actually been
				% defined (yet).
			;	abstract_inst(sym_name, list(inst)).

:- type uniqueness
	--->		shared		% there might be other references
	;		unique		% there is only one reference
	;		mostly_unique	% there is only one reference
					% but there might be more on
					% backtracking
	;		clobbered	% this was the only reference, but
					% the data has already been reused
	;		mostly_clobbered.
					% this was the only reference, but
					% the data has already been reused;
					% however, there may be more references
					% on backtracking, so we will need to
					% restore the old value on backtracking

	% higher-order predicate terms are given the inst
	%	`ground(shared, yes(PredInstInfo))'
	% where the PredInstInfo contains the extra modes and the determinism
	% for the predicate.  Note that the higher-order predicate term
	% itself must be ground.

:- type pred_inst_info
	---> pred_inst_info(
			pred_or_func,		% is this a higher-order func
						% mode or a higher-order pred
						% mode?
			list(mode),		% the modes of the additional
						% (i.e. not-yet-supplied)
						% arguments of the pred;
						% for a function, this includes
						% the mode of the return value
						% as the last element of the
						% list.
			determinism 		% the determinism of the
						% predicate or function
	).

:- type bound_inst	--->	functor(cons_id, list(inst)).

:- type inst_name	--->	user_inst(sym_name, list(inst))
			;	merge_inst(inst, inst)
			;	unify_inst(is_live, inst, inst, unify_is_real)
			;	ground_inst(inst_name, is_live, uniqueness,
						unify_is_real)
			;	shared_inst(inst_name)
			;	mostly_uniq_inst(inst_name)
			;	typed_ground(uniqueness, type)
			;	typed_inst(type, inst_name).

:- type is_live		--->	live ; dead.

	% Unifications of insts fall into two categories, "real" and "fake".
	% The "real" inst unifications correspond to real unifications,
	% and are not allowed to unify with `clobbered' insts.
	% "Fake" inst unifications are used for procedure calls in implied
	% modes, where the final inst of the var must be computed by
	% unifying its initial inst with the procedure's final inst,
	% so that if you pass a ground var to a procedure whose mode
	% is `free -> list_skeleton', the result is ground, not list_skeleton.
	% But these fake unifications must be allowed to unify with `clobbered'
	% insts. Hence we pass down a flag to `abstractly_unify_inst' which
	% specifies whether or not to allow unifications with clobbered values.

:- type unify_is_real
	--->	real_unify
	;	fake_unify.

% mode_defn/3 defined above

:- type mode_defn	--->	eqv_mode(sym_name, list(inst_param), mode).

:- type (mode)		--->	((inst) -> (inst))
			;	user_defined_mode(sym_name, list(inst)).

% mode/4 defined above

%-----------------------------------------------------------------------------%

	% This is how module-system declarations (such as imports
	% and exports) are represented.

:- type module_defn	--->	module(module_name)
			;	interface
			;	implementation
			;	imported
				% this is used internally by the compiler,
				% to identify declarations which originally
				% came from some other module
			;	external(sym_name_specifier)
			;	end_module(module_name)
			;	export(sym_list)
			;	import(sym_list)
			;	use(sym_list).
:- type sym_list	--->	sym(list(sym_specifier))
			;	pred(list(pred_specifier))
			;	func(list(func_specifier))
			;	cons(list(cons_specifier))
			;	op(list(op_specifier))
			;	adt(list(adt_specifier))
	 		;	type(list(type_specifier))
	 		;	module(list(module_specifier)).
:- type sym_specifier	--->	sym(sym_name_specifier)
			;	typed_sym(typed_cons_specifier)
			;	pred(pred_specifier)
			;	func(func_specifier)
			;	cons(cons_specifier)
			;	op(op_specifier)
			;	adt(adt_specifier)
	 		;	type(type_specifier)
	 		;	module(module_specifier).
:- type pred_specifier	--->	sym(sym_name_specifier)
			;	name_args(sym_name, list(type)).
:- type func_specifier	==	cons_specifier.
:- type cons_specifier	--->	sym(sym_name_specifier)
			;	typed(typed_cons_specifier).
:- type typed_cons_specifier --->	
				name_args(sym_name, list(type))
			;	name_res(sym_name_specifier, type)
			;	name_args_res(sym_name,
						list(type), type).
:- type adt_specifier	==	sym_name_specifier.
:- type type_specifier	==	sym_name_specifier.
:- type op_specifier	--->	sym(sym_name_specifier)
			% operator fixity specifiers not yet implemented
			;	fixity(sym_name_specifier, fixity).
:- type fixity		--->	infix ; prefix ; postfix ;
				binary_prefix ; binary_postfix.
:- type sym_name_specifier ---> name(sym_name)
			;	name_arity(sym_name, arity).
:- type sym_name 	--->	unqualified(string)
			;	qualified(module_specifier, string).

:- type module_specifier ==	string.
:- type module_name 	== 	string.
:- type arity		==	int.

%-----------------------------------------------------------------------------%
