#!/bin/env python3

import sys, numpy as np
# from hdf5storage import loadmat

def hcalctxt( Prog, iFiles, oFiles ):
    """hcalctxt [2a1] Numpy computations on text (csv) files. Exec multiple expressioins.

    EXAMPLE: hcalctxt 'Y = [ X[0]+X[1]**2 ]; Fmt="%03d"' 'tmpA.txt tmpB.txt' out.txt

    SEE: hcalctxt (eval single expression) 
    """
    # PREC: hcalctxt2b.py
    # AUTHOR: Hendrik.Mandelkow@gmail.com, 2020-11
    # AUTH: HM, 2020-11, v2b: "exec" multiple statements. Allow for multiple in and out files.
    # AUTH: HM, 2020-11, v2a1: Clean version removing redundancies.

    global X, Y, Fmt, Dlm, Nln
    Fmt, Dlm, Nln = '%.3g', ' ', '\n'

    iFiles = iFiles.split()
    oFiles = oFiles.split()
    X = [ ( np.loadtxt(Fname), print('+ Load '+Fname))[0] for Fname in iFiles ]
    # TODO:
    try: Y = [ eval( Prog ) ]
    except SyntaxError:
        Y = []
        # HOWTO use exec to manipulate global and local variables:
        exec( Prog, globals() ) # +++
        # exec( Prog, globals(), locals() ) # This also works without "globals Y" above, however...
        # Y must not be re-created but "mutated", in order to pass back.

    assert isinstance(Y,(list,tuple)) and len(Y)>0, "Oops! Program must define an output list Y=[ results... ]."
    try:
        [ np.savetxt( oFiles[n], Y[n], Fmt, Dlm, Nln ) for n in range(len(Y)) ]
    except:
        print('+++ ERROR: Prog must define a *list* Y of length oFiles!')
        raise # Re-raise last error?!

def hloadmatxt(*iFiles):
    X = []
    for Fname in iFiles:
        print(f'+ Load {Fname}')
        try:
            X.append( np.loadtxt(Fname))
        except:
            from hdf5storage import loadmat
            Fname = Fname.split(':')
            X = X + list( loadmat(Fname[0],None,Fname[1:]).values() )
    return X

if __name__ == "__main__":
    hcalctxt( *sys.argv[1:] )
