%-----------------------------------------------------------------------------%
% Copyright (C) 1995-1999 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%

% Main author: conway.
%
% This module provides some functionality for renaming variables in goals.
% The predicates rename_var* take a structure and a mapping from var -> var
% and apply that translation. If a var in the input structure does not
% occur as a key in the mapping, then the variable is left unsubstituted.

% goal_util__create_variables takes a list of variables, a varset an
% initial translation mapping and an initial mapping from variable to
% type, and creates new instances of each of the source variables in the
% translation mapping, adding the new variable to the type mapping and
% updating the varset. The type for each new variable is found by looking
% in the type map given in the 5th argument - the last input.
% (This interface will not easily admit uniqueness in the type map for this
% reason - such is the sacrifice for generality.)

:- module goal_util.

%-----------------------------------------------------------------------------%

:- interface.

:- import_module hlds_data, hlds_goal, hlds_module, hlds_pred.
:- import_module instmap, prog_data.
:- import_module bool, list, set, map, term.

	% goal_util__rename_vars_in_goals(GoalList, MustRename, Substitution,
	%	NewGoalList).
:- pred goal_util__rename_vars_in_goals(list(hlds_goal), bool,
		map(prog_var, prog_var), list(hlds_goal)).
:- mode goal_util__rename_vars_in_goals(in, in, in, out) is det.

:- pred goal_util__rename_vars_in_goal(hlds_goal, map(prog_var, prog_var),
		hlds_goal).
:- mode goal_util__rename_vars_in_goal(in, in, out) is det.

:- pred goal_util__must_rename_vars_in_goal(hlds_goal,
		map(prog_var, prog_var), hlds_goal).
:- mode goal_util__must_rename_vars_in_goal(in, in, out) is det.

:- pred goal_util__rename_var_list(list(var(T)), bool,
		map(var(T), var(T)), list(var(T))).
:- mode goal_util__rename_var_list(in, in, in, out) is det.

	% goal_util__create_variables(OldVariables, OldVarset, InitialVarTypes,
	%	InitialSubstitution, OldVarTypes, OldVarNames,  NewVarset,
	%	NewVarTypes, NewSubstitution)
:- pred goal_util__create_variables(list(prog_var),
			prog_varset, map(prog_var, type),
			map(prog_var, prog_var),
			map(prog_var, type),
			prog_varset, prog_varset, map(prog_var, type),
			map(prog_var, prog_var)).
:- mode goal_util__create_variables(in, in, in, in, in, in, out, out, out)
		is det.

	% Return all the variables in the goal.
	% Unlike quantification:goal_vars, this predicate returns
	% even the explicitly quantified variables.
:- pred goal_util__goal_vars(hlds_goal, set(prog_var)).
:- mode goal_util__goal_vars(in, out) is det.

	% Return all the variables in the list of goals.
	% Unlike quantification:goal_vars, this predicate returns
	% even the explicitly quantified variables.
:- pred goal_util__goals_goal_vars(list(hlds_goal), set(prog_var),
		set(prog_var)).
:- mode goal_util__goals_goal_vars(in, in, out) is det.

	% Return all the variables in a generic call.
:- pred goal_util__generic_call_vars(generic_call, list(prog_var)).
:- mode goal_util__generic_call_vars(in, out) is det.

	%
	% goal_util__extra_nonlocal_typeinfos(TypeInfoMap, TypeClassInfoMap,
	%		VarTypes, ExistQVars, NonLocals, NonLocalTypeInfos):
	% compute which type-info and type-class-info variables
	% may need to be non-local to a goal.
	%
	% A type-info variable may be non-local to a goal if any of 
	% the ordinary non-local variables for that goal are
	% polymorphically typed with a type that depends on that
	% type-info variable, or if the type-info is for an
	% existentially quantified type variable.
	%
	% In addition, a typeclass-info may be non-local to a goal if
	% any of the non-local variables for that goal are
	% polymorphically typed and are constrained by the typeclass
	% constraints for that typeclass-info variable,
	% or if the the type-class-info is for an existential constraint,
	% i.e. a constraint which contrains an existentially quantified
	% type variable.
	%
:- pred goal_util__extra_nonlocal_typeinfos(map(tvar, type_info_locn),
		map(class_constraint, prog_var), map(prog_var, type),
		existq_tvars, set(prog_var), set(prog_var)).
:- mode goal_util__extra_nonlocal_typeinfos(in, in, in, in, in, out) is det.

	% See whether the goal is a branched structure.
:- pred goal_util__goal_is_branched(hlds_goal_expr).
:- mode goal_util__goal_is_branched(in) is semidet.

	% Return an indication of the size of the goal.
:- pred goal_size(hlds_goal, int).
:- mode goal_size(in, out) is det.

	% Return an indication of the size of the list of goals.
:- pred goals_size(list(hlds_goal), int).
:- mode goals_size(in, out) is det.

	% Test whether the goal calls the given procedure.
:- pred goal_calls(hlds_goal, pred_proc_id).
:- mode goal_calls(in, in) is semidet.
:- mode goal_calls(in, out) is nondet.

	% Test whether the goal calls the given predicate.
	% This is useful before mode analysis when the proc_ids
	% have not been determined.
:- pred goal_calls_pred_id(hlds_goal, pred_id).
:- mode goal_calls_pred_id(in, in) is semidet.

	% Convert a switch back into a disjunction. This is needed 
	% for the magic set transformation.
:- pred goal_util__switch_to_disjunction(prog_var, list(case), instmap,
		inst_table, list(hlds_goal), prog_varset, prog_varset,
		map(prog_var, type), map(prog_var, type), module_info).
:- mode goal_util__switch_to_disjunction(in, in, in, in, out,
		in, out, in, out, in) is det.

:- pred goal_util__case_to_disjunct(prog_var, cons_id, hlds_goal, instmap,
		inst_table, instmap_delta, hlds_goal, prog_varset, prog_varset,
		map(prog_var, type), map(prog_var, type), module_info).
