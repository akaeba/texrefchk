[![Unittest](https://github.com/akaeba/texrefchk/workflows/Unittest/badge.svg)](https://github.com/akaeba/texrefchk/actions)

# [texrefchk](./texrefchk.sh)
TeX Label and reference checker. Searches for non unique TeX Labels and broken references.


## Releases

| Version                                                   | Date       | Source                                                                                                 | Change log     |
| --------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------ | -------------- |
| latest                                                    |            | <a id="raw-url" href="https://github.com/akaeba/texrefchk/archive/refs/heads/main.zip">latest.zip</a>  |                |
| [v0.1.0](https://github.com/akaeba/texrefchk/tree/v0.1.0) | 2022-08-XX | <a id="raw-url" href="https://github.com/akaeba/texrefchk/archive/refs/tags/v0.1.0.zip">v0.1.0.zip</a> | initial draft  |


## Features

* checks TeX sources for non unique labels, selector `\label{}` and `label=`
* checks references for existing labels, selector `\autoref{}`, `\nameref{}`, `\ref{}`
* output of broken labels/references with tag and issued file
* outputs errors in file _non_unique_labels.txt_ and _non_defined_references.txt_


## Command line interface

### Options

| Option        | Description                  |
| ------------- | ---------------------------- |
| --texdir[=.]  | path to analyzed TeX sources |
| --stoponerror | stop on first error          |
| --verbose     | advanced debug output        |


### Run

```bash
./texrefchk --texdir=./test/01_pass
```




