%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2007 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: rbmm.region_resurrection_renaming.m.
% Main author: Quan Phan.
%
% Region resurrection is the situation where the liveness of a region
% variable along an execution path is like: live, dead, live ..., i.e., the
% variable becomes bound, then unbound, then bound again. This makes region
% variables different from regular Mercury variables.
% This module finds which renaming and reversed renaming of region variables
% are needed so that region resurrection is resolved, and after applying 
% the renaming, region variables are regular Mercury variables. 
%
%-----------------------------------------------------------------------------%

:- module transform_hlds.rbmm.region_resurrection_renaming.
:- interface.

:- import_module hlds.
:- import_module hlds.hlds_pred.
:- import_module transform_hlds.smm_common.
:- import_module transform_hlds.rbmm.points_to_info.
:- import_module transform_hlds.rbmm.region_liveness_info.

:- import_module list.
:- import_module map.
:- import_module string.

%-----------------------------------------------------------------------------%

:- type renaming_table ==
	map(pred_proc_id, renaming_proc).

:- type renaming_proc ==
    map(program_point, renaming).

:- type renaming == map(string, string).

:- type renaming_annotation_table ==
    map(pred_proc_id, renaming_annotation_proc).

:- type renaming_annotation_proc ==
    map(program_point, list(string)).

:- type proc_resurrection_path_table ==
    map(pred_proc_id, exec_path_region_set_table).
    
:- type exec_path_region_set_table == map(execution_path, region_set).

:- type join_point_region_name_table ==
    map(pred_proc_id, map(program_point, string)).

:- pred compute_resurrection_paths(execution_path_table::in,
    proc_pp_region_set_table::in, proc_pp_region_set_table::in,
    proc_region_set_table::in, proc_region_set_table::in,
    proc_pp_region_set_table::out, proc_resurrection_path_table::out) is det.

:- pred collect_region_resurrection_renaming(proc_pp_region_set_table::in,
    proc_region_set_table::in, rpta_info_table::in,
    proc_resurrection_path_table::in,
    renaming_table::out) is det.

:- pred collect_join_points(renaming_table::in,
    execution_path_table::in, join_point_region_name_table::out) is det.

:- pred collect_renaming_and_annotation(renaming_table::in,
    join_point_region_name_table::in, proc_pp_region_set_table::in,
    proc_region_set_table::in, rpta_info_table::in,
    proc_resurrection_path_table::in, execution_path_table::in,
    renaming_annotation_table::out, renaming_table::out) is det.

    % Record the annotation for a procedure.
    % 
:- pred record_annotation(program_point::in, string::in,
    renaming_annotation_proc::in, renaming_annotation_proc::out) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module hlds.hlds_goal.
:- import_module libs.
:- import_module libs.compiler_util.
:- import_module transform_hlds.rbmm.points_to_graph.

:- import_module assoc_list.
:- import_module bool.
:- import_module int.
:- import_module pair.
:- import_module set.
:- import_module svmap.
:- import_module svset.

%-----------------------------------------------------------------------------%

    % This predicate traveses execution paths and computes 2 pieces of
    % information:
    % 1. The set of regions that become live before a program point
    % (for each program point in a procedure).
    % 2. For each procedure, compute the execution paths in which 
    % resurrections of regions happen. For such an execution path
    % it also calculates the regions which resurrect. Only procedures
    % which contain resurrection are kept in the results. And for such
    % procedures only execution paths that contain resurrection are
    % kept.
    %
compute_resurrection_paths(ExecPathTable, LRBeforeTable, LRAfterTable,
        BornRTable, LocalRTable, CreatedBeforeTable,
        PathContainsResurrectionTable) :-
    map.foldl2(compute_resurrection_paths_proc(LRBeforeTable, LRAfterTable,
        BornRTable, LocalRTable), ExecPathTable, 
        map.init, CreatedBeforeTable,
        map.init, PathContainsResurrectionTable).

:- pred compute_resurrection_paths_proc(proc_pp_region_set_table::in,
    proc_pp_region_set_table::in, proc_region_set_table::in, 
    proc_region_set_table::in, pred_proc_id::in, list(execution_path)::in, 
    proc_pp_region_set_table::in, proc_pp_region_set_table::out,
    proc_resurrection_path_table::in, proc_resurrection_path_table::out)
    is det.

