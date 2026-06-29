# musrfit Installer for Ubuntu 24.04

<p align="center">
  <strong>Fast musrfit setup for Ubuntu 24.04 / WSL2</strong><br>
  Two reproducible installers for musrfit 1.11.1 and 1.9.5 
</p>

<p align="center">
  <code>installer_v1.11.1.sh</code>
  &nbsp;|&nbsp;
  <code>installer_v1.9.5.sh</code> <strong></strong>
</p>

This repository provides two Bash installers for setting up ROOT and musrfit on Ubuntu 24.04:

- `installer_v1.11.1.sh`
- `installer_v1.9.5.sh` (recommended) 

Each `.sh` installs the required build dependencies, downloads the matching precompiled CERN ROOT package, clones the official musrfit source code, checks out a fixed commit for reproducible builds, builds musrfit, installs it into the ROOT directory, and adds the required environment variables to `~/.bashrc`.

In a typical WSL2 Ubuntu 24.04 environment, installation can finish within about five minutes, depending mainly on network speed.

## Contents

- [Supported System](#supported-system)
- [Quick Start](#quick-start)
- [Version Comparison](#version-comparison)
- [Why Two Versions Are Provided](#why-two-versions-are-provided)
- [What the Installers Do](#what-the-installers-do)
- [Default Installation Paths](#default-installation-paths)
- [Build Differences &amp; Optional Overrides](#build-differences--optional-overrides)
- [Sudo Usage and Environment Files](#sudo-usage-and-environment-files)
- [Author](#author)

## Supported System

- Ubuntu 24.04 is the tested and stable target system for these installers.
- WSL2 is recommended for musrfit users on Windows.

Other Ubuntu/Linux versions have not been tested. If another Linux version is detected, the installer will ask whether to continue, but stable operation is not guaranteed.

## Quick Start

Open Ubuntu and clone this repository:

```bash
cd ~
git clone https://github.com/Ericendil/Fast-Installation-for-Musrfit
cd Fast-Installation-for-Musrfit
```

Please run one installer as a normal user, not with `sudo`.

For musrfit 1.11.1:

```bash
chmod +x installer_v1.11.1.sh
./installer_v1.11.1.sh
```

For musrfit 1.9.5 (recommended):

```bash
chmod +x installer_v1.9.5.sh
./installer_v1.9.5.sh
```

After the success message, open a new shell or manually source `.bashrc`:

```bash
source ~/.bashrc
```

This step is required because a `.sh` script runs in a child shell. Environment changes made inside the installer cannot directly update the parent shell you are currently using.

Then you can open musrfit by running:

```bash
musredit
```


## Version Comparison

| Item | `installer_v1.11.1.sh` | `installer_v1.9.5.sh` (recommended) |
| --- | --- | --- |
| musrfit version | 1.11.1 | 1.9.5 |
| musrfit git revision | `6ed33d65` | `ebefcf7a` |
| musrfit release date | 2026-06-07 11:30:41 | 2024-06-24 09:44:07 |
| ROOT version | 6.40.02 | 6.32.02 |
| ROOT package | `root_v6.40.02.Linux-ubuntu24.04-x86_64-gcc13.3.tar.gz` | `root_v6.32.02.Linux-ubuntu24.04-x86_64-gcc13.2.tar.gz` |
| default `MUSRFIT_REF` | `6ed33d65` | `ebefcf7af9fed9524be78afcf39d81d97577b48b` |
| HDF4 dependency | Uses `libhdf4-dev`, falls back to `libhdf4-alt-dev` if needed | Uses `libhdf4-dev` |
| NeXus CMake paths | Uses default CMake/package discovery | Explicitly sets `/usr/include/nexus` and `/usr/lib/x86_64-linux-gnu/libNeXus.so` |

The two installers share the same general installation flow. The differences above are intentional due to different ROOT package and build requirements.

## Why Two Versions Are Provided

I developed and kept both installers because musrfit 1.11.1 is somehow much slower than musrfit 1.9.5 in my repeated fitting tests.

The test case was a slightly complex but identical `.msr` file: a fit using equation `statGssKTLF + simplExpo + constant_bg` on six LF datasets. I repeated the same fitting task several times under different Ubuntu and musrfit environments. The first round of tests showed that the newer musrfit version was consistently slower, especially in `MINOS`.

<div align="center">

<table>
  <thead>
    <tr>
      <th align="center">ID</th>
      <th align="center">Environment / description</th>
      <th align="center">Ubuntu version</th>
      <th align="center">musrfit version</th>
      <th align="center">Minimize time (s)</th>
      <th align="center">MINOS time (s)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center">1</td>
      <td align="center">Main work environment</td>
      <td align="center">Ubuntu 24.04 LTS</td>
      <td align="center">1.11.1</td>
      <td align="center">50.682</td>
      <td align="center">465.498</td>
    </tr>
    <tr>
      <td align="center">2</td>
      <td align="center">Previous main work environment</td>
      <td align="center">Ubuntu 22.04 LTS</td>
      <td align="center">1.9.5</td>
      <td align="center">1.624</td>
      <td align="center">23.666</td>
    </tr>
    <tr>
      <td align="center">3</td>
      <td align="center">Fresh test environment</td>
      <td align="center">Ubuntu 24.04 LTS</td>
      <td align="center">1.9.5</td>
      <td align="center">8.155</td>
      <td align="center">17.001</td>
    </tr>
    <tr>
      <td align="center">4</td>
      <td align="center">Fresh test environment</td>
      <td align="center">Ubuntu 24.04 LTS</td>
      <td align="center">1.11.1</td>
      <td align="center">66.626</td>
      <td align="center">40.091</td>
    </tr>
    <tr>
      <td align="center">5</td>
      <td align="center">Fresh test environment</td>
      <td align="center">Ubuntu 24.04 LTS</td>
      <td align="center">1.11.1</td>
      <td align="center">44.180</td>
      <td align="center">697.446</td>
    </tr>
  </tbody>
</table>

</div>

The results above show that the problem is not likely caused by the Ubuntu version or other environment differences. The problem is most likely related to the ROOT / musrfit versions.

After script development and optimization, I created a fresh WSL environment, ran the installers, and performed the same fit again. The results were:

<div align="center">

<table>
  <thead>
    <tr>
      <th align="center">ID</th>
      <th align="center">Environment / description</th>
      <th align="center">Ubuntu version</th>
      <th align="center">musrfit version</th>
      <th align="center">Minimize time (s)</th>
      <th align="center">MINOS time (s)</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center">6</td>
      <td align="center">Latest test: 1.9.5 installer</td>
      <td align="center">Ubuntu 24.04 LTS</td>
      <td align="center">1.9.5</td>
      <td align="center">6.555</td>
      <td align="center">19.038</td>
    </tr>
    <tr>
      <td align="center">7</td>
      <td align="center">Latest test: 1.11.1 installer</td>
      <td align="center">Ubuntu 24.04 LTS</td>
      <td align="center">1.11.1</td>
      <td align="center">62.960</td>
      <td align="center">472.380</td>
    </tr>
  </tbody>
</table>

</div>

The latest tests support the same conclusion: the 1.9.5 installer is kept as a practical fast baseline, while the 1.11.1 installer is kept for users who need the newer musrfit/ROOT combination.

## What the Installers Do

Both installers:

- Check that the script is not run as root.
- Check whether the system is Ubuntu 24.04.
- Enable the Ubuntu `universe` repository.
- Install build dependencies.
- Download the matching CERN ROOT binary package.
- Configure the dynamic linker for ROOT.
- Clone or update the official musrfit repository.
- Check out the configured musrfit commit.
- Remove the old musrfit `build` directory and create a clean one.
- Build musrfit with CMake in `Release` mode.
- Install musrfit into the ROOT installation prefix.
- Add ROOT and musrfit environment variables to `~/.bashrc`.
- Print ROOT and musrfit version information after installation.

## Default Installation Paths

The installer script itself can be placed and run from any directory. The installation destination is controlled by `INSTALL_HOME`, not by the script location.

Both installers use the same default paths:

```bash
~/apps/root
~/apps/musrfit
```

Because the default ROOT path is shared, do not install both versions into the same `INSTALL_HOME` unless you first move away the existing `~/apps/root`. Each installer checks the existing ROOT version before reusing it. If the existing ROOT version does not match the installer, the script stops instead of silently using the wrong ROOT build.

To install into another location, set `INSTALL_HOME`:

```bash
INSTALL_HOME=/path/to/install ./installer_v1.11.1.sh
```

or:

```bash
INSTALL_HOME=/path/to/install ./installer_v1.9.5.sh
```

## Build Differences &amp; Optional Overrides

### Build Differences

Both installers enable NeXus and HDF4 support through `-Dnexus=1` and `-DHAVE_HDF4=1`. Therefore, the musrfit builds installed by these scripts support NeXus binary files.

The musrfit 1.11.1 installer uses:

```bash
cmake .. \
  -DCMAKE_INSTALL_PREFIX="${ROOTSYS}" \
  -DCMAKE_BUILD_TYPE=Release \
  -Dnexus=1 \
  -DHAVE_HDF4=1
```

The musrfit 1.9.5 installer uses:

```bash
cmake .. \
  -DCMAKE_INSTALL_PREFIX="${ROOTSYS}" \
  -DCMAKE_BUILD_TYPE=Release \
  -Dnexus=1 \
  -DHAVE_HDF4=1 \
  -DNEXUS_INCLUDE_DIR=/usr/include/nexus \
  -DNEXUS_LIBRARY=/usr/lib/x86_64-linux-gnu/libNeXus.so
```

Both installers build with:

```bash
cmake --build . --clean-first -- -j"${BUILD_JOBS}"
```

By default, `BUILD_JOBS` uses `nproc`. You can override it:

```bash
BUILD_JOBS=4 ./installer_v1.11.1.sh
```

### Optional Overrides

Both installers support these environment variables:

```bash
INSTALL_HOME=${HOME}
ROOT_URL=<matching_ROOT_tarball_url>
MUSRFIT_REPO=https://bitbucket.org/muonspin/musrfit.git
MUSRFIT_SRC=${INSTALL_HOME}/apps/musrfit
MUSRFIT_REF=<commit_or_tag>
BUILD_JOBS=$(nproc)
```

Override these only if you know the selected ROOT and musrfit versions are compatible.

For example, one could use all override parameters:

```bash
INSTALL_HOME="$HOME/musrfit-1.9.5" \
ROOT_URL="https://root.cern/download/root_v6.32.02.Linux-ubuntu24.04-x86_64-gcc13.2.tar.gz" \
MUSRFIT_REPO="https://bitbucket.org/muonspin/musrfit.git" \
MUSRFIT_SRC="$HOME/musrfit-1.9.5/apps/musrfit" \
MUSRFIT_REF="ebefcf7af9fed9524be78afcf39d81d97577b48b" \
BUILD_JOBS=4 \
./installer_v1.9.5.sh
```

Parameter meanings:

- `INSTALL_HOME`: Base installation directory. ROOT is installed under `$INSTALL_HOME/apps/root` by default.
- `ROOT_URL`: CERN ROOT binary package URL. It should match the target Ubuntu and musrfit version.
- `MUSRFIT_REPO`: musrfit source repository URL.
- `MUSRFIT_SRC`: Local musrfit source directory.
- `MUSRFIT_REF`: musrfit commit or tag to check out before building.
- `BUILD_JOBS`: Number of parallel build jobs passed to CMake.

## Sudo Usage and Environment Files

The scripts request `sudo` permission near the start with `sudo -v`. They use `sudo` for system package installation, enabling the `universe` repository, fallback directory creation or ownership repair when the target install directory is not writable, and dynamic linker configuration through `/etc/ld.so.conf.d/cern-root.conf` and `ldconfig`.

The installer adds an environment block like this to `~/.bashrc`:

```bash
export ROOTSYS=<INSTALL_HOME>/apps/root
export PATH=$ROOTSYS/bin:$PATH
export MUSRFITPATH=$ROOTSYS/bin
```

With the default settings, `<INSTALL_HOME>` is the user's home directory. If `INSTALL_HOME` is overridden, the `ROOTSYS` value written to `~/.bashrc` follows that custom installation path.

The official musrfit instructions may also mention `~/.bash_profile`. This installer intentionally does not create or edit `~/.bash_profile`.

On Ubuntu, `~/.bash_profile` usually does not exist by default. Ubuntu normally uses `~/.profile`, which loads `~/.bashrc` for Bash sessions. If an installer creates a new `~/.bash_profile`, Bash may prefer it over `~/.profile`, and the default Ubuntu shell setup may no longer run unless it is copied manually.

If your environment already uses `~/.bash_profile`, you can make it load `~/.bashrc`:

```bash
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
```

## Author

EC from Fudan University

Please leave your comments or suggestions in this GitHub project.