:- mode goal_util__case_to_disjunct(in, in, in, in, in, in, out, in, out,
		in, out, in) is det.

	% Transform an if-then-else into ( Cond, Then ; \+ Cond, Else ),
	% since magic.m and rl_gen.m don't handle if-then-elses.
:- pred goal_util__if_then_else_to_disjunction(hlds_goal, hlds_goal,
		hlds_goal, hlds_goal_info, hlds_goal_expr) is det.
:- mode goal_util__if_then_else_to_disjunction(in, in, in, in, out) is det.

%-----------------------------------------------------------------------------%

	% goal_util__can_reorder_goals(ModuleInfo, FullyStrict, Goal1, Goal2).
	%
	% Goals can be reordered if
	% - the goals are independent
	% - the goals are not impure
	% - any possible change in termination behaviour is allowed
	% 	according to the semantics options.
	%
:- pred goal_util__can_reorder_goals(module_info::in, bool::in, 
		inst_table::in, instmap::in, hlds_goal::in,
		instmap::in, hlds_goal::in) is semidet.

	% goal_util__reordering_maintains_termination(ModuleInfo,
	%		 FullyStrict, Goal1, Goal2)
	%
	% Succeeds if any possible change in termination behaviour from
	% reordering the goals is allowed according to the semantics options.
	% The information computed by termination analysis is used when
	% making this decision.
	%
:- pred goal_util__reordering_maintains_termination(module_info::in, bool::in, 
		hlds_goal::in, hlds_goal::in) is semidet.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module hlds_data, mode_util, code_aux, prog_data, purity.
:- import_module code_aux, det_analysis, inst_match, type_util, (inst).
:- import_module int, std_util, string, assoc_list, require, varset.

%-----------------------------------------------------------------------------%

goal_util__create_variables([], Varset, VarTypes, Subn, _OldVarTypes,
		_OldVarNames, Varset, VarTypes, Subn).
goal_util__create_variables([V | Vs], Varset0, VarTypes0, Subn0, OldVarTypes,
					OldVarNames, Varset, VarTypes, Subn) :-
	(
		map__contains(Subn0, V)
	->
		Varset2 = Varset0,
		Subn1 = Subn0,
		VarTypes1 = VarTypes0
	;
		varset__new_var(Varset0, NV, Varset1),
		(
			varset__search_name(OldVarNames, V, Name)
		->
			varset__name_var(Varset1, NV, Name, Varset2)
		;
			Varset2 = Varset1
		),
		map__det_insert(Subn0, V, NV, Subn1),
		(
			map__search(OldVarTypes, V, VT)
		->
			map__set(VarTypes0, NV, VT, VarTypes1)
		;
			VarTypes1 = VarTypes0
		)
	),
	goal_util__create_variables(Vs, Varset2, VarTypes1, Subn1, OldVarTypes,
		OldVarNames, Varset, VarTypes, Subn).

%-----------------------------------------------------------------------------%

:- pred goal_util__init_subn(assoc_list(prog_var, prog_var),
	map(prog_var, prog_var), map(prog_var, prog_var)).
:- mode goal_util__init_subn(in, in, out) is det.

goal_util__init_subn([], Subn, Subn).
goal_util__init_subn([A - H | Vs], Subn0, Subn) :-
	map__set(Subn0, H, A, Subn1),
	goal_util__init_subn(Vs, Subn1, Subn).

%-----------------------------------------------------------------------------%

:- pred goal_util__rename_var_pair_list(assoc_list(prog_var, T), bool,
	map(prog_var, prog_var), list(pair(prog_var, T))).
:- mode goal_util__rename_var_pair_list(in, in, in, out) is det.

goal_util__rename_var_pair_list([], _Must, _Subn, []).
goal_util__rename_var_pair_list([V - D | VDs], Must, Subn, [N - D | NDs]) :-
	goal_util__rename_var(V, Must, Subn, N),
	goal_util__rename_var_pair_list(VDs, Must, Subn, NDs).

goal_util__rename_var_list([], _Must, _Subn, []).
goal_util__rename_var_list([V | Vs], Must, Subn, [N | Ns]) :-
	goal_util__rename_var(V, Must, Subn, N),
	goal_util__rename_var_list(Vs, Must, Subn, Ns).

:- pred goal_util__rename_var(var(V), bool, map(var(V), var(V)),
		var(V)).
:- mode goal_util__rename_var(in, in, in, out) is det.

goal_util__rename_var(V, Must, Subn, N) :-
	(
		map__search(Subn, V, N0)
	->
		N = N0
	;
		(
			Must = no,
			N = V
		;
			Must = yes,
			term__var_to_int(V, VInt),
			string__format(
			    "goal_util__rename_var: no substitute for var %i", 
			    [i(VInt)], Msg),
			error(Msg)
		)
	).

%-----------------------------------------------------------------------------%

goal_util__rename_vars_in_goal(Goal0, Subn, Goal) :-
	goal_util__rename_vars_in_goal(Goal0, no, Subn, Goal).

goal_util__must_rename_vars_in_goal(Goal0, Subn, Goal) :-
	goal_util__rename_vars_in_goal(Goal0, yes, Subn, Goal).

%-----------------------------------------------------------------------------%

goal_util__rename_vars_in_goals([], _, _, []).
goal_util__rename_vars_in_goals([Goal0 | Goals0], Must, Subn, [Goal | Goals]) :-
	goal_util__rename_vars_in_goal(Goal0, Must, Subn, Goal),
	goal_util__rename_vars_in_goals(Goals0, Must, Subn, Goals).

:- pred goal_util__rename_vars_in_goal(hlds_goal, bool, map(prog_var, prog_var),
		hlds_goal).
:- mode goal_util__rename_vars_in_goal(in, in, in, out) is det.