compute_resurrection_paths_proc(LRBeforeTable, LRAfterTable, BornRTable,
        LocalRTable, PPId, ExecPaths, !CreatedBeforeTable,
        !PathContainsResurrectionTable) :-
    map.lookup(LRBeforeTable, PPId, LRBeforeProc),
    map.lookup(LRAfterTable, PPId, LRAfterProc),
    map.lookup(BornRTable, PPId, BornRProc),
    map.lookup(LocalRTable, PPId, LocalRProc),
    list.foldl2(compute_resurrection_paths_exec_path(LRBeforeProc,
        LRAfterProc, set.union(BornRProc, LocalRProc)), ExecPaths,
        map.init, CreatedBeforeProc, map.init, PathContainsResurrectionProc),
    svmap.set(PPId, CreatedBeforeProc, !CreatedBeforeTable),
    % We only want to include procedures in which resurrection happens
    % in this map.
    ( if    map.count(PathContainsResurrectionProc) = 0
      then
            true
      else
        svmap.set(PPId, PathContainsResurrectionProc,
            !PathContainsResurrectionTable)
    ).
    
:- pred compute_resurrection_paths_exec_path(pp_region_set_table::in,
    pp_region_set_table::in, region_set::in, execution_path::in, 
    pp_region_set_table::in, pp_region_set_table::out,
    exec_path_region_set_table::in, exec_path_region_set_table::out) is det.

compute_resurrection_paths_exec_path(LRBeforeProc, LRAfterProc, Born_Local,
        ExecPath, !CreatedBeforeProc, !ResurrectedRegionProc) :-
    list.foldl3(compute_resurrection_paths_prog_point(LRBeforeProc,
        LRAfterProc, Born_Local), ExecPath,
        set.init, _, !CreatedBeforeProc,
        set.init, ResurrectedRegionsInExecPath),
    % We want to record only execution paths in which resurrections
    % happen.
    ( if    set.empty(ResurrectedRegionsInExecPath)
      then
            true
      else
            svmap.set(ExecPath, ResurrectedRegionsInExecPath,
                !ResurrectedRegionProc)
    ).

:- pred compute_resurrection_paths_prog_point(pp_region_set_table::in,
    pp_region_set_table::in, region_set::in,
    pair(program_point, hlds_goal)::in, region_set::in, region_set::out,
    pp_region_set_table::in, pp_region_set_table::out,
    region_set::in, region_set::out) is det.

compute_resurrection_paths_prog_point(LRBeforeProc, LRAfterProc, Born_Local,
        ProgPoint - _, !Candidates, !CreatedBeforeProc,
        !ResurrectedRegionsInExecPath) :-
    map.lookup(LRBeforeProc, ProgPoint, LRBeforeProgPoint),
    map.lookup(LRAfterProc, ProgPoint, LRAfterProgPoint),

    % Regions which are created before this program point.
    set.intersect(Born_Local,
        set.difference(LRAfterProgPoint, LRBeforeProgPoint),
        CreatedBeforeProgPoint),
    svmap.set(ProgPoint, CreatedBeforeProgPoint, !CreatedBeforeProc),

    % Resurrected regions become live at more than one program point
    % in an execution path.
    set.intersect(!.Candidates, CreatedBeforeProgPoint, ResurrectedRegions),
    set.union(ResurrectedRegions, !ResurrectedRegionsInExecPath), 

    % When a region is known to become live at one program point, it is
    % considered a candidate for resurrection.
    set.difference(set.union(!.Candidates, CreatedBeforeProgPoint),
        !.ResurrectedRegionsInExecPath, !:Candidates).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

    % This predicate only traverses procedures with the execution paths
    % containing resurrection and computes *renaming* at the points
    % where a resurrected region becomes live.
    % The result here will also only contain procedures in which resurrection
    % happens and for each procedure only execution paths in which
    % resurrection happens.
    %
collect_region_resurrection_renaming(CreatedBeforeTable, LocalRTable,
        RptaInfoTable, PathContainsResurrectionTable,
        ResurrectionRenameTable) :-
    map.foldl(collect_region_resurrection_renaming_proc(CreatedBeforeTable,
        LocalRTable, RptaInfoTable), PathContainsResurrectionTable,
        map.init, ResurrectionRenameTable).

:- pred collect_region_resurrection_renaming_proc(
    proc_pp_region_set_table::in, proc_region_set_table::in,
    rpta_info_table::in, pred_proc_id::in,
    map(execution_path, region_set)::in, renaming_table::in,
    renaming_table::out) is det.

