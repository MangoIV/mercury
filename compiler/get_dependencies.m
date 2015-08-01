%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 1996-2011 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: get_dependencies.m.
%
% This module finds out what other things the contents of a given module
% depend on. These "things" can be
%
% - other Mercury modules that this module imports or uses,
% - files containing fact tables, or
% - foreign language source or header files.
%
%-----------------------------------------------------------------------------%

:- module parse_tree.get_dependencies.
:- interface.

:- import_module libs.globals.
:- import_module mdbcomp.sym_name.
:- import_module parse_tree.prog_data.
:- import_module parse_tree.prog_item.

:- import_module list.

%-----------------------------------------------------------------------------%

    % get_dependencies_in_{items,item_blocks}(Items, ImportDeps, UseDeps):
    %
    % Get the list of modules that a list of items (explicitly) depends on.
    % ImportDeps is the list of modules imported using `:- import_module',
    % UseDeps is the list of modules imported using `:- use_module'.
    % N.B. Typically you also need to consider the module's implicit
    % dependencies (see get_implicit_dependencies/3), its parent modules
    % (see get_ancestors/1) and possibly also the module's child modules
    % (see get_children/2). You may also need to consider indirect
    % dependencies.
    %
:- pred get_dependencies_in_items(list(item)::in,
    list(module_name)::out, list(module_name)::out) is det.
:- pred get_dependencies_in_item_blocks(list(item_block(MS))::in,
    list(module_name)::out, list(module_name)::out) is det.

    % get_dependencies_int_imp_in_raw_item_blocks(RawItemBlocs,
    %   IntImportDeps, IntUseDeps, ImpImportDeps, ImpUseDeps):
    %
    % Get the list of modules that a list of items (explicitly) depends on.
    %
    % IntImportDeps is the list of modules imported using `:- import_module'
    % in the interface, and ImpImportDeps those modules imported in the
    % implementation. IntUseDeps is the list of modules imported using
    % `:- use_module' in the interface, and ImpUseDeps those modules imported
    % in the implementation.
    %
    % N.B. Typically you also need to consider the module's implicit
    % dependencies (see get_implicit_dependencies/3), its parent modules
    % (see get_ancestors/1) and possibly also the module's child modules
    % (see get_children/2). You may also need to consider indirect
    % dependencies.
    %
:- pred get_dependencies_int_imp_in_raw_item_blocks(list(raw_item_block)::in,
    list(module_name)::out, list(module_name)::out,
    list(module_name)::out, list(module_name)::out) is det.

    % get_implicit_dependencies_in_*(Globals, Items/ItemBlocks,
    %   ImportDeps, UseDeps):
    %
    % Get the list of builtin modules (e.g. "public_builtin",
    % "private_builtin" etc) that the given items may implicitly depend on.
    % ImportDeps is the list of modules which should be automatically
    % implicitly imported as if via `:- import_module', and UseDeps is
    % the list which should be automatically implicitly imported as if via
    % `:- use_module'.
    %
:- pred get_implicit_dependencies_in_item_blocks(globals::in,
    list(item_block(MS))::in,
    list(module_name)::out, list(module_name)::out) is det.
:- pred get_implicit_dependencies_in_items(globals::in,
    list(item)::in,
    list(module_name)::out, list(module_name)::out) is det.

    % Get the fact table dependencies for the given list of items.
    %
:- pred get_fact_table_dependencies_in_item_blocks(list(item_block(MS))::in,
    list(string)::out) is det.

    % Get foreign include_file dependencies for a module.
    % This replicates part of get_item_list_foreign_code.
    %
:- pred get_foreign_include_files_in_item_blocks(list(item_block(MS))::in,
    foreign_include_file_infos::out) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module libs.options.
:- import_module mdbcomp.builtin_modules.
:- import_module parse_tree.status.

:- import_module bool.
:- import_module cord.
:- import_module maybe.
:- import_module require.
:- import_module set.
:- import_module term.

%-----------------------------------------------------------------------------%

% XXX ITEM_LIST: consider reordering these predicates.

get_dependencies_in_item_blocks(ItemBlocks, ImportDeps, UseDeps) :-
    get_dependencies_in_item_blocks_acc(ItemBlocks,
        set.init, ImportDepsSet, set.init, UseDepsSet),
    ImportDeps = set.to_sorted_list(ImportDepsSet),
    UseDeps = set.to_sorted_list(UseDepsSet).

:- pred get_dependencies_in_item_blocks_acc(list(item_block(MS))::in,
    set(module_name)::in, set(module_name)::out,
    set(module_name)::in, set(module_name)::out) is det.