goal_util__rename_vars_in_goal(Goal0 - GoalInfo0, Must, Subn, Goal - GoalInfo)
		:-
	goal_util__name_apart_2(Goal0, Must, Subn, Goal),
	goal_util__name_apart_goalinfo(GoalInfo0, Must, Subn, GoalInfo).

%-----------------------------------------------------------------------------%

:- pred goal_util__name_apart_2(hlds_goal_expr, bool, map(prog_var, prog_var),
		hlds_goal_expr).
:- mode goal_util__name_apart_2(in, in, in, out) is det.

goal_util__name_apart_2(conj(Goals0), Must, Subn, conj(Goals)) :-
	goal_util__name_apart_list(Goals0, Must, Subn, Goals).

goal_util__name_apart_2(par_conj(Goals0, SM0), Must, Subn,
		par_conj(Goals, SM)) :-
	goal_util__name_apart_list(Goals0, Must, Subn, Goals),
	goal_util__rename_var_maps(SM0, Must, Subn, SM).

goal_util__name_apart_2(disj(Goals0, SM0), Must, Subn, disj(Goals, SM)) :-
	goal_util__name_apart_list(Goals0, Must, Subn, Goals),
	goal_util__rename_var_maps(SM0, Must, Subn, SM).

goal_util__name_apart_2(switch(Var0, Det, Cases0, SM0), Must, Subn,
		switch(Var, Det, Cases, SM)) :-
	goal_util__rename_var(Var0, Must, Subn, Var),
	goal_util__name_apart_cases(Cases0, Must, Subn, Cases),
	goal_util__rename_var_maps(SM0, Must, Subn, SM).

goal_util__name_apart_2(if_then_else(Vars0, Cond0, Then0, Else0, SM0),
		Must, Subn, if_then_else(Vars, Cond, Then, Else, SM)) :-
	goal_util__rename_var_list(Vars0, Must, Subn, Vars),
	goal_util__rename_vars_in_goal(Cond0, Must, Subn, Cond),
	goal_util__rename_vars_in_goal(Then0, Must, Subn, Then),
	goal_util__rename_vars_in_goal(Else0, Must, Subn, Else),
	goal_util__rename_var_maps(SM0, Must, Subn, SM).

goal_util__name_apart_2(not(Goal0), Must, Subn, not(Goal)) :-
	goal_util__rename_vars_in_goal(Goal0, Must, Subn, Goal).

goal_util__name_apart_2(some(Vars0, CanRemove, Goal0), Must, Subn,
		some(Vars, CanRemove, Goal)) :-
	goal_util__rename_var_list(Vars0, Must, Subn, Vars),
	goal_util__rename_vars_in_goal(Goal0, Must, Subn, Goal).

goal_util__name_apart_2(
		generic_call(GenericCall0, Args0, Modes, Det),
		Must, Subn,
		generic_call(GenericCall, Args, Modes, Det)) :-
	goal_util__rename_generic_call(GenericCall0, Must, Subn, GenericCall),
	goal_util__rename_var_list(Args0, Must, Subn, Args).

goal_util__name_apart_2(
		call(PredId, ProcId, Args0, Builtin, Context, Sym),
		Must, Subn,
		call(PredId, ProcId, Args, Builtin, Context, Sym)) :-
	goal_util__rename_var_list(Args0, Must, Subn, Args).

goal_util__name_apart_2(unify(TermL0,TermR0,Mode,Unify0,Context), Must, Subn,
		unify(TermL,TermR,Mode,Unify,Context)) :-
	goal_util__rename_var(TermL0, Must, Subn, TermL),
	goal_util__rename_unify_rhs(TermR0, Must, Subn, TermR),
	goal_util__rename_unify(Unify0, Must, Subn, Unify).

goal_util__name_apart_2(pragma_c_code(A,B,C,Vars0,E,F,G), Must, Subn,
		pragma_c_code(A,B,C,Vars,E,F,G)) :-
	goal_util__rename_var_list(Vars0, Must, Subn, Vars).

%-----------------------------------------------------------------------------%

:- pred goal_util__name_apart_list(list(hlds_goal), bool,
		map(prog_var, prog_var), list(hlds_goal)).
:- mode goal_util__name_apart_list(in, in, in, out) is det.

goal_util__name_apart_list([], _Must, _Subn, []).
goal_util__name_apart_list([G0 | Gs0], Must, Subn, [G | Gs]) :-
	goal_util__rename_vars_in_goal(G0, Must, Subn, G),
	goal_util__name_apart_list(Gs0, Must, Subn, Gs).

%-----------------------------------------------------------------------------%

:- pred goal_util__name_apart_cases(list(case), bool, map(prog_var, prog_var),
		list(case)).
:- mode goal_util__name_apart_cases(in, in, in, out) is det.

goal_util__name_apart_cases([], _Must, _Subn, []).
goal_util__name_apart_cases([case(Cons, IMDelta0, G0) | Gs0], Must, Subn,
		[case(Cons, IMDelta, G) | Gs]) :-
	instmap_delta_apply_sub(IMDelta0, Must, Subn, IMDelta),
	goal_util__rename_vars_in_goal(G0, Must, Subn, G),
	goal_util__name_apart_cases(Gs0, Must, Subn, Gs).

%-----------------------------------------------------------------------------%

:- pred goal_util__rename_unify_rhs(unify_rhs, bool, map(prog_var, prog_var),
		unify_rhs).
:- mode goal_util__rename_unify_rhs(in, in, in, out) is det.

goal_util__rename_unify_rhs(var(Var0), Must, Subn, var(Var)) :-
	goal_util__rename_var(Var0, Must, Subn, Var).
goal_util__rename_unify_rhs(functor(Functor, ArgVars0), Must, Subn,
			functor(Functor, ArgVars)) :-
	goal_util__rename_var_list(ArgVars0, Must, Subn, ArgVars).