collect_region_resurrection_renaming_proc(CreatedBeforeTable, _LocalRTable,
        RptaInfoTable, PPId, PathsContainResurrection,
        !ResurrectionRenameTable) :-
    map.lookup(CreatedBeforeTable, PPId, CreatedBeforeProc),
    map.lookup(RptaInfoTable, PPId, RptaInfo),
    RptaInfo = rpta_info(Graph, _),
    map.foldl(collect_region_resurrection_renaming_exec_path(Graph,
        CreatedBeforeProc),
        PathsContainResurrection, map.init, ResurrectionRenameProc),
    svmap.set(PPId, ResurrectionRenameProc, !ResurrectionRenameTable).

:- pred collect_region_resurrection_renaming_exec_path(rpt_graph::in,
    pp_region_set_table::in, execution_path::in,
    region_set::in, renaming_proc::in,
    renaming_proc::out) is det.

collect_region_resurrection_renaming_exec_path(Graph, CreatedBeforeProc,
        ExecPath, ResurrectedRegions, !ResurrectionRenameProc) :-
    list.foldl2(collect_region_resurrection_renaming_prog_point(Graph,
        CreatedBeforeProc, ResurrectedRegions), ExecPath, 1, _,
        !ResurrectionRenameProc).

:- pred collect_region_resurrection_renaming_prog_point(rpt_graph::in,
    pp_region_set_table::in, region_set::in,
    pair(program_point, hlds_goal)::in, int::in, int::out,
    renaming_proc::in, renaming_proc::out) is det.

collect_region_resurrection_renaming_prog_point(Graph, CreatedBeforeProc,
        ResurrectedRegions, ProgPoint - _, !RenamingCounter,
        !ResurrectionRenameProc) :-
    map.lookup(CreatedBeforeProc, ProgPoint, CreatedBeforeProgPoint),
    set.intersect(ResurrectedRegions, CreatedBeforeProgPoint, 
        ToBeRenamedRegions),
    % We only record the program points where resurrection renaming exists.
    ( if    set.empty(ToBeRenamedRegions)
      then
            true
      else
            set.fold(record_renaming_prog_point(Graph, ProgPoint,
                !.RenamingCounter), ToBeRenamedRegions,
                !ResurrectionRenameProc)
    ),
    !:RenamingCounter = !.RenamingCounter + 1.
 
:- pred record_renaming_prog_point(rpt_graph::in, program_point::in, int::in,
    rptg_node::in, renaming_proc::in,
    renaming_proc::out) is det.

record_renaming_prog_point(Graph, ProgPoint, RenamingCounter, Region,
        !ResurrectionRenameProc) :-
    RegionName = rptg_lookup_region_name(Graph, Region),
    Renamed = RegionName ++ "_Resur_"
        ++ string.int_to_string(RenamingCounter),

    ( if    map.search(!.ResurrectionRenameProc, ProgPoint,
                RenamingProgPoint0)
      then
            svmap.set(RegionName, Renamed,
                RenamingProgPoint0, RenamingProgPoint)
      else
            svmap.det_insert(RegionName, Renamed, map.init, RenamingProgPoint)
    ),
    svmap.set(ProgPoint, RenamingProgPoint, !ResurrectionRenameProc).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

    % Collect join points in procedures.
    % We need to find the join points in a procedure because we need to use
    % a specific region name for each renaming at a join point.
    %
    % A program point is a join point if it is in at least two execution
    % paths and its previous points in some two execution paths are different.
    %
    % We will only collect join points in procedures where resurrection
    % happens.
    %
    % We use ResurrectionRenameTable just for the PPIds of procedures in
    % which resurrection happens.
    %
    % The new region name at a join point is formed by RegionName_jp_Number.
    % If a region needs new names at several join points then Number will
    % make the new names distinct.
    %
collect_join_points(ResurrectionRenameTable, ExecPathTable, JoinPointTable) :-
    map.foldl(collect_join_points_proc(ExecPathTable),
        ResurrectionRenameTable, map.init, JoinPointTable).

:- pred collect_join_points_proc(execution_path_table::in,
    pred_proc_id::in, renaming_proc::in,
    join_point_region_name_table::in,
    join_point_region_name_table::out) is det.

collect_join_points_proc(ExecPathTable, PPId, _, !JoinPointTable) :-
    map.lookup(ExecPathTable, PPId, ExecPaths),
    list.foldr(pred(ExecPath::in, Ps0::in, Ps::out) is det :- (
                    assoc_list.keys(ExecPath, P),
                    Ps = [P | Ps0]
               ), ExecPaths, [], Paths), 
    list.foldl3(collect_join_points_path(Paths), Paths,
        1, _, set.init, _JoinPoints, map.init, JoinPointProc),
    svmap.set(PPId, JoinPointProc, !JoinPointTable).