get_dependencies_in_item_blocks_acc([], !ImportDeps, !UseDeps).
get_dependencies_in_item_blocks_acc([ItemBlock | ItemBlocks],
        !ImportDeps, !UseDeps) :-
    ItemBlock = item_block(_Section, _Context, Items),
    get_dependencies_in_items_acc(Items, !ImportDeps, !UseDeps),
    get_dependencies_in_item_blocks_acc(ItemBlocks,
        !ImportDeps, !UseDeps).

%-----------------------------------------------------------------------------%

get_dependencies_int_imp_in_raw_item_blocks(RawItemBlocks,
        IntImportDeps, IntUseDeps,
        ImpImportDeps, ImpUseDeps) :-
    get_dependencies_in_int_imp_in_raw_item_blocks_acc(RawItemBlocks,
        set.init, IntImportDepsSet, set.init, IntUseDepsSet,
        set.init, ImpImportDepsSet, set.init, ImpUseDepsSet),
    IntImportDeps = set.to_sorted_list(IntImportDepsSet),
    ImpImportDeps = set.to_sorted_list(ImpImportDepsSet),
    IntUseDeps = set.to_sorted_list(IntUseDepsSet),
    ImpUseDeps = set.to_sorted_list(ImpUseDepsSet).

:- pred get_dependencies_in_int_imp_in_raw_item_blocks_acc(
    list(raw_item_block)::in,
    set(module_name)::in, set(module_name)::out,
    set(module_name)::in, set(module_name)::out,
    set(module_name)::in, set(module_name)::out,
    set(module_name)::in, set(module_name)::out) is det.

get_dependencies_in_int_imp_in_raw_item_blocks_acc([],
        !IntImportDeps, !IntUseDeps, !ImpImportDeps, !ImpUseDeps).
get_dependencies_in_int_imp_in_raw_item_blocks_acc(
        [RawItemBlock | RawItemBlocks],
        !IntImportDeps, !IntUseDeps, !ImpImportDeps, !ImpUseDeps) :-
    RawItemBlock = item_block(Section, _Context, Items),
    (
        Section = ms_interface,
        get_dependencies_in_items_acc(Items, !IntImportDeps, !IntUseDeps)
    ;
        Section = ms_implementation,
        get_dependencies_in_items_acc(Items, !ImpImportDeps, !ImpUseDeps)
    ),
    get_dependencies_in_int_imp_in_raw_item_blocks_acc(RawItemBlocks,
        !IntImportDeps, !IntUseDeps, !ImpImportDeps, !ImpUseDeps).

%-----------------------------------------------------------------------------%

get_dependencies_in_items(Items, ImportDeps, UseDeps) :-
    get_dependencies_in_items_acc(Items,
        set.init, ImportDepsSet, set.init, UseDepSet),
    ImportDeps = set.to_sorted_list(ImportDepsSet),
    UseDeps = set.to_sorted_list(UseDepSet).

:- pred get_dependencies_in_items_acc(list(item)::in,
    set(module_name)::in, set(module_name)::out,
    set(module_name)::in, set(module_name)::out) is det.

get_dependencies_in_items_acc([], !ImportDeps, !UseDeps).
get_dependencies_in_items_acc([Item | Items], !ImportDeps, !UseDeps) :-
    (
        Item = item_module_defn(ItemModuleDefn),
        ItemModuleDefn = item_module_defn_info(ModuleDefn, _, _),
        (
            ModuleDefn = md_import(ImportedModuleName),
            set.insert(ImportedModuleName, !ImportDeps)
        ;
            ModuleDefn = md_use(UsedModuleName),
            set.insert(UsedModuleName, !UseDeps)
        ;
            ModuleDefn = md_include_module(_)
        )
    ;
        ( Item = item_clause(_)
        ; Item = item_type_defn(_)
        ; Item = item_inst_defn(_)
        ; Item = item_mode_defn(_)
        ; Item = item_pred_decl(_)
        ; Item = item_mode_decl(_)
        ; Item = item_pragma(_)
        ; Item = item_promise(_)
        ; Item = item_typeclass(_)
        ; Item = item_instance(_)
        ; Item = item_initialise(_)
        ; Item = item_finalise(_)
        ; Item = item_mutable(_)
        ; Item = item_nothing(_)
        )
    ),
    get_dependencies_in_items_acc(Items, !ImportDeps, !UseDeps).

%-----------------------------------------------------------------------------%