goal_util__rename_unify_rhs(
	    lambda_goal(PredOrFunc, EvalMethod, FixModes, NonLocals0,
	    		Vars0, Modes, Det, IMDelta0, Goal0),
	    Must, Subn, 
	    lambda_goal(PredOrFunc, EvalMethod, FixModes, NonLocals,
	    		Vars, Modes, Det, IMDelta, Goal)) :-
	instmap_delta_apply_sub(IMDelta0, Must, Subn, IMDelta),
	goal_util__rename_var_list(NonLocals0, Must, Subn, NonLocals),
	goal_util__rename_var_list(Vars0, Must, Subn, Vars),
	goal_util__rename_vars_in_goal(Goal0, Must, Subn, Goal).

:- pred goal_util__rename_unify(unification, bool, map(prog_var, prog_var),
		unification).
:- mode goal_util__rename_unify(in, in, in, out) is det.

goal_util__rename_unify(
		construct(Var0, ConsId, Vars0, Modes, Reuse0, Uniq, Aditi),
		Must, Subn,
		construct(Var, ConsId, Vars, Modes, Reuse, Uniq, Aditi)) :-
	goal_util__rename_var(Var0, Must, Subn, Var),
	goal_util__rename_var_list(Vars0, Must, Subn, Vars),
	( Reuse0 = yes(cell_to_reuse(ReuseVar0, B, C)) ->
		goal_util__rename_var(ReuseVar0, Must, Subn, ReuseVar),
		Reuse = yes(cell_to_reuse(ReuseVar, B, C))
	;
		Reuse = no
	).
goal_util__rename_unify(deconstruct(Var0, ConsId, Vars0, Modes, Cat),
		Must, Subn, deconstruct(Var, ConsId, Vars, Modes, Cat)) :-
	goal_util__rename_var(Var0, Must, Subn, Var),
	goal_util__rename_var_list(Vars0, Must, Subn, Vars).
goal_util__rename_unify(assign(L0, R0), Must, Subn, assign(L, R)) :-
	goal_util__rename_var(L0, Must, Subn, L),
	goal_util__rename_var(R0, Must, Subn, R).
goal_util__rename_unify(simple_test(L0, R0), Must, Subn, simple_test(L, R)) :-
	goal_util__rename_var(L0, Must, Subn, L),
	goal_util__rename_var(R0, Must, Subn, R).
goal_util__rename_unify(complicated_unify(Modes, Cat, TypeInfoVars),
			_Must, _Subn,
			complicated_unify(Modes, Cat, TypeInfoVars)).

%-----------------------------------------------------------------------------%

:- pred goal_util__rename_generic_call(generic_call, bool,
		map(prog_var, prog_var), generic_call).
:- mode goal_util__rename_generic_call(in, in, in, out) is det.

goal_util__rename_generic_call(higher_order(Var0, PredOrFunc, Arity),
		Must, Subn, higher_order(Var, PredOrFunc, Arity)) :-
	goal_util__rename_var(Var0, Must, Subn, Var).
goal_util__rename_generic_call(class_method(Var0, Method, ClassId, MethodId),
		Must, Subn, class_method(Var, Method, ClassId, MethodId)) :-
	goal_util__rename_var(Var0, Must, Subn, Var).
goal_util__rename_generic_call(aditi_builtin(Builtin, PredCallId),
		_Must, _Subn, aditi_builtin(Builtin, PredCallId)).

%-----------------------------------------------------------------------------%

:- pred goal_util__rename_var_maps(map(prog_var, T), bool,
				map(prog_var, prog_var), map(prog_var, T)).
:- mode goal_util__rename_var_maps(in, in, in, out) is det.

goal_util__rename_var_maps(Map0, Must, Subn, Map) :-
	map__to_assoc_list(Map0, AssocList0),
	goal_util__rename_var_maps_2(AssocList0, Must, Subn, AssocList),
	map__from_assoc_list(AssocList, Map).

:- pred goal_util__rename_var_maps_2(assoc_list(var(V), T),
		bool, map(var(V), var(V)), assoc_list(var(V), T)).
:- mode goal_util__rename_var_maps_2(in, in, in, out) is det.

goal_util__rename_var_maps_2([], _Must, _Subn, []).
goal_util__rename_var_maps_2([V - L | Vs], Must, Subn, [N - L | Ns]) :-
	goal_util__rename_var(V, Must, Subn, N),
	goal_util__rename_var_maps_2(Vs, Must, Subn, Ns).

%-----------------------------------------------------------------------------%

:- pred goal_util__name_apart_goalinfo(hlds_goal_info,
		bool, map(prog_var, prog_var), hlds_goal_info).
:- mode goal_util__name_apart_goalinfo(in, in, in, out) is det.

goal_util__name_apart_goalinfo(GoalInfo0, Must, Subn, GoalInfo) :-
	goal_info_get_pre_births(GoalInfo0, PreBirths0),
	goal_util__name_apart_set(PreBirths0, Must, Subn, PreBirths),
	goal_info_set_pre_births(GoalInfo0, PreBirths, GoalInfo1),

	goal_info_get_pre_deaths(GoalInfo1, PreDeaths0),
	goal_util__name_apart_set(PreDeaths0, Must, Subn, PreDeaths),
	goal_info_set_pre_deaths(GoalInfo1, PreDeaths, GoalInfo2),

	goal_info_get_post_births(GoalInfo2, PostBirths0),
	goal_util__name_apart_set(PostBirths0, Must, Subn, PostBirths),
	goal_info_set_post_births(GoalInfo2, PostBirths, GoalInfo3),

	goal_info_get_post_deaths(GoalInfo3, PostDeaths0),
	goal_util__name_apart_set(PostDeaths0, Must, Subn, PostDeaths),
	goal_info_set_post_deaths(GoalInfo3, PostDeaths, GoalInfo4),

	goal_info_get_nonlocals(GoalInfo4, NonLocals0),
	goal_util__name_apart_set(NonLocals0, Must, Subn, NonLocals),
	goal_info_set_nonlocals(GoalInfo4, NonLocals, GoalInfo5),

	goal_info_get_instmap_delta(GoalInfo5, InstMap0),
	instmap_delta_apply_sub(InstMap0, Must, Subn, InstMap),
	goal_info_set_instmap_delta(GoalInfo5, InstMap, GoalInfo6),

	goal_info_get_follow_vars(GoalInfo6, MaybeFollowVars0),
	(
		MaybeFollowVars0 = no,
		MaybeFollowVars = no
	;
		MaybeFollowVars0 = yes(FollowVars0),
		goal_util__rename_var_maps(FollowVars0, Must, Subn, FollowVars),
		MaybeFollowVars = yes(FollowVars)
	),
	goal_info_set_follow_vars(GoalInfo6, MaybeFollowVars, GoalInfo).

