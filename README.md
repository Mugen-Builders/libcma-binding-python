<br>
<p align="center">
    <img src="https://github.com/user-attachments/assets/080bb0be-060c-4813-85b4-6d9bf25af01f" align="center" width="20%">
</p>
<br>
<div align="center">
	<i>Cartesi Rollups LIBCMA Binding for PYTHON</i>
</div>
<div align="center">
	<!-- <b>Any Code. Ethereum’s Security.</b> -->
</div>
<br>
<p align="center">
	<img src="https://img.shields.io/github/license/Mugen-Builders/libcma-binding-python?style=default&logo=opensourceinitiative&logoColor=white&color=008DA5" alt="license">
	<img src="https://img.shields.io/github/last-commit/Mugen-Builders/libcma-binding-python?style=default&logo=git&logoColor=white&color=000000" alt="last-commit">
</p>

## Overview

This repository contains the Python bindings for the [Cartesi machine guest library (libcma)](https://github.com/Mugen-Builders/machine-asset-tools). The bindings expose libcma’s C API (parser, and ledger) for utilization in python applications as an object. The library is written in cython and it should be compiled for the system. This would serve as an alternative to the HttpServer and offer methods to manage a Cartesi application instance.

The repo includes:

- **Library**: `pycma` — the main cython library definition.
- **Sample apps**: `wallet_app`
- **Tests**: `/tests` Utilizes cartesapp to test the sample application which uses the libcma-python-bindings.

## Requirements

- **Docker** — for building the RISC-V image and running the Cartesi machine.
- **Python 3.12+** — for the test suite (cartesapp).

## Usage

### Add the binding to your Cartesi project

You can use `pip` to install:

```shell
pip3 install pycma --find-links https://prototyp3-dev.github.io/pip-wheels-riscv/wheels/
```

Note: the wheels are already compiled at https://prototyp3-dev.github.io/pip-wheels-riscv/wheels/. Alternatively you can install directly from the repo:

```shell
pip3 install pycma@git+https://github.com/Mugen-Builders/libcma-binding-python
```
