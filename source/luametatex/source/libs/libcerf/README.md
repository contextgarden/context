# libcerf

This is the home page of **libcerf**, a self-contained numeric library that provides an efficient and accurate implementation of complex error functions, along with Dawson, Faddeeva, and Voigt functions.

# User Documentation

## Synopsis

In the following, "complex" stands for the C99 data type "double _Complex":

  * complex [cerf](http://apps.jcns.fz-juelich.de/man/cerf.html) (complex): The complex error function erf(z).
  * complex [cerfc](http://apps.jcns.fz-juelich.de/man/cerf.html) (complex): The complex complementary error function erfc(z) = 1 - erf(z).
  * complex [cerfcx](http://apps.jcns.fz-juelich.de/man/erfcx.html) (complex z): The underflow-compensating function erfcx(z) = exp(z^2) erfc(z).
  * double [erfcx](http://apps.jcns.fz-juelich.de/man/erfcx.html) (double x): The same for real x.
  * complex [cerfi](http://apps.jcns.fz-juelich.de/man/erfi.html) (complex z): The imaginary error function erfi(z) = -i erf(iz).
  * double [erfi](http://apps.jcns.fz-juelich.de/man/erfi.html) (double x): The same for real x.
  * complex [w_of_z](http://apps.jcns.fz-juelich.de/man/w_of_z.html) (complex z): Faddeeva's scaled complex error function w(z) = exp(-z^2) erfc(-iz).
  * double [im_w_of_x](http://apps.jcns.fz-juelich.de/man/w_of_z.html) (double x): The same for real x, returning the purely imaginary result as a real number.
  * complex [cdawson](http://apps.jcns.fz-juelich.de/man/dawson.html) (complex z): Dawson's integral D(z) = sqrt(pi)/2 * exp(-z^2) * erfi(z).
  * double [dawson](http://apps.jcns.fz-juelich.de/man/dawson.html) (double x): The same for real x.
  * double [voigt](http://apps.jcns.fz-juelich.de/man/voigt.html) (double x, double sigma, double gamma): The convolution of a Gaussian and a Lorentzian.
  * double [voigt_hwhm](http://apps.jcns.fz-juelich.de/man/voigt_hwhm.html) (double sigma, double gamma): The half width at half maximum of the Voigt profile.

## Accuracy

By construction, it is expected that the relative accuracy is generally better than 1E-13. This has been confirmed by comparison with high-precision Maple computations and with a *long double* computation using Fourier transform representation and double-exponential transform.

## Copyright and Citation

Copyright (C) [Steven G. Johnson](http:*math.mit.edu/~stevenj), Massachusetts Institute of Technology, 2012; [Joachim Wuttke](http:*www.fz-juelich.de/SharedDocs/Personen/JCNS/EN/Wuttke_J.html), Forschungszentrum Jülich, 2013.

License: [MIT License](http://opensource.org/licenses/MIT)

When using libcerf in scientific work, please cite as follows:
  * S. G. Johnson, A. Cervellino, J. Wuttke: libcerf, numeric library for complex error functions, version [...], http://apps.jcns.fz-juelich.de/libcerf

Please send bug reports to the authors, or submit them through the Gitlab issue tracker.

## Further references

Most function evaluations in this library rely on Faddeeva's function w(z).

This function has been reimplemented from scratch by [Steven G. Johnson](http://math.mit.edu/~stevenj);
project web site http://ab-initio.mit.edu/Faddeeva. The implementation partly relies on algorithms from the following publications:
  * Walter Gautschi, *Efficient computation of the complex error function,* SIAM J. Numer. Anal. 7, 187 (1970).
  * G. P. M. Poppe and C. M. J. Wijers, *More efficient computation of the complex error function,* ACM Trans. Math. Soft. 16, 38 (1990).
  * Mofreh R. Zaghloul and Ahmed N. Ali, *Algorithm 916: Computing the Faddeyeva and Voigt Functions,* ACM Trans. Math. Soft. 38, 15 (2011).

# Installation

## From source

Download location: http://apps.jcns.fz-juelich.de/src/libcerf/

Build&install are based on CMake. Out-of-source build is enforced.
After unpacking the source, go to the source directory and do:

  mkdir build
  cd build
  cmake ..
  make
  make install

To test, run the programs in directory test/.

The library has been developed using gcc-4.7. Reports about successful compilation with older versions of gcc would be welcome. For correct support of complex numbers it seems that at least gcc-4.3 is required. Compilation with gcc-4.2 works after removing of the "-Werror" flag from *configure*.

## Binary packages

  * Linux:
    * [rpm package](https://build.opensuse.org/package/show/science/libcerf) by Christoph Junghans
    * [Gentoo package](http://packages.gentoo.org/package/sci-libs/libcerf) by Christoph Junghans
    * [Debian package](https://packages.debian.org/jessie/libs/libcerf1) by Eugen Wintersberger
  * OS X:
    * [MacPorts::libcerf](http://www.macports.org/ports.php?by=name&substr=libcerf), by Mojca Miklavec
    * [Homebrew/homebrew-science/libcerf.rb](https://formulae.brew.sh/formula/libcerf), by Roman Garnett

# Code structure

The code consists of
- the library's C source (directory lib/),
- test code (directory test/),
- manual pages (directory man/),
- build utilities (aclocal.m4, build-aux/, config*, m4/, Makefile*).

## Compilation

The library libcerf is written in C. It can be compiled as C code (default) or as C++ code (with option -DCERF_CPP=ON). Compilation as C++ is useful especially under MS Windows because as per 2018 the C compiler of Visual Studio does not support C90, nor any newer language standard, and is unable to cope with complex numbers.

Otherwise, the library is self-contained, and installation should be
straightforward, using the usual command sequence

  ./configure
  make
  sudo make install

The command ./configure takes various options that are explained in the
file INSTALL.

## Language bindings

For use with other programming languages, libcerf should be either linked directly, or provided with a trivial wrapper. Such language bindings are added to the libcerf package as contributed by their authors.

The following bindings are available:
  * **fortran**, by Antonio Cervellino (Paul Scherrer Institut)

Further contributions will be highly welcome.

Please report bugs to the package maintainer.