get_implicit_dependencies_in_items(Globals, Items, ImportDeps, UseDeps) :-
    ImplicitImportNeeds0 = init_implicit_import_needs,
    gather_implicit_import_needs_in_items(Items,
        ImplicitImportNeeds0, ImplicitImportNeeds),
    compute_implicit_import_needs(Globals, ImplicitImportNeeds,
        ImportDeps, UseDeps).

get_implicit_dependencies_in_item_blocks(Globals, ItemBlocks,
        ImportDeps, UseDeps) :-
    ImplicitImportNeeds0 = init_implicit_import_needs,
    gather_implicit_import_needs_in_item_blocks(ItemBlocks,
        ImplicitImportNeeds0, ImplicitImportNeeds),
    compute_implicit_import_needs(Globals, ImplicitImportNeeds,
        ImportDeps, UseDeps).

:- pred compute_implicit_import_needs(globals::in, implicit_import_needs::in,
    list(module_name)::out, list(module_name)::out) is det.

compute_implicit_import_needs(Globals, ImplicitImportNeeds,
        !:ImportDeps, !:UseDeps) :-
    !:ImportDeps = [mercury_public_builtin_module],
    !:UseDeps = [mercury_private_builtin_module],
    ImplicitImportNeeds = implicit_import_needs(
        ItemsNeedTabling, ItemsNeedTablingStatistics,
        ItemsNeedSTM, ItemsNeedException,
        ItemsNeedStringFormat, ItemsNeedStreamFormat, ItemsNeedIO),
    % We should include mercury_table_builtin_module if the Items contain
    % a tabling pragma, or if one of --use-minimal-model (either kind) and
    % --trace-table-io is specified. In the former case, we may also need
    % to import mercury_table_statistics_module.
    (
        ItemsNeedTabling = do_need_tabling,
        !:UseDeps = [mercury_table_builtin_module | !.UseDeps],
        (
            ItemsNeedTablingStatistics = do_need_tabling_statistics,
            !:UseDeps = [mercury_table_statistics_module | !.UseDeps]
        ;
            ItemsNeedTablingStatistics = dont_need_tabling_statistics
        )
    ;
        ItemsNeedTabling = dont_need_tabling,
        expect(unify(ItemsNeedTablingStatistics, dont_need_tabling_statistics),
            $module, $pred, "tabling statistics without tabling"),
        (
            % These forms of tabling cannot ask for statistics.
            (
                globals.lookup_bool_option(Globals,
                    use_minimal_model_stack_copy, yes)
            ;
                globals.lookup_bool_option(Globals,
                    use_minimal_model_own_stacks, yes)
            ;
                globals.lookup_bool_option(Globals, trace_table_io, yes)
            )
        ->
            !:UseDeps = [mercury_table_builtin_module | !.UseDeps]
        ;
            true
        )
    ),
    (
        ItemsNeedSTM = do_need_stm,
        !:UseDeps = [mercury_stm_builtin_module, mercury_exception_module,
            mercury_univ_module | !.UseDeps]
    ;
        ItemsNeedSTM = dont_need_stm
    ),
    (
        ItemsNeedException = do_need_exception,
        !:UseDeps = [mercury_exception_module | !.UseDeps]
    ;
        ItemsNeedException = dont_need_exception
    ),
    (
        ItemsNeedStringFormat = do_need_string_format,
        !:UseDeps = [mercury_string_format_module,
            mercury_string_parse_util_module | !.UseDeps]
    ;
        ItemsNeedStringFormat = dont_need_string_format
    ),
    (
        ItemsNeedStreamFormat = do_need_stream_format,
        !:UseDeps = [mercury_stream_module | !.UseDeps]
    ;
        ItemsNeedStreamFormat = dont_need_stream_format
    ),
    (
        ItemsNeedIO = do_need_io,
        !:UseDeps = [mercury_io_module | !.UseDeps]
    ;
        ItemsNeedIO = dont_need_io
    ),
    globals.lookup_bool_option(Globals, profile_deep, Deep),
    (
        Deep = yes,
        !:UseDeps = [mercury_profiling_builtin_module | !.UseDeps]
    ;
        Deep = no
    ),
    (
        (
            globals.lookup_bool_option(Globals,
                record_term_sizes_as_words, yes)
        ;
            globals.lookup_bool_option(Globals,
                record_term_sizes_as_cells, yes)
        )
    ->
        !:UseDeps = [mercury_term_size_prof_builtin_module | !.UseDeps]
    ;
        true
    ),
    globals.get_target(Globals, Target),
    globals.lookup_bool_option(Globals, highlevel_code, HighLevelCode),
    globals.lookup_bool_option(Globals, parallel, Parallel),
    (
        Target = target_c,
        HighLevelCode = no,
        Parallel = yes
    ->
        !:UseDeps = [mercury_par_builtin_module | !.UseDeps]
    ;
        true
    ),
    globals.lookup_bool_option(Globals, use_regions, UseRegions),
    (
        UseRegions = yes,
        !:UseDeps = [mercury_region_builtin_module | !.UseDeps]
    ;
        UseRegions = no
    ),
    globals.get_ssdb_trace_level(Globals, SSDBTraceLevel),
    globals.lookup_bool_option(Globals, force_disable_ssdebug, DisableSSDB),
    (
        ( SSDBTraceLevel = shallow
        ; SSDBTraceLevel = deep
        ),
        DisableSSDB = no
    ->
        !:UseDeps = [mercury_ssdb_builtin_module | !.UseDeps]
    ;
        true
    ),
    list.sort_and_remove_dups(!ImportDeps),
    list.sort_and_remove_dups(!UseDeps).