%-----------------------------------------------------------------------------%

:- pred goal_util__name_apart_set(set(prog_var), bool, map(prog_var, prog_var),
		set(prog_var)).
:- mode goal_util__name_apart_set(in, in, in, out) is det.

goal_util__name_apart_set(Vars0, Must, Subn, Vars) :-
	set__to_sorted_list(Vars0, VarsList0),
	goal_util__rename_var_list(VarsList0, Must, Subn, VarsList),
	set__list_to_set(VarsList, Vars).

%-----------------------------------------------------------------------------%

goal_util__goal_vars(Goal - _GoalInfo, Set) :-
	set__init(Set0),
	goal_util__goal_vars_2(Goal, Set0, Set).

:- pred goal_util__goal_vars_2(hlds_goal_expr, set(prog_var), set(prog_var)).
:- mode goal_util__goal_vars_2(in, in, out) is det.

goal_util__goal_vars_2(unify(Var, RHS, _, Unif, _), Set0, Set) :-
	set__insert(Set0, Var, Set1),
	( Unif = construct(_, _, _, _, CellToReuse, _, _) ->
		( CellToReuse = yes(cell_to_reuse(Var, _, _)) ->
			set__insert(Set1, Var, Set2)
		;
			Set2 = Set1
		)
	;
		Set2 = Set1
	),	
	goal_util__rhs_goal_vars(RHS, Set2, Set).

goal_util__goal_vars_2(generic_call(GenericCall, ArgVars, _, _),
		Set0, Set) :-
	goal_util__generic_call_vars(GenericCall, Vars0),
	set__insert_list(Set0, Vars0, Set1),
	set__insert_list(Set1, ArgVars, Set).

goal_util__goal_vars_2(call(_, _, ArgVars, _, _, _), Set0, Set) :-
	set__insert_list(Set0, ArgVars, Set).

goal_util__goal_vars_2(conj(Goals), Set0, Set) :-
	goal_util__goals_goal_vars(Goals, Set0, Set).

goal_util__goal_vars_2(par_conj(Goals, _SM), Set0, Set) :-
	goal_util__goals_goal_vars(Goals, Set0, Set).

goal_util__goal_vars_2(disj(Goals, _), Set0, Set) :-
	goal_util__goals_goal_vars(Goals, Set0, Set).

goal_util__goal_vars_2(switch(Var, _Det, Cases, _), Set0, Set) :-
	set__insert(Set0, Var, Set1),
	goal_util__cases_goal_vars(Cases, Set1, Set).

goal_util__goal_vars_2(some(Vars, _, Goal - _), Set0, Set) :-
	set__insert_list(Set0, Vars, Set1),
	goal_util__goal_vars_2(Goal, Set1, Set).

goal_util__goal_vars_2(not(Goal - _GoalInfo), Set0, Set) :-
	goal_util__goal_vars_2(Goal, Set0, Set).

goal_util__goal_vars_2(if_then_else(Vars, A - _, B - _, C - _, _), Set0, Set) :-
	set__insert_list(Set0, Vars, Set1),
	goal_util__goal_vars_2(A, Set1, Set2),
	goal_util__goal_vars_2(B, Set2, Set3),
	goal_util__goal_vars_2(C, Set3, Set).

goal_util__goal_vars_2(pragma_c_code(_, _, _, ArgVars, _, _, _),
		Set0, Set) :-
	set__insert_list(Set0, ArgVars, Set).

goal_util__goals_goal_vars([], Set, Set).
goal_util__goals_goal_vars([Goal - _ | Goals], Set0, Set) :-
	goal_util__goal_vars_2(Goal, Set0, Set1),
	goal_util__goals_goal_vars(Goals, Set1, Set).

:- pred goal_util__cases_goal_vars(list(case), set(prog_var), set(prog_var)).
:- mode goal_util__cases_goal_vars(in, in, out) is det.

goal_util__cases_goal_vars([], Set, Set).
goal_util__cases_goal_vars([case(_, _, Goal - _) | Cases], Set0, Set) :-
	goal_util__goal_vars_2(Goal, Set0, Set1),
	goal_util__cases_goal_vars(Cases, Set1, Set).

:- pred goal_util__rhs_goal_vars(unify_rhs, set(prog_var), set(prog_var)).
:- mode goal_util__rhs_goal_vars(in, in, out) is det.

goal_util__rhs_goal_vars(var(X), Set0, Set) :-
	set__insert(Set0, X, Set).
goal_util__rhs_goal_vars(functor(_Functor, ArgVars), Set0, Set) :-
	set__insert_list(Set0, ArgVars, Set).
goal_util__rhs_goal_vars(
		lambda_goal(_, _, _, NonLocals, LambdaVars, _M, _D, _IMDelta,
				Goal - _), 
		Set0, Set) :-
	set__insert_list(Set0, NonLocals, Set1),
	set__insert_list(Set1, LambdaVars, Set2),
	goal_util__goal_vars_2(Goal, Set2, Set).

goal_util__generic_call_vars(higher_order(Var, _, _), [Var]).
goal_util__generic_call_vars(class_method(Var, _, _, _), [Var]).
goal_util__generic_call_vars(aditi_builtin(_, _), []).

%-----------------------------------------------------------------------------%

