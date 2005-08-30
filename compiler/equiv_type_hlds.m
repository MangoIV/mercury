%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2003-2005 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% Main author: stayl.
%
% Expand all types in the module_info using all equivalence type definitions,
% even those local to (transitively) imported modules.
%
% This is necessary to avoid problems with back-ends that don't support
% equivalence types properly (or at all).
%
%-----------------------------------------------------------------------------%
:- module transform_hlds__equiv_type_hlds.

:- interface.

:- import_module hlds__hlds_module.

:- pred replace_in_hlds(module_info::in, module_info::out) is det.

:- implementation.

:- import_module check_hlds__mode_util.
:- import_module check_hlds__type_util.
:- import_module check_hlds__polymorphism.
:- import_module hlds__goal_util.
:- import_module hlds__hlds_goal.
:- import_module hlds__hlds_pred.
:- import_module hlds__hlds_data.
:- import_module hlds__instmap.
:- import_module hlds__quantification.
:- import_module mdbcomp__prim_data.
:- import_module parse_tree__equiv_type.
:- import_module parse_tree__prog_data.
:- import_module parse_tree__prog_type.
:- import_module recompilation.

:- import_module bool.
:- import_module list.
:- import_module map.
:- import_module require.
:- import_module set.
:- import_module std_util.
:- import_module string.
:- import_module svmap.
:- import_module term.
:- import_module varset.

replace_in_hlds(!ModuleInfo) :-
    module_info_types(!.ModuleInfo, Types0),
    map__foldl2(add_type_to_eqv_map, Types0, map__init, EqvMap,
        set__init, EqvExportTypes),
    set__fold(mark_eqv_exported_types, EqvExportTypes, Types0, Types1),

    module_info_get_maybe_recompilation_info(!.ModuleInfo, MaybeRecompInfo0),
    module_info_name(!.ModuleInfo, ModuleName),
    map__map_foldl(replace_in_type_defn(ModuleName, EqvMap), Types1, Types,
        MaybeRecompInfo0, MaybeRecompInfo),
    module_info_set_types(Types, !ModuleInfo),
    module_info_set_maybe_recompilation_info(MaybeRecompInfo, !ModuleInfo),

    InstCache0 = map__init,

    module_info_insts(!.ModuleInfo, Insts0),
    replace_in_inst_table(EqvMap, Insts0, Insts, InstCache0, InstCache1),
    module_info_set_insts(Insts, !ModuleInfo),

    module_info_predids(!.ModuleInfo, PredIds),
    list__foldl2(replace_in_pred(EqvMap), PredIds, !ModuleInfo, InstCache1, _).

:- pred add_type_to_eqv_map(type_ctor::in, hlds_type_defn::in,
    eqv_map::in, eqv_map::out, set(type_ctor)::in, set(type_ctor)::out)
    is det.

add_type_to_eqv_map(TypeCtor, Defn, !EqvMap, !EqvExportTypes) :-
    hlds_data__get_type_defn_body(Defn, Body),
    ( Body = eqv_type(EqvType) ->
        hlds_data__get_type_defn_tvarset(Defn, TVarSet),
        hlds_data__get_type_defn_tparams(Defn, Params),
        hlds_data__get_type_defn_status(Defn, Status),
        map__det_insert(!.EqvMap, TypeCtor,
            eqv_type_body(TVarSet, Params, EqvType), !:EqvMap),
        ( status_is_exported(Status, yes) ->
            add_type_ctors_to_set(EqvType, !EqvExportTypes)
        ;
            true
        )
    ;
        true
    ).

:- pred add_type_ctors_to_set((type)::in,
    set(type_ctor)::in, set(type_ctor)::out) is det.

add_type_ctors_to_set(Type, !Set) :-
    ( type_to_ctor_and_args(Type, TypeCtor, Args) ->
        set__insert(!.Set, TypeCtor, !:Set),
        list__foldl(add_type_ctors_to_set, Args, !Set)
    ;
        true
    ).

:- pred mark_eqv_exported_types(type_ctor::in, type_table::in, type_table::out)
    is det.

