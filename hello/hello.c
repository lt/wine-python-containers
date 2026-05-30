#define PY_SSIZE_T_CLEAN
#ifdef _WIN64
#ifndef MS_WIN64
#define MS_WIN64
#endif
#endif
#include <Python.h>

static PyObject*
hello_load(PyObject* self, PyObject* args)
{
    PyObject* dict = PyDict_New();
    if (!dict) {
        return NULL;
    }

    PyObject* name = PyUnicode_FromString("hello_module");
    PyObject* version = PyUnicode_FromString("1.0.0");

    if (!name || !version) {
        Py_XDECREF(name);
        Py_XDECREF(version);
        Py_DECREF(dict);
        return NULL;
    }

    if (PyDict_SetItemString(dict, "name", name) < 0 ||
        PyDict_SetItemString(dict, "version", version) < 0) {
        Py_DECREF(name);
        Py_DECREF(version);
        Py_DECREF(dict);
        return NULL;
    }

    Py_DECREF(name);
    Py_DECREF(version);

    return dict;
}

static PyMethodDef HelloMethods[] = {
    {"load", hello_load, METH_VARARGS, "Hello there."},
    {NULL, NULL, 0, NULL}
};

#if PY_MAJOR_VERSION >= 3
    static struct PyModuleDef hellomodule = {
        PyModuleDef_HEAD_INIT,
        "hello",   /* Name */
        NULL,      /* Documentation */
        -1,        /* Size of per-interpreter state */
        HelloMethods
    };

    PyMODINIT_FUNC
    PyInit_hello(void)
    {
        return PyModule_Create(&hellomodule);
    }
#else
    PyMODINIT_FUNC
    inithello(void)
    {
        (void) Py_InitModule("hello", HelloMethods);
    }
#endif