goal_util__extra_nonlocal_typeinfos(TypeVarMap, TypeClassVarMap, VarTypes,
		ExistQVars, NonLocals, NonLocalTypeInfos) :-
	set__to_sorted_list(NonLocals, NonLocalsList),
	map__apply_to_list(NonLocalsList, VarTypes, NonLocalsTypes),
	term__vars_list(NonLocalsTypes, NonLocalTypeVars),
		% Find all the type-infos and typeclass-infos that are
		% non-local
	solutions_set(lambda([Var::out] is nondet, (
			%
			% if there is some TypeVar for which either
			% (a) the type of some non-local variable
			%     depends on that type variable, or
			% (b) that type variable is existentially
			%     quantified
			%
			( list__member(TypeVar, NonLocalTypeVars)
			; list__member(TypeVar, ExistQVars)
			),
			%
			% then the type_info Var for that type,
			% and any type_class_info Vars which represent
			% constraints on types which include that type,
			% should be included in the NonLocalTypeInfos.
			%
			( map__search(TypeVarMap, TypeVar, Location),
			  type_info_locn_var(Location, Var)
			;
			  % this is probably not very efficient...
			  map__member(TypeClassVarMap, Constraint, Var),
			  Constraint = constraint(_Name, ArgTypes),
			  term__contains_var_list(ArgTypes, TypeVar)
			)
		)), NonLocalTypeInfos).

%-----------------------------------------------------------------------------%

goal_util__goal_is_branched(if_then_else(_, _, _, _, _)).
goal_util__goal_is_branched(switch(_, _, _, _)).
goal_util__goal_is_branched(disj(_, _)).

%-----------------------------------------------------------------------------%

goal_size(GoalExpr - _, Size) :-
	goal_expr_size(GoalExpr, Size).

goals_size([], 0).
goals_size([Goal | Goals], Size) :-
	goal_size(Goal, Size1),
	goals_size(Goals, Size2),
	Size is Size1 + Size2.

:- pred cases_size(list(case), int).
:- mode cases_size(in, out) is det.

cases_size([], 0).
cases_size([case(_, _, Goal) | Cases], Size) :-
	goal_size(Goal, Size1),
	cases_size(Cases, Size2),
	Size is Size1 + Size2.

:- pred goal_expr_size(hlds_goal_expr, int).
:- mode goal_expr_size(in, out) is det.

goal_expr_size(conj(Goals), Size) :-
	goals_size(Goals, Size).
goal_expr_size(par_conj(Goals, _SM), Size) :-
	goals_size(Goals, Size1),
	Size is Size1 + 1.
goal_expr_size(disj(Goals, _), Size) :-
	goals_size(Goals, Size1),
	Size is Size1 + 1.
goal_expr_size(switch(_, _, Goals, _), Size) :-
	cases_size(Goals, Size1),
	Size is Size1 + 1.
goal_expr_size(if_then_else(_, Cond, Then, Else, _), Size) :-
	goal_size(Cond, Size1),
	goal_size(Then, Size2),
	goal_size(Else, Size3),
	Size is Size1 + Size2 + Size3 + 1.
goal_expr_size(not(Goal), Size) :-
	goal_size(Goal, Size1),
	Size is Size1 + 1.
goal_expr_size(some(_, _, Goal), Size) :-
	goal_size(Goal, Size1),
	Size is Size1 + 1.
goal_expr_size(call(_, _, _, _, _, _), 1).
goal_expr_size(generic_call(_, _, _, _), 1).
goal_expr_size(unify(_, _, _, _, _), 1).
goal_expr_size(pragma_c_code(_, _, _, _, _, _, _), 1).

%-----------------------------------------------------------------------------%

goal_calls(GoalExpr - _, PredProcId) :-
	goal_expr_calls(GoalExpr, PredProcId).

:- pred goals_calls(list(hlds_goal), pred_proc_id).
:- mode goals_calls(in, in) is semidet.
:- mode goals_calls(in, out) is nondet.

goals_calls([Goal | Goals], PredProcId) :-
	(
		goal_calls(Goal, PredProcId)
	;
		goals_calls(Goals, PredProcId)
	).

:- pred cases_calls(list(case), pred_proc_id).
:- mode cases_calls(in, in) is semidet.
:- mode cases_calls(in, out) is nondet.

cases_calls([case(_, _, Goal) | Cases], PredProcId) :-
	(
		goal_calls(Goal, PredProcId)
	;
		cases_calls(Cases, PredProcId)
	).

:- pred goal_expr_calls(hlds_goal_expr, pred_proc_id).
:- mode goal_expr_calls(in, in) is semidet.
:- mode goal_expr_calls(in, out) is nondet.

goal_expr_calls(conj(Goals), PredProcId) :-
	goals_calls(Goals, PredProcId).
goal_expr_calls(disj(Goals, _), PredProcId) :-
	goals_calls(Goals, PredProcId).
goal_expr_calls(switch(_, _, Goals, _), PredProcId) :-
	cases_calls(Goals, PredProcId).
goal_expr_calls(if_then_else(_, Cond, Then, Else, _), PredProcId) :-
	(
		goal_calls(Cond, PredProcId)
	;
		goal_calls(Then, PredProcId)
	;
		goal_calls(Else, PredProcId)
	).
goal_expr_calls(not(Goal), PredProcId) :-
	goal_calls(Goal, PredProcId).
goal_expr_calls(some(_, _, Goal), PredProcId) :-
	goal_calls(Goal, PredProcId).
goal_expr_calls(call(PredId, ProcId, _, _, _, _), proc(PredId, ProcId)).

%-----------------------------------------------------------------------------%

goal_calls_pred_id(GoalExpr - _, PredId) :-
	goal_expr_calls_pred_id(GoalExpr, PredId).

:- pred goals_calls_pred_id(list(hlds_goal), pred_id).
:- mode goals_calls_pred_id(in, in) is semidet.