mark_eqv_exported_types(TypeCtor, !TypeTable) :-
    ( map__search(!.TypeTable, TypeCtor, Defn0) ->
        set_type_defn_in_exported_eqv(yes, Defn0, Defn),
        map__det_update(!.TypeTable, TypeCtor, Defn, !:TypeTable)
    ;
        % We can get here for builtin `types' such as func. Since
        % their unify and compare preds are in the runtime system,
        % not generated by the compiler, marking them as exported
        % in the compiler is moot.
        true
    ).

:- pred replace_in_type_defn(module_name::in, eqv_map::in, type_ctor::in,
    hlds_type_defn::in, hlds_type_defn::out,
    maybe(recompilation_info)::in, maybe(recompilation_info)::out) is det.

replace_in_type_defn(ModuleName, EqvMap, TypeCtor, !Defn, !MaybeRecompInfo) :-
    hlds_data__get_type_defn_tvarset(!.Defn, TVarSet0),
    hlds_data__get_type_defn_body(!.Defn, Body0),
    equiv_type__maybe_record_expanded_items(ModuleName, fst(TypeCtor),
        !.MaybeRecompInfo, EquivTypeInfo0),
    (
        Body0 = du_type(Ctors0, _, _, _, _, _),
        equiv_type__replace_in_ctors(EqvMap, Ctors0, Ctors,
            TVarSet0, TVarSet, EquivTypeInfo0, EquivTypeInfo),
        Body = Body0 ^ du_type_ctors := Ctors
    ;
        Body0 = eqv_type(Type0),
        equiv_type__replace_in_type(EqvMap, Type0, Type, _,
            TVarSet0, TVarSet, EquivTypeInfo0, EquivTypeInfo),
        Body = eqv_type(Type)
    ;
        Body0 = foreign_type(_),
        EquivTypeInfo = EquivTypeInfo0,
        Body = Body0,
        TVarSet = TVarSet0
    ;
        Body0 = solver_type(SolverTypeDetails0, UserEq),
        SolverTypeDetails0 = solver_type_details(RepnType0, InitPred,
                    GroundInst, AnyInst),
        equiv_type__replace_in_type(EqvMap, RepnType0, RepnType, _,
            TVarSet0, TVarSet, EquivTypeInfo0, EquivTypeInfo),
        SolverTypeDetails = solver_type_details(RepnType, InitPred,
            GroundInst, AnyInst),
        Body = solver_type(SolverTypeDetails, UserEq)
    ;
        Body0 = abstract_type(_),
        EquivTypeInfo = EquivTypeInfo0,
        Body = Body0,
        TVarSet = TVarSet0
    ),
    equiv_type__finish_recording_expanded_items(
        item_id(type_body, TypeCtor), EquivTypeInfo, !MaybeRecompInfo),
    hlds_data__set_type_defn_body(Body, !Defn),
    hlds_data__set_type_defn_tvarset(TVarSet, !Defn).

:- pred replace_in_inst_table(eqv_map::in,
    inst_table::in, inst_table::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_inst_table(EqvMap, !InstTable, !Cache) :-
%   %
%   % We currently have no syntax for typed user-defined insts,
%   % so this is unnecessary.
%   %
%   inst_table_get_user_insts(!.InstTable, UserInsts0),
%   map__map_values(
%       (pred(_::in, Defn0::in, Defn::out) is det :-
%           Body0 = Defn0 ^ inst_body,
%           (
%               Body0 = abstract_inst,
%               Defn = Defn0
%           ;
%               Body0 = eqv_inst(Inst0),
%               % XXX We don't have a valid tvarset here.
%               TVarSet0 = varset__init.
%               replace_in_inst(EqvMap, Inst0, Inst,
%                   TVarSet0, _)
%           )
%       ). UserInsts0, UserInsts),
%   inst_table_set_user_insts(!.InstTable, UserInsts, !:InstTable),

    inst_table_get_unify_insts(!.InstTable, UnifyInsts0),
    inst_table_get_merge_insts(!.InstTable, MergeInsts0),
    inst_table_get_ground_insts(!.InstTable, GroundInsts0),
    inst_table_get_any_insts(!.InstTable, AnyInsts0),
    inst_table_get_shared_insts(!.InstTable, SharedInsts0),
    inst_table_get_mostly_uniq_insts(!.InstTable, MostlyUniqInsts0),
    replace_in_inst_table(replace_in_maybe_inst_det(EqvMap),
        EqvMap, UnifyInsts0, UnifyInsts, !Cache),
    replace_in_merge_inst_table(EqvMap, MergeInsts0, MergeInsts, !Cache),
    replace_in_inst_table(replace_in_maybe_inst_det(EqvMap),
        EqvMap, GroundInsts0, GroundInsts, !Cache),
    replace_in_inst_table(replace_in_maybe_inst_det(EqvMap),
        EqvMap, AnyInsts0, AnyInsts, !Cache),
    replace_in_inst_table(replace_in_maybe_inst(EqvMap),
        EqvMap, SharedInsts0, SharedInsts, !Cache),
    replace_in_inst_table(replace_in_maybe_inst(EqvMap),
        EqvMap, MostlyUniqInsts0, MostlyUniqInsts, !.Cache, _),
    inst_table_set_unify_insts(UnifyInsts, !InstTable),
    inst_table_set_merge_insts(MergeInsts, !InstTable),
    inst_table_set_ground_insts(GroundInsts, !InstTable),
    inst_table_set_any_insts(AnyInsts, !InstTable),
    inst_table_set_shared_insts(SharedInsts, !InstTable),
    inst_table_set_mostly_uniq_insts(MostlyUniqInsts, !InstTable).

:- pred replace_in_inst_table(
    pred(T, T, inst_cache, inst_cache)::(pred(in, out, in, out) is det),
    eqv_map::in, map(inst_name, T)::in, map(inst_name, T)::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_inst_table(P, EqvMap, Map0, Map, !Cache) :-
    map__to_assoc_list(Map0, AL0),
    list__map_foldl(
        (pred((Name0 - T0)::in, (Name - T)::out,
                !.Cache::in, !:Cache::out) is det :-
            % XXX We don't have a valid tvarset here.
            varset__init(TVarSet),
            replace_in_inst_name(EqvMap, Name0, Name,
                _, TVarSet, _, !Cache),
            P(T0, T, !Cache)
        ), AL0, AL, !Cache),
    map__from_assoc_list(AL, Map).

:- pred replace_in_merge_inst_table(eqv_map::in, merge_inst_table::in,
        merge_inst_table::out, inst_cache::in, inst_cache::out) is det.

replace_in_merge_inst_table(EqvMap, Map0, Map, !Cache) :-
    map__to_assoc_list(Map0, AL0),
    list__map_foldl(
        (pred(((InstA0 - InstB0) - MaybeInst0)::in,
                ((InstA - InstB) - MaybeInst)::out,
                !.Cache::in, !:Cache::out) is det :-
            some [!TVarSet] (
                % XXX We don't have a valid tvarset here.
                !:TVarSet = varset__init,
                replace_in_inst(EqvMap, InstA0, InstA, _, !TVarSet, !Cache),
                replace_in_inst(EqvMap, InstB0, InstB, _, !.TVarSet, _,
                    !Cache),
                replace_in_maybe_inst(EqvMap, MaybeInst0, MaybeInst, !Cache)
            )
        ), AL0, AL, !Cache),
    map__from_assoc_list(AL, Map).

:- pred replace_in_maybe_inst(eqv_map::in, maybe_inst::in, maybe_inst::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_maybe_inst(_, unknown, unknown, !Cache).
replace_in_maybe_inst(EqvMap, known(Inst0), known(Inst), !Cache) :-
    % XXX We don't have a valid tvarset here.
    varset__init(TVarSet),
    replace_in_inst(EqvMap, Inst0, Inst, _, TVarSet, _, !Cache).

:- pred replace_in_maybe_inst_det(eqv_map::in,
    maybe_inst_det::in, maybe_inst_det::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_maybe_inst_det(_, unknown, unknown, !Cache).
replace_in_maybe_inst_det(EqvMap, known(Inst0, Det), known(Inst, Det),
        !Cache) :-
    % XXX We don't have a valid tvarset here.
    varset__init(TVarSet),
    replace_in_inst(EqvMap, Inst0, Inst, _, TVarSet, _, !Cache).

:- pred replace_in_pred(eqv_map::in, pred_id::in,
    module_info::in, module_info::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_pred(EqvMap, PredId, !ModuleInfo, !Cache) :-
    some [!PredInfo, !EquivTypeInfo] (
    module_info_name(!.ModuleInfo, ModuleName),
    module_info_pred_info(!.ModuleInfo, PredId, !:PredInfo),
    module_info_get_maybe_recompilation_info(!.ModuleInfo, MaybeRecompInfo0),

    PredName = pred_info_name(!.PredInfo),
    equiv_type__maybe_record_expanded_items(ModuleName,
        qualified(ModuleName, PredName), MaybeRecompInfo0, !:EquivTypeInfo),

    pred_info_arg_types(!.PredInfo, ArgTVarSet0, ExistQVars, ArgTypes0),
    equiv_type__replace_in_type_list(EqvMap, ArgTypes0, ArgTypes,
        _, ArgTVarSet0, ArgTVarSet1, !EquivTypeInfo),

    % The constraint_proofs aren't used after polymorphism,
    % so they don't need to be processed.
    pred_info_get_class_context(!.PredInfo, ClassContext0),
    equiv_type__replace_in_prog_constraints(EqvMap, ClassContext0,
        ClassContext, ArgTVarSet1, ArgTVarSet, !EquivTypeInfo),
    pred_info_set_class_context(ClassContext, !PredInfo),
        pred_info_set_arg_types(ArgTVarSet, ExistQVars, ArgTypes, !PredInfo),

    ItemId = item_id(pred_or_func_to_item_type(
        pred_info_is_pred_or_func(!.PredInfo)),
        qualified(pred_info_module(!.PredInfo), PredName) -
            pred_info_orig_arity(!.PredInfo)),
    equiv_type__finish_recording_expanded_items(ItemId,
        !.EquivTypeInfo, MaybeRecompInfo0, MaybeRecompInfo),
    module_info_set_maybe_recompilation_info(MaybeRecompInfo, !ModuleInfo),

        pred_info_procedures(!.PredInfo, Procs0),
    map__map_foldl(
        replace_in_proc(EqvMap), Procs0, Procs,
            {!.ModuleInfo, !.PredInfo, !.Cache},
            {!:ModuleInfo, !:PredInfo, !:Cache}),
        pred_info_set_procedures(Procs, !PredInfo),
        module_info_set_pred_info(PredId, !.PredInfo, !ModuleInfo)
    ).

:- pred replace_in_proc(eqv_map::in, proc_id::in,
    proc_info::in, proc_info::out,
    {module_info, pred_info, inst_cache}::in,
    {module_info, pred_info, inst_cache}::out) is det.

replace_in_proc(EqvMap, _, !ProcInfo, {!.ModuleInfo, !.PredInfo, !.Cache},
        {!:ModuleInfo, !:PredInfo, !:Cache}) :-
    some [!TVarSet] (
        pred_info_typevarset(!.PredInfo, !:TVarSet),

        proc_info_argmodes(!.ProcInfo, ArgModes0),
        replace_in_modes(EqvMap, ArgModes0, ArgModes, _, !TVarSet, !Cache),
        proc_info_set_argmodes(ArgModes, !ProcInfo),

        proc_info_maybe_declared_argmodes(!.ProcInfo, MaybeDeclModes0),
        (
            MaybeDeclModes0 = yes(DeclModes0),
            replace_in_modes(EqvMap, DeclModes0, DeclModes, _, !TVarSet,
                !Cache),
            proc_info_set_maybe_declared_argmodes(yes(DeclModes), !ProcInfo)
        ;
            MaybeDeclModes0 = no
        ),

        proc_info_vartypes(!.ProcInfo, VarTypes0),
        map__map_foldl(
            (pred(_::in, VarType0::in, VarType::out,
                    !.TVarSet::in, !:TVarSet::out) is det :-
                equiv_type__replace_in_type(EqvMap,
                    VarType0, VarType, _, !TVarSet, no, _)
            ),
            VarTypes0, VarTypes, !TVarSet),
        proc_info_set_vartypes(VarTypes, !ProcInfo),

        proc_info_rtti_varmaps(!.ProcInfo, RttiVarMaps0),
        rtti_varmaps_types(RttiVarMaps0, AllTypes),
        list__foldl2(
            (pred(OldType::in, !.TMap::in, !:TMap::out,
                    !.TVarSet::in, !:TVarSet::out) is det :-
                equiv_type__replace_in_type(EqvMap, OldType, NewType, _,
                    !TVarSet, no, _),
                svmap__set(OldType, NewType, !TMap)
            ), AllTypes, map__init, TypeMap, !TVarSet),
        rtti_varmaps_transform_types(
            (pred(!.VarMapType::in, !:VarMapType::out) is det :-
                map__lookup(TypeMap, !VarMapType)
            ), RttiVarMaps0, RttiVarMaps),
        proc_info_set_rtti_varmaps(RttiVarMaps, !ProcInfo),

        proc_info_goal(!.ProcInfo, Goal0),
        replace_in_goal(EqvMap, Goal0, Goal, Changed,
            replace_info(!.ModuleInfo, !.PredInfo, !.ProcInfo, !.TVarSet,
                !.Cache, no),
            replace_info(!:ModuleInfo, !:PredInfo, !:ProcInfo, !:TVarSet,
                _XXX, Recompute)),
        ( Changed = yes, proc_info_set_goal(Goal, !ProcInfo)
        ; Changed = no
        ),

        (
            Recompute = yes,
            requantify_proc(!ProcInfo),
            recompute_instmap_delta_proc(no, !ProcInfo, !ModuleInfo)
        ;
            Recompute = no
        ),

        pred_info_set_typevarset(!.TVarSet, !PredInfo)
    ).

%-----------------------------------------------------------------------------%

% Note that we go out of our way to avoid duplicating unchanged
% insts and modes.  This means we don't need to hash-cons those
% insts to avoid losing sharing.

:- pred replace_in_modes(eqv_map::in, list(mode)::in, list(mode)::out,
    bool::out, tvarset::in, tvarset::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_modes(_EqvMap, [], [], no, !TVarSet, !Cache).
replace_in_modes(EqvMap, List0 @ [Mode0 | Modes0], List, Changed,
        !TVarSet, !Cache) :-
    replace_in_mode(EqvMap, Mode0, Mode, Changed0, !TVarSet, !Cache),
    replace_in_modes(EqvMap, Modes0, Modes, Changed1, !TVarSet, !Cache),
    Changed = Changed0 `or` Changed1,
    ( Changed = yes, List = [Mode | Modes]
    ; Changed = no, List = List0
    ).

:- pred replace_in_mode(eqv_map::in, (mode)::in, (mode)::out, bool::out,
    tvarset::in, tvarset::out, inst_cache::in, inst_cache::out) is det.

replace_in_mode(EqvMap, Mode0 @ (InstA0 -> InstB0), Mode,
        Changed, !TVarSet, !Cache) :-
    replace_in_inst(EqvMap, InstA0, InstA, ChangedA, !TVarSet, !Cache),
    replace_in_inst(EqvMap, InstB0, InstB, ChangedB, !TVarSet, !Cache),
    Changed = ChangedA `or` ChangedB,
    ( Changed = yes, Mode = (InstA -> InstB)
    ; Changed = no, Mode = Mode0
    ).
replace_in_mode(EqvMap, Mode0 @ user_defined_mode(Name, Insts0), Mode,
        Changed, !TVarSet, !Cache) :-
    replace_in_insts(EqvMap, Insts0, Insts, Changed, !TVarSet, !Cache),
    ( Changed = yes, Mode = user_defined_mode(Name, Insts)
    ; Changed = no, Mode = Mode0
    ).

:- pred replace_in_inst(eqv_map::in, (inst)::in, (inst)::out,
    bool::out, tvarset::in, tvarset::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_inst(EqvMap, Inst0, Inst, Changed, !TVarSet, !Cache) :-
    replace_in_inst_2(EqvMap, Inst0, Inst1, Changed, !TVarSet, !Cache),
    (
        Changed = yes,
        % Doing this when the inst has not changed is too slow,
        % and makes the cache potentially very large.
        hash_cons_inst(Inst1, Inst, !Cache)
    ;
        Changed = no,
        Inst = Inst1
    ).

:- pred replace_in_inst_2(eqv_map::in, (inst)::in, (inst)::out, bool::out,
    tvarset::in, tvarset::out, inst_cache::in, inst_cache::out) is det.

replace_in_inst_2(_, any(_) @ Inst, Inst, no, !TVarSet, !Cache).
replace_in_inst_2(_, free @ Inst, Inst, no, !TVarSet, !Cache).
replace_in_inst_2(EqvMap, Inst0 @ free(Type0), Inst, Changed,
        !TVarSet, !Cache) :-
    equiv_type__replace_in_type(EqvMap, Type0, Type, Changed, !TVarSet, no, _),
    ( Changed = yes, Inst = free(Type)
    ; Changed = no, Inst = Inst0
    ).
replace_in_inst_2(EqvMap, Inst0 @ bound(Uniq, BoundInsts0), Inst,
        Changed, !TVarSet, !Cache) :-
    replace_in_bound_insts(EqvMap, BoundInsts0, BoundInsts, Changed, !TVarSet,
        !Cache),
    ( Changed = yes, Inst = bound(Uniq, BoundInsts)
    ; Changed = no, Inst = Inst0
    ).
replace_in_inst_2(_, ground(_, none) @ Inst, Inst, no, !TVarSet, !Cache).
replace_in_inst_2(EqvMap,
        Inst0 @ ground(Uniq,
            higher_order(pred_inst_info(PorF, Modes0, Det))),
        Inst, Changed, !TVarSet, !Cache) :-
    replace_in_modes(EqvMap, Modes0, Modes, Changed, !TVarSet, !Cache),
    (
        Changed = yes,
        Inst = ground(Uniq, higher_order(pred_inst_info(PorF, Modes, Det)))
    ;
        Changed = no,
        Inst = Inst0
    ).
replace_in_inst_2(_, not_reached @ Inst, Inst, no, !TVarSet, !Cache).
replace_in_inst_2(_, inst_var(_) @ Inst, Inst, no, !TVarSet, !Cache).
replace_in_inst_2(EqvMap, Inst0 @ constrained_inst_vars(Vars, CInst0), Inst,
        Changed, !TVarSet, !Cache) :-
    replace_in_inst(EqvMap, CInst0, CInst, Changed, !TVarSet, !Cache),
    ( Changed = yes, Inst = constrained_inst_vars(Vars, CInst)
    ; Changed = no, Inst = Inst0
    ).
replace_in_inst_2(EqvMap, Inst0 @ defined_inst(InstName0), Inst,
         Changed, !TVarSet, !Cache) :-
    replace_in_inst_name(EqvMap, InstName0, InstName, Changed,
        !TVarSet, !Cache),
    ( Changed = yes, Inst = defined_inst(InstName)
    ; Changed = no, Inst = Inst0
    ).
replace_in_inst_2(EqvMap, Inst0 @ abstract_inst(Name, Insts0), Inst,
        Changed, !TVarSet, !Cache) :-
    replace_in_insts(EqvMap, Insts0, Insts, Changed, !TVarSet, !Cache),
    ( Changed = yes, Inst = abstract_inst(Name, Insts)
    ; Changed = no, Inst = Inst0
    ).

:- pred replace_in_inst_name(eqv_map::in, inst_name::in, inst_name::out,
    bool::out, tvarset::in, tvarset::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_inst_name(EqvMap, InstName0 @ user_inst(Name, Insts0), InstName,
        Changed, !TVarSet, !Cache) :-
    replace_in_insts(EqvMap, Insts0, Insts, Changed, !TVarSet, !Cache),
    ( Changed = yes, InstName = user_inst(Name, Insts)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ merge_inst(InstA0, InstB0), InstName,
        Changed, !TVarSet, !Cache) :-
    replace_in_inst(EqvMap, InstA0, InstA, ChangedA, !TVarSet, !Cache),
    replace_in_inst(EqvMap, InstB0, InstB, ChangedB, !TVarSet, !Cache),
    Changed = ChangedA `or` ChangedB,
    ( Changed = yes, InstName = merge_inst(InstA, InstB)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap,
        InstName0 @ unify_inst(Live, InstA0, InstB0, Real),
        InstName, Changed, !TVarSet, !Cache) :-
    replace_in_inst(EqvMap, InstA0, InstA, ChangedA, !TVarSet, !Cache),
    replace_in_inst(EqvMap, InstB0, InstB, ChangedB, !TVarSet, !Cache),
    Changed = ChangedA `or` ChangedB,
    ( Changed = yes, InstName = unify_inst(Live, InstA, InstB, Real)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ ground_inst(Name0, Live, Uniq, Real),
        InstName, Changed, !TVarSet, !Cache) :-
    replace_in_inst_name(EqvMap, Name0, Name, Changed, !TVarSet, !Cache),
    ( Changed = yes, InstName = ground_inst(Name, Live, Uniq, Real)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ any_inst(Name0, Live, Uniq, Real),
        InstName, Changed, !TVarSet, !Cache) :-
    replace_in_inst_name(EqvMap, Name0, Name, Changed, !TVarSet, !Cache),
    ( Changed = yes, InstName = any_inst(Name, Live, Uniq, Real)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ shared_inst(Name0), InstName,
         Changed, !TVarSet, !Cache) :-
    replace_in_inst_name(EqvMap, Name0, Name, Changed, !TVarSet, !Cache),
    ( Changed = yes, InstName = shared_inst(Name)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ mostly_uniq_inst(Name0),
        InstName, Changed, !TVarSet, !Cache) :-
    replace_in_inst_name(EqvMap, Name0, Name, Changed, !TVarSet, !Cache),
    ( Changed = yes, InstName = mostly_uniq_inst(Name)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ typed_ground(Uniq, Type0), InstName,
        Changed, !TVarSet, !Cache) :-
    replace_in_type(EqvMap, Type0, Type, Changed, !TVarSet, no, _),
    ( Changed = yes, InstName = typed_ground(Uniq, Type)
    ; Changed = no, InstName = InstName0
    ).
replace_in_inst_name(EqvMap, InstName0 @ typed_inst(Type0, Name0),
        InstName, Changed, !TVarSet, !Cache) :-
    replace_in_type(EqvMap, Type0, Type, TypeChanged, !TVarSet, no, _),
    replace_in_inst_name(EqvMap, Name0, Name, Changed0, !TVarSet, !Cache),
    Changed = TypeChanged `or` Changed0,
    ( Changed = yes, InstName = typed_inst(Type, Name)
    ; Changed = no, InstName = InstName0
    ).

:- pred replace_in_bound_insts(eqv_map::in, list(bound_inst)::in,
    list(bound_inst)::out, bool::out, tvarset::in, tvarset::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_bound_insts(_EqvMap, [], [], no, !TVarSet, !Cache).
replace_in_bound_insts(EqvMap, List0 @ [functor(ConsId, Insts0) | BoundInsts0],
        List, Changed, !TVarSet, !Cache) :-
    replace_in_insts(EqvMap, Insts0, Insts,
        InstsChanged, !TVarSet, !Cache),
    replace_in_bound_insts(EqvMap, BoundInsts0, BoundInsts,
        BoundInstsChanged, !TVarSet, !Cache),
    Changed = InstsChanged `or` BoundInstsChanged,
    ( Changed = yes, List = [functor(ConsId, Insts) | BoundInsts]
    ; Changed = no, List = List0
    ).

:- pred replace_in_insts(eqv_map::in, list(inst)::in, list(inst)::out,
    bool::out, tvarset::in, tvarset::out,
    inst_cache::in, inst_cache::out) is det.

replace_in_insts(_EqvMap, [], [], no, !TVarSet, !Cache).
replace_in_insts(EqvMap, List0 @ [Inst0 | Insts0], List, Changed,
        !TVarSet, !Cache) :-
    replace_in_inst(EqvMap, Inst0, Inst, Changed0, !TVarSet, !Cache),
    replace_in_insts(EqvMap, Insts0, Insts, Changed1, !TVarSet, !Cache),
    Changed = Changed0 `or` Changed1,
    ( Changed = yes, List = [Inst | Insts]
    ; Changed = no, List = List0
    ).

    % We hash-cons (actually map-cons) insts created by this pass
    % to avoid losing sharing.
:- type inst_cache == map(inst, inst).

:- pred hash_cons_inst((inst)::in, (inst)::out,
    inst_cache::in, inst_cache::out) is det.

hash_cons_inst(Inst0, Inst, !Cache) :-
    ( Inst1 = map__search(!.Cache, Inst0) ->
        Inst = Inst1
    ;
        Inst = Inst0,
        !:Cache = map__det_insert(!.Cache, Inst, Inst)
    ).

%-----------------------------------------------------------------------------%

:- type replace_info
    --->    replace_info(
                module_info :: module_info,
                pred_info   :: pred_info,
                proc_info   :: proc_info,
                tvarset     :: tvarset,
                inst_cache  :: inst_cache,
                recompute   :: bool
            ).

:- pred replace_in_goal(eqv_map::in)
    `with_type` replacer(hlds_goal, replace_info)
    `with_inst` replacer.

replace_in_goal(EqvMap, Goal0 @ (GoalExpr0 - GoalInfo0), Goal,
        Changed, !Info) :-
    replace_in_goal_expr(EqvMap, GoalExpr0, GoalExpr, Changed0, !Info),

    goal_info_get_instmap_delta(GoalInfo0, InstMapDelta0),
    TVarSet0 = !.Info ^ tvarset,
    Cache0 = !.Info ^ inst_cache,
    instmap_delta_map_foldl(
        (pred(_::in, Inst0::in, Inst::out,
                {Changed1, TVarSet1, Cache1}::in,
                {Changed1 `or` InstChanged, TVarSet2, Cache2}::out) is det :-
            replace_in_inst(EqvMap, Inst0, Inst, InstChanged,
                TVarSet1, TVarSet2, Cache1, Cache2)
        ), InstMapDelta0, InstMapDelta,
        {Changed0, TVarSet0, Cache0}, {Changed, TVarSet, Cache}),
    (
        Changed = yes,
        !:Info = (!.Info ^ tvarset := TVarSet) ^ inst_cache := Cache,
        goal_info_set_instmap_delta(InstMapDelta, GoalInfo0, GoalInfo),
        Goal = GoalExpr - GoalInfo
    ;
        Changed = no,
        Goal = Goal0
    ).

:- pred replace_in_goal_expr(eqv_map::in)
    `with_type` replacer(hlds_goal_expr, replace_info)
    `with_inst` replacer.

replace_in_goal_expr(EqvMap, Goal0 @ conj(Goals0), Goal, Changed, !Info) :-
    replace_in_list(replace_in_goal(EqvMap), Goals0, Goals,
        Changed, !Info),
    ( Changed = yes, Goal = conj(Goals)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ par_conj(Goals0), Goal, Changed, !Info) :-
    replace_in_list(replace_in_goal(EqvMap), Goals0, Goals,
        Changed, !Info),
    ( Changed = yes, Goal = par_conj(Goals)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ disj(Goals0), Goal, Changed, !Info) :-
    replace_in_list(replace_in_goal(EqvMap), Goals0, Goals,
        Changed, !Info),
    ( Changed = yes, Goal = disj(Goals)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ switch(A, B, Cases0), Goal, Changed,
        !Info) :-
    replace_in_list(
        (pred((Case0 @ case(ConsId, CaseGoal0))::in, Case::out,
                CaseChanged::out, !.Info::in, !:Info::out) is det :-
            replace_in_goal(EqvMap, CaseGoal0, CaseGoal,
                CaseChanged, !Info),
            ( CaseChanged = yes, Case = case(ConsId, CaseGoal)
            ; CaseChanged = no, Case = Case0
            )
        ), Cases0, Cases, Changed, !Info),
    ( Changed = yes, Goal = switch(A, B, Cases)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ not(NegGoal0), Goal, Changed, !Info) :-
    replace_in_goal(EqvMap, NegGoal0, NegGoal, Changed, !Info),
    ( Changed = yes, Goal = not(NegGoal)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ scope(Reason, SomeGoal0), Goal,
        Changed, !Info) :-
    replace_in_goal(EqvMap, SomeGoal0, SomeGoal, Changed, !Info),
    ( Changed = yes, Goal = scope(Reason, SomeGoal)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ if_then_else(Vars, Cond0, Then0, Else0),
        Goal, Changed, !Info) :-
    replace_in_goal(EqvMap, Cond0, Cond, Changed1, !Info),
    replace_in_goal(EqvMap, Then0, Then, Changed2, !Info),
    replace_in_goal(EqvMap, Else0, Else, Changed3, !Info),
    Changed = Changed1 `or` Changed2 `or` Changed3,
    ( Changed = yes, Goal = if_then_else(Vars, Cond, Then, Else)
    ; Changed = no, Goal = Goal0
    ).
replace_in_goal_expr(_, Goal @ call(_, _, _, _, _, _), Goal, no, !Info).
replace_in_goal_expr(EqvMap, Goal0 @ foreign_proc(_, _, _, _, _, _), Goal,
        Changed, !Info) :-
    TVarSet0 = !.Info ^ tvarset,
    replace_in_foreign_arg_list(EqvMap, Goal0 ^ foreign_args,
        Args, ChangedArgs, TVarSet0, TVarSet1, no, _),
    replace_in_foreign_arg_list(EqvMap, Goal0 ^ foreign_extra_args,
        ExtraArgs, ChangedExtraArgs, TVarSet1, TVarSet, no, _),
    Changed = ChangedArgs `or` ChangedExtraArgs,
    (
        Changed = yes,
        !:Info = !.Info ^ tvarset := TVarSet,
        Goal = (Goal0 ^ foreign_args := Args) ^ foreign_extra_args := ExtraArgs
    ;
        Changed = no,
        Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ generic_call(A, B, Modes0, D), Goal,
        Changed, !Info) :-
    TVarSet0 = !.Info ^ tvarset,
    Cache0 = !.Info ^ inst_cache,
    replace_in_modes(EqvMap, Modes0, Modes, Changed, TVarSet0, TVarSet,
        Cache0, Cache),
    (
        Changed = yes,
        !:Info = (!.Info ^ tvarset := TVarSet) ^ inst_cache := Cache,
        Goal = generic_call(A, B, Modes, D)
    ;
        Changed = no,
        Goal = Goal0
    ).
replace_in_goal_expr(EqvMap, Goal0 @ unify(Var, _, _, _, _), Goal,
        Changed, !Info) :-
    module_info_types(!.Info ^ module_info, Types),
    proc_info_vartypes(!.Info ^ proc_info, VarTypes),
    map__lookup(VarTypes, Var, VarType),
    classify_type(!.Info ^ module_info, VarType) = TypeCat,
    (
        %
        % If this goal constructs a type_info for an equivalence
        % type, we need to expand that to make the type_info for
        % the expanded type.  It's simpler to just recreate the
        % type-info from scratch.
        %
        Goal0 ^ unify_kind = construct(_, ConsId, _, _, _, _, _),
        ConsId = type_info_cell_constructor(TypeCtor),
        TypeCat = type_info_type,
        map__search(Types, TypeCtor, TypeDefn),
        hlds_data__get_type_defn_body(TypeDefn, Body),
        Body = eqv_type(_),
        type_to_ctor_and_args(VarType, _TypeInfoCtor,
            [TypeInfoArgType])
    ->
        Changed = yes,
        pred_info_set_typevarset(!.Info ^ tvarset, !.Info ^ pred_info,
            PredInfo0),
        create_poly_info(!.Info ^ module_info, PredInfo0, !.Info ^ proc_info,
            PolyInfo0),
        polymorphism__make_type_info_var(TypeInfoArgType,
            term__context_init, TypeInfoVar, Goals0, PolyInfo0, PolyInfo),
        poly_info_extract(PolyInfo, PredInfo0, PredInfo,
            !.Info ^ proc_info, ProcInfo, ModuleInfo),
        pred_info_typevarset(PredInfo, TVarSet),
        !:Info = (((!.Info ^ pred_info := PredInfo)
            ^ proc_info := ProcInfo)
            ^ module_info := ModuleInfo)
            ^ tvarset := TVarSet,

        goal_util__rename_vars_in_goals(no,
            map__from_assoc_list([TypeInfoVar - Var]), Goals0, Goals),
        ( Goals = [Goal1 - _] ->
            Goal = Goal1
        ;
            Goal = conj(Goals)
        ),
        !:Info = !.Info ^ recompute := yes
    ;
        %
        % Check for a type_ctor_info for an equivalence type.
        % We can just remove these because after the code above
        % to fix up type_infos for equivalence types they can't
        % be used.
        %
        Goal0 ^ unify_kind = construct(_, ConsId, _, _, _, _, _),
        ConsId = type_info_cell_constructor(TypeCtor),
        TypeCat = type_ctor_info_type,
        map__search(Types, TypeCtor, TypeDefn),
        hlds_data__get_type_defn_body(TypeDefn, Body),
        Body = eqv_type(_)
    ->
        Changed = yes,
        Goal = conj([]),
        !:Info = !.Info ^ recompute := yes
    ;
        Goal0 ^ unify_mode = LMode0 - RMode0,
        TVarSet0 = !.Info ^ tvarset,
        Cache0 = !.Info ^ inst_cache,
        replace_in_mode(EqvMap, LMode0, LMode, Changed1,
            TVarSet0, TVarSet1, Cache0, Cache1),
        replace_in_mode(EqvMap, RMode0, RMode, Changed2,
            TVarSet1, TVarSet, Cache1, Cache),
        !:Info = (!.Info ^ tvarset := TVarSet)
            ^ inst_cache := Cache,
        replace_in_unification(EqvMap, Goal0 ^ unify_kind, Unification,
            Changed3, !Info),
        Changed = Changed1 `or` Changed2 `or` Changed3,
        (
            Changed = yes,
            Goal = (Goal0 ^ unify_mode := LMode - RMode)
                ^ unify_kind := Unification
        ;
            Changed = no,
            Goal = Goal0
        )
    ).
replace_in_goal_expr(_, shorthand(_), _, _, !Info) :-
    error("replace_in_goal_expr: shorthand").

:- pred replace_in_unification(eqv_map::in)
    `with_type` replacer(unification, replace_info)
    `with_inst` replacer.

replace_in_unification(_, assign(_, _) @ Uni, Uni, no, !Info).
replace_in_unification(_, simple_test(_, _) @ Uni, Uni, no, !Info).
replace_in_unification(EqvMap, Uni0 @ complicated_unify(UniMode0, B, C), Uni,
        Changed, !Info) :-
    replace_in_uni_mode(EqvMap, UniMode0, UniMode, Changed, !Info),
    ( Changed = yes, Uni = complicated_unify(UniMode, B, C)
    ; Changed = no, Uni = Uni0
    ).
replace_in_unification(EqvMap, construct(_, _, _, _, _, _, _) @ Uni0, Uni,
        Changed, !Info) :-
    replace_in_list(replace_in_uni_mode(EqvMap),
        Uni0 ^ construct_arg_modes, UniModes, Changed, !Info),
    ( Changed = yes, Uni = Uni0 ^ construct_arg_modes := UniModes
    ; Changed = no, Uni = Uni0
    ).
replace_in_unification(EqvMap, deconstruct(_, _, _, _, _, _) @ Uni0, Uni,
        Changed, !Info) :-
    replace_in_list(replace_in_uni_mode(EqvMap),
        Uni0 ^ deconstruct_arg_modes, UniModes, Changed, !Info),
    ( Changed = yes, Uni = Uni0 ^ deconstruct_arg_modes := UniModes
    ; Changed = no, Uni = Uni0
    ).

:- pred replace_in_uni_mode(eqv_map::in)
    `with_type` replacer(uni_mode, replace_info)
    `with_inst` replacer.

replace_in_uni_mode(EqvMap, ((InstA0 - InstB0) -> (InstC0 - InstD0)),
        ((InstA - InstB) -> (InstC - InstD)), Changed, !Info) :-
    some [!TVarSet, !Cache] (
        !:TVarSet = !.Info ^ tvarset,
        !:Cache = !.Info ^ inst_cache,
        replace_in_inst(EqvMap, InstA0, InstA, Changed1, !TVarSet, !Cache),
        replace_in_inst(EqvMap, InstB0, InstB, Changed2, !TVarSet, !Cache),
        replace_in_inst(EqvMap, InstC0, InstC, Changed3, !TVarSet, !Cache),
        replace_in_inst(EqvMap, InstD0, InstD, Changed4, !TVarSet, !Cache),
        Changed = Changed1 `or` Changed2 `or` Changed3 `or` Changed4,
        (
            Changed = yes,
            !:Info = (!.Info ^ tvarset := !.TVarSet)
                ^ inst_cache := !.Cache
        ;
            Changed = no
        )
    ).

:- type replacer(T, Acc) == pred(T, T, bool, Acc, Acc).
:- inst replacer == (pred(in, out, out, in, out) is det).

:- pred replace_in_list(replacer(T, Acc)::in(replacer))
    `with_type` replacer(list(T), Acc) `with_inst` replacer.

replace_in_list(_, [], [], no, !Acc).
replace_in_list(Repl, List0 @ [H0 | T0], List, Changed, !Acc) :-
    replace_in_list(Repl, T0, T, Changed0, !Acc),
    Repl(H0, H, Changed1, !Acc),
    Changed = Changed0 `or` Changed1,
    ( Changed = yes, List = [H | T]
    ; Changed = no, List = List0
    ).

%-----------------------------------------------------------------------------%

    % Replace equivalence types in a given type.
    % The bool output is `yes' if anything changed.
:- pred replace_in_foreign_arg(eqv_map::in, foreign_arg::in, foreign_arg::out,
    bool::out, tvarset::in, tvarset::out,
    equiv_type_info::in, equiv_type_info::out) is det.

replace_in_foreign_arg(EqvMap, Arg0, Arg, Changed, !VarSet, !Info) :-
    Arg0 = foreign_arg(Var, NameMode, Type0),
    replace_in_type(EqvMap, Type0, Type, Changed, !VarSet, !Info),
    ( Changed = yes, Arg = foreign_arg(Var, NameMode, Type)
    ; Changed = no, Arg = Arg0
    ).

:- pred replace_in_foreign_arg_list(eqv_map::in,
    list(foreign_arg)::in, list(foreign_arg)::out, bool::out,
    tvarset::in, tvarset::out, equiv_type_info::in, equiv_type_info::out)
    is det.

replace_in_foreign_arg_list(_EqvMap, [], [], no, !VarSet, !Info).
replace_in_foreign_arg_list(EqvMap, List0 @ [A0 | As0], List,
        Changed, !VarSet, !Info) :-
    replace_in_foreign_arg(EqvMap, A0, A, Changed0, !VarSet, !Info),
    replace_in_foreign_arg_list(EqvMap, As0, As, Changed1, !VarSet, !Info),
    Changed = Changed0 `or` Changed1,
    ( Changed = yes, List = [A | As]
    ; Changed = no, List = List0
    ).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
