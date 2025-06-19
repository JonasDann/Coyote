<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="img/cyt_logo_dark.png" width = 450>
    <source media="(prefers-color-scheme: light)" srcset="img/cyt_logo_light.png" width = 450>
    <img src="img/cyt_logo_light.png" width = 600>
  </picture>
</p>

[![Documentation Status](https://github.com/fpgasystems/Coyote/actions/workflows/build_docs.yaml/badge.svg?branch=master)](https://fpgasystems.github.io/Coyote/)
[![Build benchmarks](https://github.com/fpgasystems/Coyote/actions/workflows/build_static.yaml/badge.svg?branch=master)](https://github.com/fpgasystems/Coyote/actions/workflows/build_static.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

# _An operating system for FPGAs_
Coyote is an open-source shell which aims to facilitate the deployment of FPGAs in datacenters and cloud systems. One could think of Coyote as an OS for FPGAs, taking care of standard system abstractions for multi-tenancy, multi-threading, reconfiguration, networking (RDMA, TCP/IP), virtualized memory (DRAM, HBM) and PCIe interaction with other hardware (CPU, GPU). Generally speaking, Coyote aims to simplify the application deployment process and enable developers to solely focus on their application and its performance, rather than infrastructure development. By providing clear and simple-to-use interfaces in both hardware and software, Coyote allows everyone to leverage the mentioned abstractions for customized acceleration offloads and build distributed and heterogeneous computer systems, consisting of many FPGAs, GPUs and CPUs. Some examples of such systems would be [distributed recommender systems](https://www.usenix.org/conference/osdi24/presentation/he), [AI SmartNICs](https://arxiv.org/pdf/2501.12032) or [heterogeneous database engines](https://www.research-collection.ethz.ch/bitstream/handle/20.500.11850/586069/3/p11-korolija.pdf).

## Motivation
The inspiration for Coyote comes from the drastic changes in the hardware landscape of datacenter and cloud computing. With the inevitable end of Moore’s Law and Dennard Scaling, new generations of hardware do not promise the same performance improvements as before. Instead, computer systems are moving towards domain-specific accelerators that offer customized computing architectures for highly specialized tasks. FPGAs, in particular, were key in this development, both as prototyping platforms for sophisticated ASIC-based accelerators and as highly versatile and reconfigurable accelerators for direct deployment. 

However, FPGA tooling and infrastructure is not up to the standard of modern software development, leading many projects to “reinvent the wheel” when it comes to basic system abstractions and infrastructure. Coyote aims directly at these well-known weaknesses of the ecosystem, providing a comprehensive, open-source and community-driven approach to abstractions on FPGAs. When using Coyote, developers can fully concentrate on the implementation of their applications, leveraging the infrastructure abstractions provided by the shell. At the same time, all these abstractions are open-source and can be optimized if deemed necessary, offering insights in future computer systems.

## Features
Some of Coyote's features include:
 * Support for both RTL and HLS user applications
 * Easy-to-use software API in C++
 * Multiple isolated, virtualized user applications (vFPGAs)
 * Shared virtual memory between the FPGA, host CPU and other accelerators (e.g. GPUs)
 * Networking services: 100G RoCE-v2 compatible RDMA, TCP/IP and collectives
 * Automatic instantiation of card memory controllers (HBM/DDR) and memory striping
 * Dynamic run-time reconfiguration of user applications and services

<p align="center"
 <picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/cyt_ov_dark.png" width = 620>
  <source media="(prefers-color-scheme: light)" srcset="img/cyt_ov_light.png" width = 620>
  <img src="img/cyt_ov_light.png" width = 620>
</picture>
</p>

# Documentation & Examples

The recommended way to get started with Coyote is by going through the various [examples and tutorials](https://github.com/fpgasystems/Coyote/tree/master/examples), which cover hardware design, the software API, data movement, reconfiguration, networking etc. 

For video recordings covering **Coyote's** features, walk-through tutorials and live demos, check out our [tutorial at ASPLOS 2025](https://systems.ethz.ch/research/data-processing-on-modern-hardware/hacc/asplos25-tutorial-fpgas.html).

Additional details on **Coyote's** features and internals can be found in the [documentation](https://fpgasystems.github.io/Coyote/).

# Getting started
## Prerequisites

Full `Vivado/Vitis` suite is needed to build the hardware side of things. Hardware server will be enough for deployment only scenarios. Coyote runs with `Vivado 2022.1`. Previous versions can be used at one's own peril.  

We are currently only actively supporting the AMD `Alveo u55c` accelerator card. Our codebase offers some legacy-support for the following platforms: `vcu118`, `Alveo u50`, `Alveo u200`, `Alveo u250` and `Alveo u280`, but we are not actively working with these cards anymore. Coyote is currently being developed on the HACC cluster at ETH Zurich. For more information and possible external access check out the following link: https://systems.ethz.ch/research/data-processing-on-modern-hardware/hacc.html


`CMake` is used for project creation. Additionally `Jinja2` template engine for Python is used for some of the code generation. The API is writen in `C++`, 17 should suffice (for now).

If networking services are used, to generate the design you will need a valid [UltraScale+ Integrated 100G Ethernet Subsystem](https://www.xilinx.com/products/intellectual-property/cmac_usplus.html) license set up in `Vivado`/`Vitis`.

To run the virtual machines on top of individual *vFPGAs* the following packages are needed: `qemu-kvm`, `build-essential` and `kmod`.

## Quick Start

Initialize the repo and all submodules:

~~~~
$ git clone --recurse-submodules https://github.com/fpgasystems/Coyote
~~~~

### Build `HW`

To build an example hardware project (generate a *shell* image):

~~~~
$ mkdir build_hw && cd build_hw
$ cmake <path_to_cmake_config> -DFDEV_NAME=<target_device>  -DEXAMPLE=<target_example>
~~~~

It's a good practice to generate the hardware-build in a subfolder of the `examples_hw`, since this already contains the cmake that needs to be referenced. In this case, the procedure would look like this: 

~~~~
$ mkdir examples_hw/build_hw && cd examples_hw/build_hw 
$ cmake ../ -DFDEV_NAME=<target_device>  -DEXAMPLE=<target_example>
~~~~

Already implemented target-examples are specified in `examples_hw/CMakeLists.txt` and allow to build a variety of interesting design constellations, i.e. `rdma_perf` will create a RDMA-capable Coyote-NIC. 

Generate all projects and compile all bitstreams:

~~~~
$ make project 
$ make bitgen
~~~~

Since at least the initial building process takes quite some time and will normally be executed on a remote server, it makes sense to use the `nohup`-command in Linux to avoid termination of the building process if the connection to the server might be lost at some point. In this case, the build would be triggered with: 

~~~~
$ nohup make bitgen &> bitgen.log &
~~~~

With this, the building process will run in the background, and the terminal output will be streamed to the `bitgen.log` file. Therefore, the command 

~~~~
$ tail -f bitgen.log
~~~~

allows to check the current progress of the build-process. 

The bitstreams will be generated under `bitstreams` directory. 
This initial bitstream can be loaded via JTAG.
Further custom shell bitstreams can all be loaded dynamically. 

Netlist with the *official* static layer image is already provided under `hw/checkpoints`. We suggest you build your shells on top of this image.
This default image is built with `-DEXAMPLE=static`.

Additionally, a simulation project that utilizes the Coyote simulation environment may be built with:

~~~
$ make sim
~~~

### Build `SW`

Provided software applications (as well as any other) can be built with the following commands:

~~~~
$ mkdir build_sw && cd build_sw
$ cmake <path_to_cmake_config>
$ make
~~~~

Similar to building the HW, it makes sense to build within the `examples_sw` directory for direct access to the provided `CMakeLists.txt`: 

~~~~
$ mkdir examples_sw/build_sw && cd examples_sw/build_sw 
$ cmake ../ -DEXAMPLE=<target_example> -DVERBOSITY=<ON or OFF>
$ make
~~~~

The software-stack can be built in verbosity-mode, which will generate extensive printouts during execution. This is controlled via the `VERBOSITY` toggle in the cmake-call. Per default, verbosity is turned off.  

There is also a simulation target that the software may be built against by adding `-DSIM_DIR=<path_to_sim_build_dir>` to the cmake-call. The path to the simulation directory has to point to a hardware build directory where `make sim` has been executed to prepare the simulation project. An extensive documentation can be found in the `sim` directory.

### Build `Driver`

After the bitstream is loaded, the driver can be inserted once for the initial static image.

~~~~
$ cd driver && make
$ insmod coyote_drv.ko <any_additional_args>
~~~~

### Provided examples
Coyote already comes with a number of pre-configured example applications that can be used to test the shell-capabilities and systems performance or start own developments around networking or memory offloading. 
These existing example apps are currently available (documentation can be found in the respective ./examples_sw/\<example> directories): kmeans, multithreading, perf_fpga, perf_local, rdma_service, reconfigure_shell, streaming_service, tcp_iperf.
There is always a pair of directories in ./examples_hw and ./examples_sw that belong together.
The hardware side contains vFPGA code which the software side interacts with through the Coyote-provided functions.

## Download
Clone the repo and all its submodules:
```bash
git clone --recurse-submodules https://github.com/fpgasystems/Coyote
```

## Getting-started examples
The various Coyote examples can be found [here](https://github.com/fpgasystems/Coyote/tree/master/examples), which cover hardware design, the software API, data movement, reconfiguration, networking etc. 

# FAQ & Discussions

List of frequently asked questions and answers to common issues can be found on the [FAQ page](https://fastmachinelearning.org/hls4ml/intro/faq.html).

If you have any questions, comments, or ideas regarding Coyote or just want to show us how you use Coyote, don't hesitate to reach us through the [discussions tab](https://github.com/fpgasystems/Coyote/discussions).

# Citation

If you use Coyote, please cite us:

```bibtex
@inproceedings{coyote,
    author = {Dario Korolija and Timothy Roscoe and Gustavo Alonso},
    title = {Do {OS} abstractions make sense on FPGAs?},
    booktitle = {14th {USENIX} Symposium on Operating Systems Design and Implementation ({OSDI} 20)},
    year = {2020},
    pages = {991--1010},
    url = {https://www.usenix.org/conference/osdi20/presentation/roscoe},
    publisher = {{USENIX} Association}
}
```

# License

Copyright (c) 2023 FPGA @ Systems Group, ETH Zurich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