goals_calls_pred_id([Goal | Goals], PredId) :-
	(
		goal_calls_pred_id(Goal, PredId)
	;
		goals_calls_pred_id(Goals, PredId)
	).

:- pred cases_calls_pred_id(list(case), pred_id).
:- mode cases_calls_pred_id(in, in) is semidet.

cases_calls_pred_id([case(_, _, Goal) | Cases], PredId) :-
	(
		goal_calls_pred_id(Goal, PredId)
	;
		cases_calls_pred_id(Cases, PredId)
	).

:- pred goal_expr_calls_pred_id(hlds_goal_expr, pred_id).
:- mode goal_expr_calls_pred_id(in, in) is semidet.

goal_expr_calls_pred_id(conj(Goals), PredId) :-
	goals_calls_pred_id(Goals, PredId).
goal_expr_calls_pred_id(disj(Goals, _), PredId) :-
	goals_calls_pred_id(Goals, PredId).
goal_expr_calls_pred_id(switch(_, _, Goals, _), PredId) :-
	cases_calls_pred_id(Goals, PredId).
goal_expr_calls_pred_id(if_then_else(_, Cond, Then, Else, _), PredId) :-
	(
		goal_calls_pred_id(Cond, PredId)
	;
		goal_calls_pred_id(Then, PredId)
	;
		goal_calls_pred_id(Else, PredId)
	).
goal_expr_calls_pred_id(not(Goal), PredId) :-
	goal_calls_pred_id(Goal, PredId).
goal_expr_calls_pred_id(some(_, _, Goal), PredId) :-
	goal_calls_pred_id(Goal, PredId).
goal_expr_calls_pred_id(call(PredId, _, _, _, _, _), PredId).

%-----------------------------------------------------------------------------%

goal_util__switch_to_disjunction(_, [], _, _, [], VarSet, VarSet, 
		VarTypes, VarTypes, _).
goal_util__switch_to_disjunction(Var, [case(ConsId, IMDelta, Goal0) | Cases],
		InstMap, InstTable, [Goal | Goals], VarSet0, VarSet,
		VarTypes0, VarTypes, ModuleInfo) :-
	goal_util__case_to_disjunct(Var, ConsId, Goal0, InstMap, InstTable,
		IMDelta, Goal, VarSet0, VarSet1, VarTypes0, VarTypes1,
		ModuleInfo),
	goal_util__switch_to_disjunction(Var, Cases, InstMap, InstTable, Goals,
		VarSet1, VarSet, VarTypes1, VarTypes, ModuleInfo).

goal_util__case_to_disjunct(Var, ConsId, CaseGoal, InstMap, InstTable,
		InstMapDelta, Disjunct, VarSet0, VarSet, VarTypes0, VarTypes,
		ModuleInfo) :-
	cons_id_arity(ConsId, ConsArity),
	varset__new_vars(VarSet0, ConsArity, ArgVars, VarSet),
	map__lookup(VarTypes0, Var, VarType),
	type_util__get_cons_id_arg_types(ModuleInfo,
		VarType, ConsId, ArgTypes),
	map__det_insert_from_corresponding_lists(VarTypes0, ArgVars,
		ArgTypes, VarTypes),
	instmap__lookup_var(InstMap, Var, Inst0),
	(
		inst_expand(InstMap, InstTable, ModuleInfo, Inst0, Inst1),
		get_arg_insts(Inst1, ConsId, ConsArity, ArgInsts1)
	->
		ArgInsts = ArgInsts1
	;
		error("goal_util__case_to_disjunct - get_arg_insts failed")
	),
	InstToUniMode =
		lambda([ArgInst::in, ArgUniMode::out] is det, (
			ArgUniMode = ((ArgInst - free(unique))
					-> (ArgInst - ArgInst))
		)),
	list__map(InstToUniMode, ArgInsts, UniModes),
	UniMode = (Inst0 - Inst0) - (Inst0 - Inst0),
	UnifyContext = unify_context(explicit, []),
	Unification = deconstruct(Var, ConsId, ArgVars, UniModes, can_fail),
	ExtraGoal = unify(Var, functor(ConsId, ArgVars),
		UniMode, Unification, UnifyContext),
	set__singleton_set(NonLocals, Var),
	goal_info_init(NonLocals, InstMapDelta, semidet, ExtraGoalInfo),

	% Conjoin the test and the rest of the case.
	goal_to_conj_list(CaseGoal, CaseGoalConj),
	GoalList = [ExtraGoal - ExtraGoalInfo | CaseGoalConj],

	% Work out the nonlocals, instmap_delta and determinism
	% of the entire conjunction.
	CaseGoal = _ - CaseGoalInfo,
	goal_info_get_nonlocals(CaseGoalInfo, CaseNonLocals0),
	set__insert(CaseNonLocals0, Var, CaseNonLocals),
	goal_info_get_instmap_delta(CaseGoalInfo, CaseInstMapDelta),
	instmap_delta_apply_instmap_delta(InstMapDelta, 
		CaseInstMapDelta, GoalInstMapDelta),
	goal_info_get_determinism(CaseGoalInfo, CaseDetism0),
	det_conjunction_detism(semidet, CaseDetism0, Detism),
	goal_info_init(CaseNonLocals, GoalInstMapDelta,
		Detism, CombinedGoalInfo),
	Disjunct = conj(GoalList) - CombinedGoalInfo.

%-----------------------------------------------------------------------------%