:- pred collect_join_points_path(list(list(program_point))::in,
    list(program_point)::in, int::in, int::out, set(program_point)::in,
    set(program_point)::out, map(program_point, string)::in,
    map(program_point, string)::out) is det.

collect_join_points_path(Paths, Path, !Counter, !JoinPoints,
        !JoinPointProc) :-
    list.delete_all(Paths, Path, TheOtherPaths),
    % We ignore the first program point in each path because
    % it cannot be a join point.
    ( if    Path = [PrevPoint, ProgPoint | ProgPoints]
      then
            ( if    is_join_point(ProgPoint, PrevPoint, TheOtherPaths)
              then
                    svmap.set(ProgPoint,
                        "_jp_" ++ string.int_to_string(!.Counter),
                        !JoinPointProc),
                    svset.insert(ProgPoint, !JoinPoints),
                    !:Counter = !.Counter + 1
              else
                    true
            ),
            collect_join_points_path(Paths,
                [ProgPoint | ProgPoints], !Counter, !JoinPoints,
                !JoinPointProc)
      else
            true
    ).

    % This predicate succeeds if the first program point is a join point. 
    % That means it is at least in another execution path and is preceded
    % by some program point, which is different from the second one.
    %
:- pred is_join_point(program_point::in, program_point::in, 
    list(list(program_point))::in) is semidet.

is_join_point(ProgPoint, PrevProgPoint, [Path | Paths]) :-
    ( if    is_join_point_2(ProgPoint, PrevProgPoint, Path)
      then  
            true
      else
            is_join_point(ProgPoint, PrevProgPoint, Paths)
    ).
    
:- pred is_join_point_2(program_point::in, program_point::in, 
    list(program_point)::in) is semidet.

is_join_point_2(ProgPoint, PrevProgPoint, [P1, P2 | Ps]) :-
    ( if    P2 = ProgPoint
      then
            P1 \= PrevProgPoint
      else
            is_join_point_2(ProgPoint, PrevProgPoint, [P2 | Ps])
    ).

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

%-----------------------------------------------------------------------------%
%
% Collect renaming at each program point.
%
% A renaming at a program point will be applied to annotations attached
% to before and after it. If the associated (atomic) goal is procedure call
% then the renaming is also applied to its actual region arguments. If the
% goal is a construction the renaming is applied to the regions of the left
% variable.

    % This predicate collects *renaming* along the execution paths in
    % procedures where region resurrection happens. It also computes
    % the reversed renaming *annotations* to ensure the integrity use of
    % regions.
    %
collect_renaming_and_annotation(ResurrectionRenameTable, JoinPointTable,
        LRBeforeTable, BornRTable, RptaInfoTable, ResurrectionPathTable,
        ExecPathTable, AnnotationTable, RenamingTable) :-
    map.foldl2(collect_renaming_and_annotation_proc(ExecPathTable,
        JoinPointTable, LRBeforeTable, BornRTable, RptaInfoTable,
        ResurrectionPathTable), ResurrectionRenameTable,
        map.init, AnnotationTable, map.init, RenamingTable).

:- pred collect_renaming_and_annotation_proc(execution_path_table::in,
    join_point_region_name_table::in, proc_pp_region_set_table::in,
    proc_region_set_table::in, rpta_info_table::in,
    proc_resurrection_path_table::in, pred_proc_id::in,
    renaming_proc::in,
    renaming_annotation_table::in, renaming_annotation_table::out,
    renaming_table::in, renaming_table::out) is det.

