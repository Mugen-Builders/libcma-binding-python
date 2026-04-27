from setuptools import setup, Extension
import os

setup(
    name='pycma',
    version=os.getenv("VERSION", '0.0.0'),
    py_modules=['pycma'],
    ext_modules = [
        Extension("pycma",
            sources=["pycma.pyx"],
            extra_objects=['/usr/lib/libcmt.a','/usr/lib/libcma.a'],
            extra_compile_args=["-fpic","-fstack-protector-strong"],
            library_dirs=["/usr/local/lib/","/usr/lib"],
            libraries=["stdc++","cmt","cma"],
            # language="c++",
        )
    ],
    setup_requires=[
        'setuptools>=75.0.0',
        'cython>=3.2.2',
        'pycmt>=0.0.1',
    ],
)
