#ifndef	ENGINE_H
#define	ENGINE_H

#define	PROGFLAG	0
#define	GOTOFLAG	1
#define	CALLFLAG	2
#define	HEAPFLAG	3
#define	DETSTACKFLAG	4
#define	NONDSTACKFLAG	5
#define	FINALFLAG	6
#define	MEMFLAG		7
#define	SREGFLAG	8
#define	DETAILFLAG	9
#define	MAXFLAG		10
/* DETAILFLAG should be the last real flag */

#define	progdebug	debugflag[PROGFLAG]
#define	gotodebug	debugflag[GOTOFLAG]
#define	calldebug	debugflag[CALLFLAG]
#define	heapdebug	debugflag[HEAPFLAG]
#define	detstackdebug	debugflag[DETSTACKFLAG]
#define	nondstackdebug	debugflag[NONDSTACKFLAG]
#define	finaldebug	debugflag[FINALFLAG]
#define	memdebug	debugflag[MEMFLAG]
#define	sregdebug	debugflag[SREGFLAG]
#define	detaildebug	debugflag[DETAILFLAG]

extern	bool	debugflag[];

extern	void	init_engine(void);
extern	void	call_engine(Code *entry_point);

Declare_entry(do_redo);
Declare_entry(do_fail);
Declare_entry(do_reset_hp_fail);
Declare_entry(do_reset_framevar0_fail);
Declare_entry(do_succeed);
Declare_entry(do_not_reached);

#endif
