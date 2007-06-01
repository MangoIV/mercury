%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2007 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: elds.m.
% Main author: wangp.
%
% ELDS - The Erlang Data Structure.
%
% This module defines the ELDS data structure itself.
% The ELDS is an intermediate data structure used in compilation;
% we compile Mercury source -> parse tree -> HLDS -> ELDS -> target (Erlang).
% The ELDS uses the same types for variables and procedure ids as the HLDS
% so as not the clutter the ELDS code generator with conversions between types.
%
%-----------------------------------------------------------------------------%

:- module erl_backend.elds.
:- interface.

:- import_module backend_libs.rtti.
:- import_module hlds.hlds_pred.
:- import_module mdbcomp.
:- import_module mdbcomp.prim_data.
:- import_module parse_tree.prog_data.
:- import_module parse_tree.prog_foreign.

:- import_module bool.
:- import_module char.
:- import_module list.
:- import_module maybe.

%-----------------------------------------------------------------------------%

%
% The type `elds' is the actual ELDS.
%
:- type elds
    --->    elds(
                % The original Mercury module name.
                elds_name           :: module_name,

                % Code defined in Erlang.
                elds_foreign_bodies :: list(foreign_body_code),

                % Definitions of functions in the module.
                elds_funcs          :: list(elds_defn),

                % Definitions of foreign exported functions.
                elds_fe_funcs       :: list(elds_foreign_export_defn),

                % Definitions of functions which return RTTI data.
                elds_rtti_funcs     :: list(elds_rtti_defn)
            ).

    % Function definition.
    %
:- type elds_defn
    --->    elds_defn(
                defn_proc_id    :: pred_proc_id,
                defn_varset     :: prog_varset,
                defn_body       :: elds_body
            ).

:- type elds_body
    --->    body_defined_here(elds_clause)
            % The body is to be defined by the user in some other way,
            % e.g. foreign code.
    ;       body_external(arity).

    % Foreign exported function definition.
    %
:- type elds_foreign_export_defn
    --->    elds_foreign_export_defn(
                fe_defn_name    :: string,
                fe_defn_varset  :: prog_varset,
                fe_defn_clause  :: elds_clause
            ).

    % Function which returns RTTI data when called.
    %
:- type elds_rtti_defn
    --->    elds_rtti_defn(
                rtti_defn_id        :: elds_rtti_id, 
                rtti_defn_exported  :: bool,
                rtti_defn_varset    :: prog_varset,
                rtti_defn_clause    :: elds_clause
            ).

    % The types of RTTI which we can generate ELDS functions for.
    %
:- type elds_rtti_id
    --->    elds_rtti_type_ctor_id(
                rtti_type_ctor
            )
    ;       elds_rtti_type_info_id(
                rtti_type_info
            )
    ;       elds_rtti_pseudo_type_info_id(
                rtti_pseudo_type_info
            )
    ;       elds_rtti_base_typeclass_id(
                tc_name,        % identifies the type class
                module_name,    % module containing instance decl.
                string          % encodes the names and arities of the
                                % types in the instance declaration
            )
    .

:- type elds_clause
    --->    elds_clause(
                clause_pattern  :: list(elds_term),
                clause_expr     :: elds_expr
            ).

    % An Erlang expression.
    %
:- type elds_expr

            % begin Expr1, Expr2, ... end
            %
    --->    elds_block(list(elds_expr))

            % A term.
            %
    ;       elds_term(elds_term)

            % Expr = Expr
            %
    ;       elds_eq(elds_expr, elds_expr)

            % A unary or binary operator expression.
            %
    ;       elds_unop(elds_unop, elds_expr)
    ;       elds_binop(elds_binop, elds_expr, elds_expr)

            % A normal call to a procedure, a higher order call, or a call to a
            % builtin.
            %
            % proc(Expr, ...)
            % Proc(Expr, ...)
            % builtin(Expr, ...)
            %
    ;       elds_call(elds_call_target, list(elds_expr))

            % A call to a function returning RTTI information.
            %
    ;       elds_rtti_ref(elds_rtti_id)

            % fun(Args, ...) -> Expr end
            % (We only use single clause functions.)
            %
    ;       elds_fun(elds_clause)

            % case Expr of
            %   Pattern -> Expr,
            %   ...
            % end
            %
    ;       elds_case_expr(elds_expr, list(elds_case))

            % try Expr of
            %   Pattern -> Expr,
            %   ...
            % catch
            %   Pattern:Pattern -> Expr
            % end
            %
    ;       elds_try(
                try_expr    :: elds_expr,
                try_cases   :: list(elds_case),
                try_catch   :: elds_catch
            )

            % throw(Expr)
            %
    ;       elds_throw(elds_expr)

            % A piece of code to be embedded directly in the generated code.
    ;       elds_foreign_code(string).

:- type elds_term
    --->    elds_char(char)
    ;       elds_int(int)
    ;       elds_float(float)
    ;       elds_string(string)
    ;       elds_atom_raw(string)
    ;       elds_atom(sym_name)
            % `elds_atom_raw' is useful to introduce arbitrary atoms into the
            % generated code.
            %
            % `elds_atom' is intended to be used with functors; how a functor
            % is ultimately written out is not the concern of the ELDS code
            % generator.

    ;       elds_tuple(list(elds_expr))

    ;       elds_var(prog_var)

    ;       elds_anon_var
            % elds_anon_var is a convenience for cases where we need a dummy
            % variable to fill out a pattern.

    ;       elds_fixed_name_var(string).
            % elds_fixed_name_var is used for communicating values to and from
            % code written in a foreign language.  In this case we have no
            % choice but to use the variable names expected by the foreign code
            % snippet.

% XXX we should use insts (or some other method) to restrict expressions in
% tuples to be terms, if the tuple is going to be used in a pattern.

:- type elds_call_target
    --->    elds_call_plain(pred_proc_id)
    ;       elds_call_ho(elds_expr)
    ;       elds_call_builtin(string).

:- type elds_case
    --->    elds_case(elds_term, elds_expr).

:- type elds_catch
    --->    elds_catch(elds_term, elds_term, elds_expr). 

:- type elds_unop
    --->    plus
    ;       minus
    ;       bnot
    ;       logical_not.

:- type elds_binop
    --->    mul
    ;       float_div
    ;       int_div
    ;       (rem)
    ;       band
    %;      and         % *not* short circuiting
    ;       add
    ;       sub
    ;       bor
    ;       bxor
    ;       bsl
    ;       bsr
    %;      or
    %;      xor
    %;      plus_plus
    %;      minus_minus
    %;      (==)        % *only* useful when comparing floats with integers
    %;      (/=)
    ;       (=<)
    ;       (<)
    ;       (>=)
    ;       (>)
    ;       (=:=)
    ;       (=/=)
    ;       andalso     % short circuiting
    ;       orelse      % short circuiting
    .

%-----------------------------------------------------------------------------%

    % Some useful constants.
    %
:- func elds_true = elds_term.
:- func elds_false = elds_term.
:- func elds_fail = elds_term.
:- func elds_throw_atom = elds_term.
:- func elds_empty_tuple = elds_term.

    % We implement commits by throwing Erlang exceptions with this
    % distinguishing atom as the first element of the tuple.
    %
:- func elds_commit_marker = elds_expr.

:- func elds_call_builtin(string, list(elds_expr)) = elds_expr.
:- func elds_call_element(prog_var, int) = elds_expr.

:- func var_eq_false(prog_var) = elds_expr.

:- func term_from_var(prog_var) = elds_term.
:- func terms_from_vars(prog_vars) = list(elds_term).

:- func expr_from_var(prog_var) = elds_expr.
:- func exprs_from_vars(prog_vars) = list(elds_expr).

:- func terms_from_fixed_vars(list(string)) = list(elds_term).
:- func exprs_from_fixed_vars(list(string)) = list(elds_expr).

    % Convert an expression to a term, aborting on failure.
    %
:- func expr_to_term(elds_expr) = elds_term.

    % Join two expressions into one block expression, flattening any nested
    % blocks.
    %
:- func join_exprs(elds_expr, elds_expr) = elds_expr.

    % maybe_join_exprs(ExprA, MaybeExprB)
    %
    % Join ExprA and ExprB as above if MaybeExprB = `yes(ExprB)',
    % otherwise return ExprA.
    %
