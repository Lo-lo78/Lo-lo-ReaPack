# Lo-lo-ReaPack

Accessible REAPER Lua scripts and JSFX instruments and effects by Lo-lo, distributed via ReaPack.

ReaPack index: https://raw.githubusercontent.com/Lo-lo78/Lo-lo-ReaPack/main/index.xml

## LSpectrum 4.5dB Analyzer 6.6

One combined ReaPack package installs the JSFX audio analyzer, its accessible Lua controller and the HTML guide.

### Repository source files

- `Lo-lo - JSFX/analysis/LSpectrum 4.5dB Analyzer.jsfx`
- `Lo-lo - JSFX/analysis/LSpectrum 4.5dB Analyzer — Full Quick Guide.html`
- `Lo-lo - Scripts/analysis/LSpectrum 4.5dB Analyzer.lua`

### REAPER installation destinations

- `Effects/Lo-lo - JSFX/analysis/LSpectrum 4.5dB Analyzer.jsfx`
- `Effects/Lo-lo - JSFX/analysis/LSpectrum 4.5dB Analyzer — Full Quick Guide.html`
- `Scripts/Lo-lo - Scripts/analysis/LSpectrum 4.5dB Analyzer.lua`

The JSFX is the package entrypoint and lists the Lua under `@provides [script main]` by a relative path to the separate Scripts directory. The Lua is marked `@noindex`: it is not a second, independently installable package.

The Lua's personal analysis output stays in `Scripts/Lo-lo - Scripts/analysis/LSpectrum 4.5dB Analyzer/spectrum_LastResult.txt`, outside ReaPack's managed files, and is not distributed. The HTML guide stays in `Effects/Lo-lo - JSFX/analysis/` as expected by the Lua.

### Publishing

Only commit approved stable versions. Increase `@version` in the main JSFX for each new released package version (and keep the Lua's header in sync). GitHub Actions regenerates `index.xml` on pushes to `main`. Check the generated XML sources and test installation in a portable REAPER before announcing the repository.

An existing Lua action installed manually may need to be removed or unregistered after confirming the ReaPack installation to avoid duplicate Action List entries.

## Standalone JSFX instruments

The following instruments are independent ReaPack packages and do **not** depend on a Lua controller or external JSFX includes:

- **Biscot1 Synth — package version 2.29:** `Lo-lo - JSFX/Instruments/Biscot1Synth/Biscot1Synth.jsfx`. The original source labels the underlying v2.29 work as TEST; verify it before announcing it as a stable release.
- **LWS-7 — package version 1.0:** `Lo-lo - JSFX/Instruments/LWS-7/LWS-7.jsfx`. The source did not declare a release version; 1.0 here is its **first ReaPack distribution version**, not a claim about an internal engine version.

These two files install under REAPER's `Effects/Lo-lo - JSFX/Instruments/` hierarchy (with their respective instrument subfolders). Only package metadata was prepended; the original JSFX code, DSP, parameter defaults and serialization were not changed.

To publish a new version of **one** instrument, increase that file's `@version`, add a changelog entry, then push to `main`. The GitHub Actions workflow regenerates `index.xml`. Do not publish untested changes as stable releases.

**Repository safety:** Always extract this archive over the existing local repository, preserving its `.git` folder and current `index.xml`. Those two entries are intentionally excluded from this archive to avoid replacing commit history or an index generated on GitHub. Do not delete existing files before extracting.
