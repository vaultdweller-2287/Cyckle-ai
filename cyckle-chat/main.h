/* Generated by Cython 3.0.12 */

#ifndef __PYX_HAVE__main
#define __PYX_HAVE__main

#include "Python.h"

#ifndef __PYX_HAVE_API__main

#ifdef CYTHON_EXTERN_C
    #undef __PYX_EXTERN_C
    #define __PYX_EXTERN_C CYTHON_EXTERN_C
#elif defined(__PYX_EXTERN_C)
    #ifdef _MSC_VER
    #pragma message ("Please do not define the '__PYX_EXTERN_C' macro externally. Use 'CYTHON_EXTERN_C' instead.")
    #else
    #warning Please do not define the '__PYX_EXTERN_C' macro externally. Use 'CYTHON_EXTERN_C' instead.
    #endif
#else
  #ifdef __cplusplus
    #define __PYX_EXTERN_C extern "C"
  #else
    #define __PYX_EXTERN_C extern
  #endif
#endif

#ifndef DL_IMPORT
  #define DL_IMPORT(_T) _T
#endif

__PYX_EXTERN_C PyObject *modeldict;

#endif /* !__PYX_HAVE_API__main */

/* WARNING: the interface of the module init function changed in CPython 3.5. */
/* It now returns a PyModuleDef instance instead of a PyModule instance. */

#if PY_MAJOR_VERSION < 3
PyMODINIT_FUNC initmain(void);
#else
/* WARNING: Use PyImport_AppendInittab("main", PyInit_main) instead of calling PyInit_main directly from Python 3.5 */
PyMODINIT_FUNC PyInit_main(void);

#if PY_VERSION_HEX >= 0x03050000 && (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER) || (defined(__cplusplus) && __cplusplus >= 201402L))
#if defined(__cplusplus) && __cplusplus >= 201402L
[[deprecated("Use PyImport_AppendInittab(\"main\", PyInit_main) instead of calling PyInit_main directly.")]] inline
#elif defined(__GNUC__) || defined(__clang__)
__attribute__ ((__deprecated__("Use PyImport_AppendInittab(\"main\", PyInit_main) instead of calling PyInit_main directly."), __unused__)) __inline__
#elif defined(_MSC_VER)
__declspec(deprecated("Use PyImport_AppendInittab(\"main\", PyInit_main) instead of calling PyInit_main directly.")) __inline
#endif
static PyObject* __PYX_WARN_IF_PyInit_main_INIT_CALLED(PyObject* res) {
  return res;
}
#define PyInit_main() __PYX_WARN_IF_PyInit_main_INIT_CALLED(PyInit_main())
#endif
#endif

#endif /* !__PYX_HAVE__main */