collect_renaming_and_annotation_proc(ExecPathTable, JoinPointTable,
        LRBeforeTable, BornRTable, RptaInfoTable, ResurrectionPathTable,
        PPId, ResurrectionRenameProc, !AnnotationTable, !RenamingTable) :-
    map.lookup(JoinPointTable, PPId, JoinPointProc),
    map.lookup(LRBeforeTable, PPId, LRBeforeProc),
    map.lookup(BornRTable, PPId, BornR),
    map.lookup(RptaInfoTable, PPId, RptaInfo),
    RptaInfo = rpta_info(Graph, _),
    % Here we find all regions which resurrects in this procedure.
    % This information is used at a join point to introduce renamings
    % for all resurrecting regions that become live at the join point.
    map.lookup(ResurrectionPathTable, PPId, PathsContainResurrection),
    map.values(PathsContainResurrection, ResurrectedRegionsInPaths),
    list.foldl(pred(ResurRegions::in, R0::in, R::out) is det :- (
                    set.union(R0, ResurRegions, R)
               ), ResurrectedRegionsInPaths,
               set.init, ResurrectedRegionsProc),
    map.lookup(ExecPathTable, PPId, ExecPaths),
    list.foldl2(collect_renaming_and_annotation_exec_path(
        ResurrectionRenameProc, JoinPointProc, LRBeforeProc, BornR,
        Graph, ResurrectedRegionsProc), ExecPaths,
        map.init, AnnotationProc, map.init, RenamingProc),
    svmap.set(PPId, AnnotationProc, !AnnotationTable),
    svmap.set(PPId, RenamingProc, !RenamingTable).

    % The renaming along an execution path is built up. Let's see an 
    % example of renamings.
    % (1) R1 --> R1_1   // i.e., R1 resurrects and therefore needs renaming.
    % (2) R1 --> R1_1, R2 --> R2_1
    % (3) R1 --> R1_2, R2 --> R2_1 //R1 becomes live again, needs a new name.
    % ...
    %
:- pred collect_renaming_and_annotation_exec_path(renaming_proc::in,
    map(program_point, string)::in, pp_region_set_table::in,
    region_set::in, rpt_graph::in, region_set::in, execution_path::in,
    renaming_annotation_proc::in, renaming_annotation_proc::out,
    renaming_proc::in, renaming_proc::out) is det.

collect_renaming_and_annotation_exec_path(_, _, _, _, _, _, [],
        !AnnotationProc, !RenamingProc) :-
    unexpected(this_file, "collect_renaming_and_annotation_exec_path: "
        ++ "empty execution path encountered").

    % This is the first program point in an execution path.
    % It cannot be a join point. Renaming is needed at this point only
    % when it is a resurrection point.
    %
collect_renaming_and_annotation_exec_path(ResurrectionRenameProc,
        JoinPointProc, LRBeforeProc, BornR, Graph, ResurrectedRegions,
        [ProgPoint - _ | ProgPoint_Goals], !AnnotationProc, !RenamingProc) :-
    ( if    map.search(ResurrectionRenameProc, ProgPoint, ResurRename)
      then
            svmap.set(ProgPoint, ResurRename, !RenamingProc)
      else
            svmap.set(ProgPoint, map.init, !RenamingProc)
    ),
    collect_renaming_and_annotation_exec_path_2(ResurrectionRenameProc,
        JoinPointProc, LRBeforeProc, BornR, Graph, ResurrectedRegions,
        ProgPoint, ProgPoint_Goals, !AnnotationProc, !RenamingProc).

:- pred collect_renaming_and_annotation_exec_path_2(renaming_proc::in,
    map(program_point, string)::in, pp_region_set_table::in,
    region_set::in, rpt_graph::in, region_set::in, program_point::in,
    execution_path::in,
    renaming_annotation_proc::in, renaming_annotation_proc::out,
    renaming_proc::in, renaming_proc::out) is det.

    % This means the first program point is also the last.
    % We do not need to do anything more.
    %
collect_renaming_and_annotation_exec_path_2(_, _, _, _, _, _, _, [],
        !AnnotationProc, !RenamingProc).

    % This is a program point which is not the first.
    %
    % A program point can belong to different execution paths, therefore
    % it can be processed more than once. If a program point is a
    % *join point*, the process in later execution paths may add new
    % renaming information about some resurrected region(s) which does not
    % resurrect in the already-processed paths covering this program point.
    % To avoid updating information related to the already-processed paths
    % whenever we process a join point we include the information about ALL 
    % resurrected regions that are live before the join point. This will
    % ensure that no new renaming information arises when the program
    % point is processed again.
    %
    % At a join point, we need to add suitable annotations to the previous
    % point, i.e., ones related to the renaming at the previous point.
    %
    % At the last program point, we need to add annotations for any region
    % parameters which resurrect.
    %