:- type maybe_need_tabling
    --->    dont_need_tabling
    ;       do_need_tabling.

:- type maybe_need_tabling_statistics
    --->    dont_need_tabling_statistics
    ;       do_need_tabling_statistics.

:- type maybe_need_stm
    --->    dont_need_stm
    ;       do_need_stm.

:- type maybe_need_exception
    --->    dont_need_exception
    ;       do_need_exception.

:- type maybe_need_string_format
    --->    dont_need_string_format
    ;       do_need_string_format.

:- type maybe_need_stream_format
    --->    dont_need_stream_format
    ;       do_need_stream_format.

:- type maybe_need_io
    --->    dont_need_io
    ;       do_need_io.

    % XXX We currently discover the need to import the modules needed
    % to compile away format strings by traversing all parts of all clauses,
    % and checking every predicate name and functor name to see whether
    % it could refer to any of the predicates recognized by the is_format_call
    % predicate. This is inefficient. It is also a bit unpredictable, since
    % it will lead us to implicitly import those modules even if a call
    % to unqualified("format") eventually turns out to call some other
    % predicate of that name.
    %
    % We should therefore consider ALWAYS implicitly importing the predicates
    % needed by format_call.m.
:- type implicit_import_needs
    --->    implicit_import_needs(
                iin_tabling             :: maybe_need_tabling,
                iin_tabling_statistics  :: maybe_need_tabling_statistics,
                iin_stm                 :: maybe_need_stm,
                iin_exception           :: maybe_need_exception,
                iin_string_format       :: maybe_need_string_format,
                iin_stream_format       :: maybe_need_stream_format,
                iin_io                  :: maybe_need_io
            ).

:- func init_implicit_import_needs = implicit_import_needs.

init_implicit_import_needs = ImplicitImportNeeds :-
    ImplicitImportNeeds = implicit_import_needs(
        dont_need_tabling, dont_need_tabling_statistics,
        dont_need_stm, dont_need_exception,
        dont_need_string_format, dont_need_stream_format, dont_need_io).