:- func maybe_join_exprs(elds_expr, maybe(elds_expr)) = elds_expr.

    % maybe_join_exprs1(MaybeExprA, ExprB)
    %
    % Join ExprA and ExprB as above if MaybeExprA = `yes(ExprA)',
    % otherwise return ExprB.
    %
:- func maybe_join_exprs1(maybe(elds_expr), elds_expr) = elds_expr.

    % expr_or_void(MaybeExpr)
    %
    % Return `E' if MaybeExpr is `yes(E)', otherwise return any constant
    % expression.  This function should only be used if the return value
    % doesn't matter if MaybeExpr can be `no'.
    %
:- func expr_or_void(maybe(elds_expr)) = elds_expr.

    % det_expr(MaybeExpr)
    %
    % Return Expr if MaybeExpr is `yes(Expr)', otherwise abort.
    %
:- func det_expr(maybe(elds_expr)) = elds_expr.

:- func elds_body_arity(elds_body) = arity.

:- func elds_clause_arity(elds_clause) = arity.

    %
    % make_enum_alternative(F)
    %
    % returns the erlang representation of the functor, F, provided
    % F is part of an enum type.
    % An enum type is a du type where none of the functors have arguments.
    % eg :- type t ---> f ; g ; h.
    %
:- func make_enum_alternative(string) = elds_term.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module libs.compiler_util.

%-----------------------------------------------------------------------------%

elds_true = elds_atom_raw("true").
elds_false = elds_atom_raw("false").
elds_fail = elds_atom_raw("fail").
elds_throw_atom = elds_atom_raw("throw").
elds_empty_tuple = elds_tuple([]).

elds_commit_marker = elds_term(elds_atom_raw("MERCURY_COMMIT")).

elds_call_builtin(FunName, Exprs) =
    elds_call(elds_call_builtin(FunName), Exprs).

% Arguments are flipped from the Erlang for currying.
elds_call_element(Var, Index) = elds_call_builtin("element",
    [elds_term(elds_int(Index)), expr_from_var(Var)]).

var_eq_false(Var) = elds_eq(expr_from_var(Var), elds_term(elds_false)).

term_from_var(Var) = elds_var(Var).
terms_from_vars(Vars) = list.map(term_from_var, Vars).

expr_from_var(Var) = elds_term(elds_var(Var)).
exprs_from_vars(Vars) = list.map(expr_from_var, Vars).

terms_from_fixed_vars(Names) =
    list.map(func(X) = elds_fixed_name_var(X), Names).
exprs_from_fixed_vars(Names) =
    list.map(func(X) = elds_term(elds_fixed_name_var(X)), Names).

expr_to_term(Expr) = Term :-
    ( Expr = elds_term(Term0) ->
        Term = Term0
    ;
        unexpected(this_file, "unable to convert elds_expr to elds_term")
    ).

join_exprs(ExprA, ExprB) = Expr :-
    ( ExprA = elds_block(As0) ->
        As = As0
    ;
        As = [ExprA]
    ),
    ( ExprB = elds_block(Bs0) ->
        Bs = Bs0
    ;
        Bs = [ExprB]
    ),
    AsBs = As ++ Bs,
    ( AsBs = [SingleExpr] ->
        Expr = SingleExpr
    ;
        Expr = elds_block(AsBs)
    ).

maybe_join_exprs(ExprA, yes(ExprB)) = join_exprs(ExprA, ExprB).
maybe_join_exprs(Expr, no) = Expr.

maybe_join_exprs1(yes(ExprA), ExprB) = join_exprs(ExprA, ExprB).
maybe_join_exprs1(no, Expr) = Expr.

expr_or_void(yes(Expr)) = Expr.
expr_or_void(no) = elds_term(elds_atom_raw("void")).

det_expr(yes(Expr)) = Expr.
det_expr(no) = _ :-
    unexpected(this_file, "det_expr: no expression").

elds_body_arity(body_defined_here(Clause)) = elds_clause_arity(Clause).
elds_body_arity(body_external(Arity)) = Arity.

elds_clause_arity(elds_clause(Args, _Expr)) = list.length(Args).

make_enum_alternative(F) = elds_tuple([elds_term(elds_atom(unqualified(F)))]).

%-----------------------------------------------------------------------------%

:- func this_file = string.

this_file = "elds.m".

%-----------------------------------------------------------------------------%
