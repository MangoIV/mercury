//
// Copyright (C) 2001-2003 The University of Melbourne.
// Copyright (C) 2018 The Mercury team.
// This file is distributed under the terms specified in COPYING.LIB.
//

package jmercury.runtime;

public class DuPtagLayout implements java.io.Serializable {
	
	public int sectag_sharers;
	public Sectag_Locn sectag_locn;
	public /* final */ DuFunctorDesc[] sectag_alternatives;

	public DuPtagLayout(int sharers, Sectag_Locn locn, DuFunctorDesc[] alts)
	{
		sectag_sharers = sharers;
		sectag_locn = locn;
		sectag_alternatives = alts;
	}

	public DuPtagLayout(int sharers, int locn, DuFunctorDesc[] alts) {
		sectag_sharers = sharers;
		sectag_locn = new Sectag_Locn(locn);
		sectag_alternatives = alts;
	}
}