goal_util__if_then_else_to_disjunction(Cond, Then, Else, GoalInfo, Goal) :-
	goal_util__compute_disjunct_goal_info(Cond, Then, 
		GoalInfo, CondThenInfo),
	conj_list_to_goal([Cond, Then], CondThenInfo, CondThen),

	Cond = _ - CondInfo,
	goal_info_get_determinism(CondInfo, CondDetism),
	det_negation_det(CondDetism, MaybeNegCondDet),
	( MaybeNegCondDet = yes(NegCondDet1) ->
		NegCondDet = NegCondDet1
	;
		error("goal_util__if_then_else_to_disjunction: inappropriate determinism in a negation.")
	),
	determinism_components(NegCondDet, _, NegCondMaxSoln),
	( NegCondMaxSoln = at_most_zero ->
		instmap_delta_init_unreachable(NegCondDelta)
	;
		instmap_delta_init_reachable(NegCondDelta)
	),
	goal_info_get_nonlocals(CondInfo, CondNonLocals),
	goal_info_init(CondNonLocals, NegCondDelta, NegCondDet, NegCondInfo),

	goal_util__compute_disjunct_goal_info(not(Cond) - NegCondInfo, Else, 
		GoalInfo, NegCondElseInfo),
	conj_list_to_goal([not(Cond) - NegCondInfo, Else], 
		NegCondElseInfo, NegCondElse),

	map__init(SM),
	Goal = disj([CondThen, NegCondElse], SM).


	% Compute a hlds_goal_info for a pair of conjoined goals.
:- pred goal_util__compute_disjunct_goal_info(hlds_goal::in, hlds_goal::in, 
		hlds_goal_info::in, hlds_goal_info::out) is det.

goal_util__compute_disjunct_goal_info(Goal1, Goal2, GoalInfo, CombinedInfo) :-
	Goal1 = _ - GoalInfo1,
	Goal2 = _ - GoalInfo2,

	goal_info_get_nonlocals(GoalInfo1, NonLocals1),
	goal_info_get_nonlocals(GoalInfo2, NonLocals2),
	goal_info_get_nonlocals(GoalInfo, OuterNonLocals),
	set__union(NonLocals1, NonLocals2, CombinedNonLocals0),
	set__intersect(CombinedNonLocals0, OuterNonLocals, CombinedNonLocals),

	goal_info_get_instmap_delta(GoalInfo1, Delta1),
	goal_info_get_instmap_delta(GoalInfo2, Delta2),
	instmap_delta_apply_instmap_delta(Delta1, Delta2, CombinedDelta),

	goal_info_get_determinism(GoalInfo1, Detism1),
	goal_info_get_determinism(GoalInfo2, Detism2),
	det_conjunction_detism(Detism1, Detism2, CombinedDetism),

	goal_info_init(CombinedNonLocals, CombinedDelta, 
		CombinedDetism, CombinedInfo).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%


goal_util__can_reorder_goals(ModuleInfo, FullyStrict, InstTable,
		InstmapBeforeEarlierGoal, EarlierGoal,
		InstmapBeforeLaterGoal, LaterGoal) :-

	EarlierGoal = _ - EarlierGoalInfo,
	LaterGoal = _ - LaterGoalInfo,

		% Impure goals cannot be reordered.
	\+ goal_info_is_impure(EarlierGoalInfo),
	\+ goal_info_is_impure(LaterGoalInfo),

	goal_util__reordering_maintains_termination(ModuleInfo, FullyStrict, 
		EarlierGoal, LaterGoal),

	%
	% Don't reorder the goals if the later goal depends
	% on the outputs of the current goal.
	%
	\+ goal_depends_on_earlier_goal(LaterGoal, EarlierGoal,
			InstmapBeforeEarlierGoal, InstTable, ModuleInfo),

	%
	% Don't reorder the goals if the later goal changes the 
	% instantiatedness of any of the non-locals of the earlier
	% goal. This is necessary if the later goal clobbers any 
	% of the non-locals of the earlier goal, and avoids rerunning
	% full mode analysis in other cases.
	%
	\+ goal_depends_on_earlier_goal(EarlierGoal, LaterGoal, 
			InstmapBeforeLaterGoal, InstTable, ModuleInfo).


goal_util__reordering_maintains_termination(ModuleInfo, FullyStrict, 
		EarlierGoal, LaterGoal) :-
	EarlierGoal = _ - EarlierGoalInfo,
	LaterGoal = _ - LaterGoalInfo,

	goal_info_get_determinism(EarlierGoalInfo, EarlierDetism),
	determinism_components(EarlierDetism, EarlierCanFail, _),
	goal_info_get_determinism(LaterGoalInfo, LaterDetism),
	determinism_components(LaterDetism, LaterCanFail, _),

		% If --fully-strict was specified, don't convert 
		% (can_loop, can_fail) into (can_fail, can_loop). 
	( 
		FullyStrict = yes, 
		\+ code_aux__goal_cannot_loop(ModuleInfo, EarlierGoal)
	->
		LaterCanFail = cannot_fail
	;
		true
	),
		% Don't convert (can_fail, can_loop) into 
		% (can_loop, can_fail), since this could worsen 
		% the termination properties of the program.
	( EarlierCanFail = can_fail ->
		code_aux__goal_cannot_loop(ModuleInfo, LaterGoal)
	;
		true
	).

	%
	% If the earlier goal changes the instantiatedness of a variable
	% that is used in the later goal, then the later goal depends on
	% the earlier goal.
	%
	% This code does work on the alias branch.
	%
:- pred goal_depends_on_earlier_goal(hlds_goal::in, hlds_goal::in,
		instmap::in, inst_table::in, module_info::in) is semidet.

goal_depends_on_earlier_goal(_ - LaterGoalInfo, _ - EarlierGoalInfo,
		InstMapBeforeEarlierGoal, InstTable, ModuleInfo) :-
	goal_info_get_instmap_delta(EarlierGoalInfo, EarlierInstMapDelta),
	instmap__apply_instmap_delta(InstMapBeforeEarlierGoal,
			EarlierInstMapDelta, InstMapAfterEarlierGoal),

	instmap_changed_vars(InstMapBeforeEarlierGoal, InstMapAfterEarlierGoal,
			InstTable, ModuleInfo, EarlierChangedVars),

	goal_info_get_nonlocals(LaterGoalInfo, LaterGoalNonLocals),
	set__intersect(EarlierChangedVars, LaterGoalNonLocals, Intersection),
	not set__empty(Intersection).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
