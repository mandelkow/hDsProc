#!/usr/local/bin/python3 -u
# #!/bin/env python3
# could use: #!/usr/local/bin/python3 -u
# Prevent BrokenPipeError by -u ? See: PYTHONUNBUFFERED in https://docs.python.org/3/using/cmdline.html

import sys, re, numpy as np, scipy as sc, scipy.signal as si

def hcalctxt( Prog, *iFiles ):
    """Calculate from text files (.csv) the result of an expression (string) using Numpy etc.
    Input files are assigned to the list X[n] = np.loadtxt( iFiles[n]).

    Use packages: import sys, re, numpy as np, scipy as sc, scipy.signal as si

    EXAMPLE: echo 1 2 3 4 5 > tmp.txt; hcalctxt.py 'X[0]+X[1]**2' '%d' tmp.txt tmp.txt

    hcalctxt.py 'X[0].reshape(-1,X[1].size,X[0].shape[1])[:,np.argsort(X[1])].flatten()' SliceRegressor.txt SliceTimes.txt > Regressor.txt

    NB: 1D output currently defaults to a single *column* (multiple rows / lines). Better cast 2D 
    to make desired output explicit e.g.: 'np.r_["r",...]' for single row / line.

    python3 -c 'import sys, numpy as np; (a,b)=[ np.loadtxt(n) for n in ("FileA.txt","FileB.txt")]; np.savetxt( sys.stdout, a+b**2, "%.1g") '
    """
    # AUTHOR: H.Mandelkow, 2020-10-05, v1a

    # NOTE: When using stdout, we mustn't print any non-essential output.
    Fmt = '%.3g'
    iFiles = list(iFiles)
    if len(iFiles) and iFiles[0].startswith('%'): Fmt = iFiles.pop(0)
    if len(iFiles) and iFiles[-1].startswith('%'): Fmt = iFiles.pop() # FIXIT: depreciated legacy
    # X = [ np.loadtxt(Fname) for Fname in iFiles ]
    X = [ np.c_[ np.loadtxt(Fname)] for Fname in iFiles ]

    if r'X[' not in Prog: Prog = re.sub(r'X([0-9]+)',r'X[\1]',Prog) # +++ conveniently replace X# with X[#]
    
    Y = eval( Prog )
    if True:
        Fmt,Dlm = re.match(r'(.*\w)([^%]*)',Fmt).groups()
        if not Dlm: Dlm = ' '
        # Pythetic r'\' should work but inconsistently does not.
        if Dlm[-1] == '\\' : (Dlm, Nln) = ( Dlm[:-1], ' ')
        else: Nln = '\n'
    else:
        Fmt,Dlm,Nln = re.match(r'(.*\w)([^%]*)\^?(.*)',Fmt).groups()
        if not Dlm: Dlm = ' '
        if not Nln: Nln = '\n'

    # np.savetxt( sys.stdout, np.r_['r',Y], Fmt, Dlm, Nln ) # default to 1 row / line
    # np.savetxt( sys.stdout, np.c_[Y], Fmt, Dlm, Nln ) # 1D defaults to column
    np.savetxt( sys.stdout, Y, Fmt, Dlm, Nln ) # 1D defaults to column
    # sys.stdout.flush() # Avoid BrokenPipeError?! Nope!

#======================================================================
hshift0 = lambda X,N: np.roll( np.append( X, 0*X[:N], 0), N, 0)[:X.shape[0]]
hshifts0 = lambda X,*N: np.concatenate([hshift0(np.c_[X],n) for n in N],1)
hshift = lambda X,N,D,V=0: np.roll( np.append( X, V+0*X.take(np.r_[:N],D,mode='clip'), D), N, D).take(np.r_[:X.shape[D]],D)
hcat = np.concatenate

def hnancent(XW):
    '''Center (demean) non-zero elements.
    '''
    # TODO: Rename to hnzdemean?
    # XW = np.where( XW==0, np.nan, XW)
    np.place( XW, XW==0, np.nan)
    XW -= np.nanmean(XW,0,keepdims=True)
    np.place( XW, np.isnan(XW), 0)
    return XW

def hnannorm(XW):
    np.place( XW, XW==0, np.nan)
    XW /= np.sqrt( np.nansum(XW**2,0,keepdims=True))
    np.place( XW, np.isnan(XW), 0)
    return XW

#======================================================================
def hzclip( Data, Zclip=4.0, dim=0, Val=None):
    assert dim==0, 'Oops! NOT TESTED for dim != 0.'
    Data = np.copy( Data )
    if Val is None: Val = Zclip

    #< print('+ Rescale...',end=' ')
    Data = hscalez(Data,dim)
    neg = Data < 0
    idx = np.abs(Data) > Zclip
    while np.any(idx):
        #< print('.',end=' ')
        Data[idx] = np.nan
        Data = hscalez(Data,dim) # +++ standardize!
        idx = np.abs(Data) > Zclip
    idx = np.isnan(Data)
    Data[idx] = Val
    # Data[idx] = 0.0 # option 1
    # Data[idx] = Zclip # option 2
    # Data[idx] = Zclip * 1.5 # option 3
    # Data[idx] = np.ceil(Zclip) + 1 # option 4
    Data[idx & neg] *= -1
    #< print('DONE.')
    return Data


#< def hzclip2( Data, dim=0, Zclip=4.0, Val=None):
def hzclip2( Data, dim=0, Zclip=4):
    '''Zclip via scipy.stats.sigmaclip()
    Zclip = 4   # (default) scale to 4 SD, clip outliers at +/-4
    Zclip=(4,5)   # scale to 4 SD, replace outliers by +/-5
    Zclip=(4,None)   # scale to 4 SD, but do not replace outliers
    '''
    # Tested (for 1D input) to yield approx the same as above ~1e-15.
    try: Zclip, Val = Zclip[0], Zclip[1]
    except: Val = Zclip
    Zclip = np.abs(Zclip) # just to be sure

    def hzclip1d( x, Zclip ): # not in place!
        x = np.copy(x)
        # NB: input low,high both positive!!!
        ( _, a, b) = sc.stats.sigmaclip( x, Zclip, Zclip) # *removes* data!
        x = (x - a) / (b-a) * 2*Zclip - Zclip # in place!?!
        if Val is not None:
            np.clip( x, -Zclip, Zclip, x) # in place!
            x[ x==Zclip ] = Val
            x[ x==-Zclip ] = -Val
        return x

    return np.apply_along_axis( hzclip1d, dim, Data, Zclip)

def hRespRvtDec( Resp, Dec=5 ):
    '''???
    '''
    Sig = np.copy(Resp)
    Sig = hzclip2( Sig, 0, [4,0]) # This is effectively done already.
    Sig = np.diff( Sig,1,0,prepend=0) # opt., could do to input!
    Sig = hzclip2( Sig, 0, [3,0])
    # Sig = np.abs(Sig) # ++++
    Sig *= Sig > 0
    Sig = si.decimate( Sig, Dec, axis=0) # The order abs-dec / dec-abs is virtually irrelevant

    return Sig

# def hresize(X,*varg):
#     X = np.copy(X)
#     X.resize(*varg)
#     return X

#======================================================================
if __name__ == "__main__":
    import warnings
    try: hcalctxt( *sys.argv[1:] )
    except BrokenPipeError: # now prevented by python3 -u
        warnings.warn('Oops, broken pipe! Who cares?!')