:- pred gather_implicit_import_needs_in_item_blocks(list(item_block(MS))::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_item_blocks([], !ImplicitImportNeeds).
gather_implicit_import_needs_in_item_blocks([ItemBlock | ItemBlocks],
        !ImplicitImportNeeds) :-
    ItemBlock = item_block(_Section, _Context, Items),
    gather_implicit_import_needs_in_items(Items,
        !ImplicitImportNeeds),
    gather_implicit_import_needs_in_item_blocks(ItemBlocks,
        !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_items(list(item)::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_items([], !ImplicitImportNeeds).
gather_implicit_import_needs_in_items([Item | Items], !ImplicitImportNeeds) :-
    (
        Item = item_clause(ItemClause),
        gather_implicit_import_needs_in_clause(ItemClause,
            !ImplicitImportNeeds)
    ;
        Item = item_pragma(ItemPragma),
        ItemPragma = item_pragma_info(Pragma, _Origin, _Context, _SeqNum),
        (
            Pragma = pragma_tabled(TableInfo),
            TableInfo = pragma_info_tabled(_, _, _, MaybeAttributes),
            !ImplicitImportNeeds ^ iin_tabling := do_need_tabling,
            (
                MaybeAttributes = no
            ;
                MaybeAttributes = yes(Attributes),
                StatsAttr = Attributes ^ table_attr_statistics,
                (
                    StatsAttr = table_gather_statistics,
                    !ImplicitImportNeeds ^ iin_tabling_statistics
                        := do_need_tabling_statistics
                ;
                    StatsAttr = table_dont_gather_statistics
                )
            )
        ;
            ( Pragma = pragma_foreign_decl(_)
            ; Pragma = pragma_foreign_code(_)
            ; Pragma = pragma_foreign_proc(_)
            ; Pragma = pragma_foreign_import_module(_)
            ; Pragma = pragma_foreign_proc_export(_)
            ; Pragma = pragma_foreign_export_enum(_)
            ; Pragma = pragma_foreign_enum(_)
            ; Pragma = pragma_external_proc(_)
            ; Pragma = pragma_type_spec(_)
            ; Pragma = pragma_inline(_)
            ; Pragma = pragma_no_inline(_)
            ; Pragma = pragma_unused_args(_)
            ; Pragma = pragma_exceptions(_)
            ; Pragma = pragma_trailing_info(_)
            ; Pragma = pragma_mm_tabling_info(_)
            ; Pragma = pragma_obsolete(_)
            ; Pragma = pragma_no_detism_warning(_)
            ; Pragma = pragma_fact_table(_)
            ; Pragma = pragma_reserve_tag(_)
            ; Pragma = pragma_oisu(_)
            ; Pragma = pragma_promise_eqv_clauses(_)
            ; Pragma = pragma_promise_pure(_)
            ; Pragma = pragma_promise_semipure(_)
            ; Pragma = pragma_termination_info(_)
            ; Pragma = pragma_termination2_info(_)
            ; Pragma = pragma_terminates(_)
            ; Pragma = pragma_does_not_terminate(_)
            ; Pragma = pragma_check_termination(_)
            ; Pragma = pragma_mode_check_clauses(_)
            ; Pragma = pragma_structure_sharing(_)
            ; Pragma = pragma_structure_reuse(_)
            ; Pragma = pragma_require_feature_set(_)
            )
        )
    ;
        Item = item_promise(ItemPromise),
        ItemPromise = item_promise_info(_PromiseType, Goal, _VarSet,
            _UnivQuantVars, _Context, _SeqNum),
        gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds)
    ;
        Item = item_instance(ItemInstance),
        ItemInstance = item_instance_info(_DerivingClass, _ClassName,
            _Types, _OriginalTypes, InstanceBody, _VarSet,
            _ModuleContainingInstance, _Context, _SeqNum),
        (
            InstanceBody = instance_body_abstract
        ;
            InstanceBody = instance_body_concrete(InstanceMethods),
            list.foldl(gather_implicit_import_needs_in_instance_method,
                InstanceMethods, !ImplicitImportNeeds)
        )
    ;
        Item = item_mutable(ItemMutableInfo),
        gather_implicit_import_needs_in_mutable(ItemMutableInfo,
            !ImplicitImportNeeds)
    ;
        Item = item_type_defn(ItemTypeDefn),
        ItemTypeDefn = item_type_defn_info(_TypeCtorName, _TypeParams,
            TypeDefn, _TVarSet, _Context, _SeqNum),
        (
            TypeDefn = parse_tree_du_type(_Constructor,
                _MaybeUnifyComparePredNames, _MaybeDirectArgs)
        ;
            TypeDefn = parse_tree_eqv_type(_EqvType)
        ;
            TypeDefn = parse_tree_abstract_type(_Details)
        ;
            TypeDefn = parse_tree_solver_type(SolverTypeDetails,
                _MaybeUnifyComparePredNames),
            SolverTypeDetails = solver_type_details(_RepresentationType,
                _InitPred, _GroundInst, _AnyInst, MutableItems),
            list.foldl(gather_implicit_import_needs_in_mutable, MutableItems,
                !ImplicitImportNeeds)
        ;
            TypeDefn = parse_tree_foreign_type(_ForeignLangType,
                _MaybeUnifyComparePredNames, _ForeignAssertions)
        )
    ;
        ( Item = item_module_defn(_)
        ; Item = item_inst_defn(_)
        ; Item = item_mode_defn(_)
        ; Item = item_pred_decl(_)
        ; Item = item_mode_decl(_)
        ; Item = item_typeclass(_)
        ; Item = item_initialise(_)
        ; Item = item_finalise(_)
        ; Item = item_nothing(_)
        )
    ),
    gather_implicit_import_needs_in_items(Items, !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_instance_method(instance_method::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_instance_method(InstanceMethod,
        !ImplicitImportNeeds) :-
    InstanceMethod = instance_method(_PredOrFunc, _MethodName, ProcDef,
        _Arity, _Context),
    (
        ProcDef = instance_proc_def_name(_Name)
    ;
        ProcDef = instance_proc_def_clauses(ItemClauses),
        list.foldl(gather_implicit_import_needs_in_clause, ItemClauses,
            !ImplicitImportNeeds)
    ).

:- pred gather_implicit_import_needs_in_mutable(item_mutable_info::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_mutable(ItemMutableInfo,
        !ImplicitImportNeeds) :-
    ItemMutableInfo = item_mutable_info(_Name, _Type, InitValue, _Inst,
        _Attrs, _VarSet, _Context, _SeqNum),
    gather_implicit_import_needs_in_term(InitValue, !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_clause(item_clause_info::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_clause(ItemClause, !ImplicitImportNeeds) :-
    ItemClause = item_clause_info(_PredName,_PredOrFunc, HeadTerms,
        _Origin, _VarSet, Goal, _Context, _SeqNum),
    gather_implicit_import_needs_in_terms(HeadTerms, !ImplicitImportNeeds),
    gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_goal(goal::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds) :-
    (
        ( Goal = true_expr(_)
        ; Goal = fail_expr(_)
        )
        % Cannot contain anything that requires implicit imports.
    ;
        ( Goal = conj_expr(_, SubGoalA, SubGoalB)
        ; Goal = par_conj_expr(_, SubGoalA, SubGoalB)
        ; Goal = disj_expr(_, SubGoalA, SubGoalB)
        ; Goal = implies_expr(_, SubGoalA, SubGoalB)
        ; Goal = equivalent_expr(_, SubGoalA, SubGoalB)
        ),
        gather_implicit_import_needs_in_goal(SubGoalA, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_goal(SubGoalB, !ImplicitImportNeeds)
    ;
        ( Goal = not_expr(_, SubGoal)
        ; Goal = some_expr(_, _Vars, SubGoal)
        ; Goal = all_expr(_, _Vars, SubGoal)
        ; Goal = some_state_vars_expr(_, _Vars, SubGoal)
        ; Goal = all_state_vars_expr(_, _Vars, SubGoal)
        ; Goal = promise_purity_expr(_, _Purity, SubGoal)
        ; Goal = promise_equivalent_solutions_expr(_, _OrdVars,
            _StateVars, _DotVars, _ColonVars, SubGoal)
        ; Goal = promise_equivalent_solution_sets_expr(_, _OrdVars,
            _StateVars, _DotVars, _ColonVars, SubGoal)
        ; Goal = promise_equivalent_solution_arbitrary_expr(_, _OrdVars,
            _StateVars, _DotVars, _ColonVars, SubGoal)
        ; Goal = require_detism_expr(_, _Detism, SubGoal)
        ; Goal = require_complete_switch_expr(_, _SwitchVar, SubGoal)
        ; Goal = require_switch_arms_detism_expr(_, _SwitchVar, _Detism,
            SubGoal)
        ),
        gather_implicit_import_needs_in_goal(SubGoal, !ImplicitImportNeeds)
    ;
        Goal = trace_expr(_, _CompCond, _RunCond, MaybeIO, _Mutables,
            SubGoal),
        (
            MaybeIO = yes(_),
            !ImplicitImportNeeds ^ iin_io := do_need_io
        ;
            MaybeIO = no
        ),
        gather_implicit_import_needs_in_goal(SubGoal, !ImplicitImportNeeds)
    ;
        Goal = try_expr(_, _MaybeIO, SubGoal, Then, MaybeElse,
            Catches, MaybeCatchAny),
        !ImplicitImportNeeds ^ iin_exception := do_need_exception,
        gather_implicit_import_needs_in_goal(SubGoal, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_goal(Then, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_maybe_goal(MaybeElse,
            !ImplicitImportNeeds),
        gather_implicit_import_needs_in_catch_exprs(Catches,
            !ImplicitImportNeeds),
        gather_implicit_import_needs_in_maybe_catch_any_expr(MaybeCatchAny,
            !ImplicitImportNeeds)
    ;
        Goal = if_then_else_expr(_, _Vars, _StateVars, Cond, Then, Else),
        gather_implicit_import_needs_in_goal(Cond, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_goal(Then, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_goal(Else, !ImplicitImportNeeds)
    ;
        Goal = atomic_expr(_, _Outer, _Inner, _OutputVars,
            MainGoal, OrElseGoals),
        !ImplicitImportNeeds ^ iin_stm := do_need_stm,
        !ImplicitImportNeeds ^ iin_exception := do_need_exception,
        gather_implicit_import_needs_in_goal(MainGoal, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_goals(OrElseGoals,
            !ImplicitImportNeeds)
    ;
        Goal = call_expr(_, CalleeSymName, Args, _Purity),
        ( if
            CalleeSymName = qualified(ModuleName, "format")
        then
            ( if 
                ( ModuleName = unqualified("string")
                ; ModuleName = unqualified("io")
                )
            then
                % For io.format, we need to pull in the same modules
                % as for string.format.
                !ImplicitImportNeeds ^ iin_string_format
                    := do_need_string_format
            else if
                ( ModuleName = unqualified("stream")
                ; ModuleName = unqualified("string_writer")
                ; ModuleName = qualified(unqualified("stream"),
                    "string_writer")
                )
            then
                % The replacement of calls to stream.string_writer.format
                % needs everything that the replacement of calls to
                % string.format or io.format needs.
                !ImplicitImportNeeds ^ iin_string_format
                    := do_need_string_format,
                !ImplicitImportNeeds ^ iin_stream_format
                    := do_need_stream_format
            else
                % The callee cannot be any of the predicates that
                % format_call.m is designed to optimize.
                true
            )
        else if
            CalleeSymName = unqualified("format")
        then
            % We don't know whether this will resolve to string.format,
            % io.format, or stream.string.writer.format. Ideally, we would
            % set iin_stream_format only if the current context contains
            % an import of stream.string_writer.m, but we don't have that
            % information here, or in our caller.
            !ImplicitImportNeeds ^ iin_string_format := do_need_string_format,
            !ImplicitImportNeeds ^ iin_stream_format := do_need_stream_format
        else
            true
        ),
        gather_implicit_import_needs_in_terms(Args, !ImplicitImportNeeds)
    ;
        Goal = event_expr(_, _EventName, EventArgs),
        gather_implicit_import_needs_in_terms(EventArgs, !ImplicitImportNeeds)
    ;
        Goal = unify_expr(_, TermA, TermB, _Purity),
        gather_implicit_import_needs_in_term(TermA, !ImplicitImportNeeds),
        gather_implicit_import_needs_in_term(TermB, !ImplicitImportNeeds)
    ).

:- pred gather_implicit_import_needs_in_goals(list(goal)::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_goals([], !ImplicitImportNeeds).
gather_implicit_import_needs_in_goals([Goal | Goals], !ImplicitImportNeeds) :-
    gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds),
    gather_implicit_import_needs_in_goals(Goals, !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_maybe_goal(maybe(goal)::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_maybe_goal(no, !ImplicitImportNeeds).
gather_implicit_import_needs_in_maybe_goal(yes(Goal), !ImplicitImportNeeds) :-
    gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_catch_exprs(list(catch_expr)::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_catch_exprs([], !ImplicitImportNeeds).
gather_implicit_import_needs_in_catch_exprs([CatchExpr | CatchExprs],
        !ImplicitImportNeeds) :-
    CatchExpr = catch_expr(_Pattern, Goal),
    gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds),
    gather_implicit_import_needs_in_catch_exprs(CatchExprs,
        !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_maybe_catch_any_expr(
    maybe(catch_any_expr)::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_maybe_catch_any_expr(no, !ImplicitImportNeeds).
gather_implicit_import_needs_in_maybe_catch_any_expr(yes(CatchAnyExpr),
        !ImplicitImportNeeds) :-
    CatchAnyExpr = catch_any_expr(_Var, Goal),
    gather_implicit_import_needs_in_goal(Goal, !ImplicitImportNeeds).

:- pred gather_implicit_import_needs_in_term(prog_term::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_term(Term, !ImplicitImportNeeds) :-
    (
        Term = variable(_Var, _Context)
    ;
        Term = functor(Const, ArgTerms, _Context),
        (
            Const = atom(Atom),
            ( if
                Atom = "format"
            then
                !ImplicitImportNeeds ^ iin_string_format
                    := do_need_string_format,
                !ImplicitImportNeeds ^ iin_stream_format
                    := do_need_stream_format
            else if
                ( Atom = "string.format"
                ; Atom = "string__format"
                ; Atom = "io.format"
                ; Atom = "io__format"
                )
            then
                !ImplicitImportNeeds ^ iin_string_format
                    := do_need_string_format
            else if
                ( Atom = "stream.format"
                ; Atom = "stream__format"
                ; Atom = "string_writer.format"
                ; Atom = "string_writer__format"
                ; Atom = "stream.string_writer.format"
                ; Atom = "stream.string_writer__format"
                ; Atom = "stream__string_writer.format"
                ; Atom = "stream__string_writer__format"
                )
            then
                % The replacement of calls to stream.string_writer.format
                % needs everything that the replacement of calls to
                % string.format or io.format needs.
                !ImplicitImportNeeds ^ iin_string_format
                    := do_need_string_format,
                !ImplicitImportNeeds ^ iin_stream_format
                    := do_need_stream_format
            else
                true
            )
        ;
            ( Const = integer(_)
            ; Const = big_integer(_, _)
            ; Const = string(_)
            ; Const = float(_)
            ; Const = implementation_defined(_)
            )
        ),
        gather_implicit_import_needs_in_terms(ArgTerms, !ImplicitImportNeeds)
    ).

:- pred gather_implicit_import_needs_in_terms(list(prog_term)::in,
    implicit_import_needs::in, implicit_import_needs::out) is det.

gather_implicit_import_needs_in_terms([], !ImplicitImportNeeds).
gather_implicit_import_needs_in_terms([Term | Terms], !ImplicitImportNeeds) :-
    gather_implicit_import_needs_in_term(Term, !ImplicitImportNeeds),
    gather_implicit_import_needs_in_terms(Terms, !ImplicitImportNeeds).

%-----------------------------------------------------------------------------%

get_fact_table_dependencies_in_item_blocks(ItemBlocks, FactTableFileNames) :-
    gather_fact_table_dependencies_in_blocks(ItemBlocks,
        [], RevFactTableFileNames),
    list.reverse(RevFactTableFileNames, FactTableFileNames).

:- pred gather_fact_table_dependencies_in_blocks(list(item_block(MS))::in,
    list(string)::in, list(string)::out) is det.

gather_fact_table_dependencies_in_blocks([], !RevFactTableFileNames).
gather_fact_table_dependencies_in_blocks([ItemBlock | ItemBlocks],
        !RevFactTableFileNames) :-
    ItemBlock = item_block(_, _, Items),
    gather_fact_table_dependencies_in_items(Items, !RevFactTableFileNames),
    gather_fact_table_dependencies_in_blocks(ItemBlocks,
        !RevFactTableFileNames).

:- pred gather_fact_table_dependencies_in_items(list(item)::in,
    list(string)::in, list(string)::out) is det.

gather_fact_table_dependencies_in_items([], !RevFactTableFileNames).
gather_fact_table_dependencies_in_items([Item | Items],
        !RevFactTableFileNames) :-
    (
        Item = item_pragma(ItemPragma),
        ItemPragma = item_pragma_info(Pragma, _, _, _),
        Pragma = pragma_fact_table(FTInfo),
        FTInfo = pragma_info_fact_table(_PredNameArity, FileName)
    ->
        !:RevFactTableFileNames = [FileName | !.RevFactTableFileNames]
    ;
        true
    ),
    gather_fact_table_dependencies_in_items(Items, !RevFactTableFileNames).

%-----------------------------------------------------------------------------%

get_foreign_include_files_in_item_blocks(ItemBlocks, IncludeFiles) :-
    list.foldl(gather_foreign_include_files_in_item_blocks_acc, ItemBlocks,
        cord.init, IncludeFiles).

:- pred gather_foreign_include_files_in_item_blocks_acc(item_block(_)::in,
    cord(foreign_include_file_info)::in, cord(foreign_include_file_info)::out)
    is det.

gather_foreign_include_files_in_item_blocks_acc(ItemBlock, !IncludeFiles) :-
    ItemBlock = item_block(_, _, Items),
    gather_foreign_include_files_in_items_acc(Items, !IncludeFiles).

:- pred gather_foreign_include_files_in_items_acc(list(item)::in,
    cord(foreign_include_file_info)::in, cord(foreign_include_file_info)::out)
    is det.

gather_foreign_include_files_in_items_acc([], !IncludeFiles).
gather_foreign_include_files_in_items_acc([Item | Items], !IncludeFiles) :-
    (
        Item = item_pragma(ItemPragma),
        ItemPragma = item_pragma_info(Pragma, _, _, _),
        (
            Pragma = pragma_foreign_decl(FDInfo),
            FDInfo = pragma_info_foreign_decl(Lang, _IsLocal, LiteralOrInclude)
        ;
            Pragma = pragma_foreign_code(FCInfo),
            FCInfo = pragma_info_foreign_code(Lang, LiteralOrInclude)
        )
    ->
        (
            LiteralOrInclude = literal(_)
        ;
            LiteralOrInclude = include_file(FileName),
            IncludeFile = foreign_include_file_info(Lang, FileName),
            !:IncludeFiles = cord.snoc(!.IncludeFiles, IncludeFile)
        )
    ;
        true
    ),
    gather_foreign_include_files_in_items_acc(Items, !IncludeFiles).

%-----------------------------------------------------------------------------%
:- end_module parse_tree.get_dependencies.
%-----------------------------------------------------------------------------%
