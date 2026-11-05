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