collect_renaming_and_annotation_exec_path_2(ResurrectionRenameProc,
        JoinPointProc, LRBeforeProc, BornR, Graph, ResurrectedRegions, 
        PrevProgPoint, [ProgPoint - _ | ProgPoint_Goals],
        !AnnotationProc, !RenamingProc) :-
    map.lookup(!.RenamingProc, PrevProgPoint, PrevRenaming), 
    ( if    map.search(ResurrectionRenameProc, ProgPoint, ResurRenaming)
      then
            % This is a resurrection point of some region(s). We need to 
            % merge the existing renaming at the previous point with the 
            % resurrection renaming here. When two renamings have the same
            % key, i.e., the region resurrects, the resurrection renaming
            % takes priority.
            map.overlay(PrevRenaming, ResurRenaming, Renaming0),
            svmap.set(ProgPoint, Renaming0, !RenamingProc)
      else
            % This is not a resurrection point (of any regions).
            % Renaming at this point is the same as at its
            % previous point
            svmap.set(ProgPoint, PrevRenaming, !RenamingProc)
    ),
    ( if    map.search(JoinPointProc, ProgPoint, JoinPointName)
      then
            % This is a join point.
            % Add annotations to the previous point.
            map.lookup(LRBeforeProc, ProgPoint, LRBeforeProgPoint),
            set.intersect(ResurrectedRegions, LRBeforeProgPoint,
                ResurrectedAndLiveRegions),
            set.fold2(add_annotation_and_renaming(PrevProgPoint,
                Graph, JoinPointName, PrevRenaming),
                ResurrectedAndLiveRegions, !AnnotationProc,
                map.init, Renaming),
            % We will just overwrite any existing renaming
            % information at this point.
            svmap.set(ProgPoint, Renaming, !RenamingProc) 
      else
            true
    ),
    (
        % This is the last program point in this execution path.
        ProgPoint_Goals = [],
        % Add reversed renaming for regions in bornR.
        set.intersect(ResurrectedRegions, BornR, ResurrectedAndBornRegions),
        map.lookup(!.RenamingProc, ProgPoint, LastRenaming),
        set.fold(add_annotation(ProgPoint, Graph, LastRenaming),
            ResurrectedAndBornRegions, !AnnotationProc)
    ;
        ProgPoint_Goals = [_ | _],
        collect_renaming_and_annotation_exec_path_2(ResurrectionRenameProc,
            JoinPointProc, LRBeforeProc, BornR, Graph, ResurrectedRegions,
            ProgPoint, ProgPoint_Goals, !AnnotationProc, !RenamingProc)
    ).

    % This predicate adds renaming annotation after the previous program
    % point and records renaming from existing region name.
    %  
:- pred add_annotation_and_renaming(program_point::in,
    rpt_graph::in, string::in, renaming::in, rptg_node::in,
    renaming_annotation_proc::in, renaming_annotation_proc::out,
    renaming::in, renaming::out) is det.

add_annotation_and_renaming(PrevProgPoint, Graph, JoinPointName,
        PrevRenaming, Region, !AnnotationProc, !Renaming) :-
    RegionName = rptg_lookup_region_name(Graph, Region),
    NewName = RegionName ++ JoinPointName,

    % Add renaming. 
    svmap.det_insert(RegionName, NewName, !Renaming),

    % Add annotation to (after) the previous program point.
    % Annotations are only added for resurrected regions that have been
    % renamed in this execution path (i.e., the execution path contains
    % PrevProgPoint and ProgPoint).
    ( if    map.search(PrevRenaming, RegionName, CurrentName)
      then
            Annotation = NewName ++ " = " ++ CurrentName,
            record_annotation(PrevProgPoint, Annotation, !AnnotationProc)
      else
            true
    ).

:- pred add_annotation(program_point::in, rpt_graph::in, renaming::in,
    rptg_node::in, renaming_annotation_proc::in,
    renaming_annotation_proc::out) is det.

add_annotation(ProgPoint, Graph, Renaming, Region, !AnnotationProc) :-
    RegionName = rptg_lookup_region_name(Graph, Region),

    % Add annotation to (after) the program point.
    % Annotations are only added for resurrected regions that have been
    % renamed in this execution path.
    ( if    map.search(Renaming, RegionName, CurrentName)
      then
            Annotation = RegionName ++ " = " ++ CurrentName,
            record_annotation(ProgPoint, Annotation, !AnnotationProc)
      else
            true
    ).

record_annotation(ProgPoint, Annotation, !AnnotationProc) :-
    ( if    map.search(!.AnnotationProc, ProgPoint, Annotations0)
      then
            ( if    list.member(Annotation, Annotations0)
              then  Annotations = Annotations0
              else  Annotations = [Annotation | Annotations0]
            )
      else
            % No annotation exists at this program point yet.
            Annotations = [Annotation]
    ),
    svmap.set(ProgPoint, Annotations, !AnnotationProc).

%-----------------------------------------------------------------------------%

:- func this_file = string.

this_file = "rbmm.region_resurrection_renaming.m".

%-----------------------------------------------------------------------------%
